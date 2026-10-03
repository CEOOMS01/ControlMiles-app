// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/create-checkout-session/index.ts
//
// Creates a Stripe Checkout Session for a FLEET plan (Starter / Growth,
// priced per vehicle). ControlMiles never sees a card: the returned URL is
// Stripe's hosted page, and the subscription itself reaches the database
// only through stripe-webhook.
//
// Body: {"scope": "fleet", "organization_id", "tier": "starter" | "growth"}.
// The caller must be an active owner/admin of that org (checked with the
// caller's own RLS-scoped client, never trusted from the body).
//
// Pre-launch audit (2026-10-03):
// - The seat quantity is the org's real vehicle count
//   (fn_org_billable_vehicles), not a number sent by the browser -- a
//   client could send vehicle_count 1 and run 50 vehicles.
//   stripe-webhook re-syncs it on invoice.upcoming before each renewal.
// - An org that already has a live subscription is sent to the billing
//   portal instead of opening a second subscription (double charge).
// - The existing Stripe customer is reused, so all invoices stay together.
// - success/cancel return to /admin/settings (the old /checkout-success
//   page never existed -> 404 after paying).
// - Personal (gig) plans are sold only in the app through Google Play
//   (user decision 2026-09-29); the old personal Stripe path is closed.
//
// STRIPE_PRICE_ID_FLEET_STARTER / _GROWTH: recurring monthly per-unit
// Prices ($12.99 / $19.99 per vehicle). Until they are set this answers
// configured:false, never a fake success.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY') ?? '';
const STRIPE_PRICE_ID_FLEET_STARTER = Deno.env.get('STRIPE_PRICE_ID_FLEET_STARTER') ?? '';
const STRIPE_PRICE_ID_FLEET_GROWTH = Deno.env.get('STRIPE_PRICE_ID_FLEET_GROWTH') ?? '';

const SITE_URL = Deno.env.get('SITE_URL') ?? 'https://controlmiles.com';
const CHECKOUT_SUCCESS_URL = `${SITE_URL}/admin/settings?billing=success`;
const CHECKOUT_CANCEL_URL = `${SITE_URL}/admin/settings?billing=canceled`;

const LIVE_STATUSES = new Set(['active', 'trialing', 'past_due']);

// Keyed by user id (authenticated endpoint). Postgres-backed
// check_rate_limit, called with the service role (EXECUTE is revoked from
// client roles so nobody can fill another user's bucket).
const RATE_LIMIT_MAX = 5;
const RATE_LIMIT_WINDOW_SECONDS = 60;

function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return respond({ error: 'Missing Authorization header' }, 401);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const userClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authHeader } },
    });
    const adminClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData?.user) {
      return respond({ error: 'Invalid or expired session' }, 401);
    }

    const { data: allowed, error: rlError } = await adminClient.rpc('check_rate_limit', {
      p_fn_name: 'create-checkout-session',
      p_client_key: userData.user.id,
      p_max_requests: RATE_LIMIT_MAX,
      p_window_seconds: RATE_LIMIT_WINDOW_SECONDS,
    });
    if (rlError) console.warn('[create-checkout-session] rate limit check failed (failing open):', rlError);
    if (allowed === false) {
      return respond({ error: 'Too many requests, please try again shortly' }, 429);
    }

    const body = await req.json().catch(() => ({}));
    if (body?.scope !== 'fleet') {
      return respond({ error: 'Personal plans are purchased in the ControlMiles app.' }, 400);
    }

    const organizationId = String(body?.organization_id ?? '');
    const fleetTier = body?.tier === 'growth' ? 'growth' : 'starter';
    if (!organizationId) {
      return respond({ error: 'Missing organization_id' }, 400);
    }

    const { data: membership, error: membershipError } = await userClient
      .from('organization_members')
      .select('member_role')
      .eq('organization_id', organizationId)
      .eq('user_id', userData.user.id)
      .eq('is_active', true)
      .maybeSingle();
    if (membershipError || !membership || !['owner', 'admin'].includes(membership.member_role)) {
      return respond({ error: 'Not authorized for this organization' }, 403);
    }

    const priceId = fleetTier === 'growth' ? STRIPE_PRICE_ID_FLEET_GROWTH : STRIPE_PRICE_ID_FLEET_STARTER;
    if (!STRIPE_SECRET_KEY || !priceId) {
      return respond({ error: 'Fleet subscriptions are not configured yet', configured: false }, 200);
    }

    const { data: org, error: orgError } = await adminClient
      .from('organizations')
      .select('stripe_customer_id, subscription_status')
      .eq('id', organizationId)
      .maybeSingle();
    if (orgError || !org) {
      return respond({ error: 'Organization not found' }, 404);
    }
    if (LIVE_STATUSES.has(org.subscription_status ?? '')) {
      return respond({ error: 'ALREADY_SUBSCRIBED' }, 409);
    }

    const { data: seats, error: seatsError } = await adminClient.rpc('fn_org_billable_vehicles', {
      p_org_id: organizationId,
    });
    if (seatsError) throw seatsError;
    const quantity = Math.max(Number(seats) || 1, 1);

    const form = new URLSearchParams();
    form.set('mode', 'subscription');
    form.set('success_url', CHECKOUT_SUCCESS_URL);
    form.set('cancel_url', CHECKOUT_CANCEL_URL);
    form.set('line_items[0][price]', priceId);
    form.set('line_items[0][quantity]', String(quantity));
    form.set('client_reference_id', organizationId);
    if (org.stripe_customer_id) {
      form.set('customer', org.stripe_customer_id);
    } else if (userData.user.email) {
      form.set('customer_email', userData.user.email);
    }
    form.set('allow_promotion_codes', 'true');
    form.set('billing_address_collection', 'auto');
    form.set('subscription_data[metadata][organization_id]', organizationId);
    form.set('subscription_data[metadata][scope]', 'fleet');
    form.set('subscription_data[metadata][tier]', fleetTier);
    form.set('metadata[organization_id]', organizationId);
    form.set('metadata[scope]', 'fleet');

    const stripeRes = await fetch('https://api.stripe.com/v1/checkout/sessions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
        // One checkout per org/tier/seat count per minute even on double-click.
        'Idempotency-Key': `fleet-checkout-${organizationId}-${fleetTier}-${quantity}-${Math.floor(Date.now() / 60000)}`,
      },
      body: form.toString(),
    });

    if (!stripeRes.ok) {
      const text = await stripeRes.text();
      console.error(`[create-checkout-session] Stripe error ${stripeRes.status}: ${text}`);
      return respond({ error: 'Could not start checkout' }, 502);
    }

    const session = await stripeRes.json();
    return respond({ url: session.url, configured: true, quantity });
  } catch (err: any) {
    console.error('[create-checkout-session] Unexpected error:', err);
    return respond({ error: 'Internal error' }, 500);
  }
});
