// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/create-checkout-session/index.ts
//
// Creates a Stripe Checkout Session for ControlMiles Base ($5.99) or
// Premium ($9.99) -- two real tiers (2026-08-28), not one: Base is the
// core paid app experience, Premium adds Automatic Detection on top of
// everything Base has. Caller passes {"tier": "base" | "premium"} in the
// request body. Real payment integration (see [[project_controlmiles]])
// -- the whole point of Stripe Checkout here is that ControlMiles NEVER
// sees a card number:
// the returned URL is Stripe's own hosted page, opened externally
// (url_launcher, see subscription_screen.dart). Card data goes straight
// to Stripe; the only thing that ever comes back to this app is a
// tokenized customer/subscription id, delivered later by
// stripe-webhook -- not by this function or the client.
//
// subscription_data.metadata.user_id is the important bit: it's what
// lets every SUBSEQUENT customer.subscription.* webhook event carry the
// ControlMiles user id directly, without stripe-webhook needing to
// correlate via stripe_customer_id or make an extra API call back to
// Stripe just to figure out whose subscription changed.
//
// Security: user_id/email come from the caller's own verified JWT
// (userClient.auth.getUser()), never trusted from a request body --
// same discipline as delete-account and cgc-seal-trip in this repo.
//
// FLEET SCOPE (explicit user request, 2026-09-17, mitigating a real gap
// the private Enterprise Brief flagged: the pricing page has always
// advertised Starter/Growth per-vehicle billing with no live checkout
// behind it). {"scope": "fleet", "organization_id", "tier": "starter" |
// "growth", "vehicle_count"} creates an org-level subscription instead --
// quantity scales with vehicle_count (Fleet pricing is per-vehicle, not
// flat), and metadata carries organization_id instead of just user_id so
// stripe-webhook can tell a Fleet event from a Gig one and update
// `organizations` instead of `profiles`/`subscriptions` (see its own
// updated header comment). The caller's org admin/owner membership is
// verified here via the caller's own RLS-scoped client, exactly like
// generate_report_access_code's own target-driver check elsewhere in
// this project -- organization_id is never trusted bare from the request
// body. STRIPE_PRICE_ID_FLEET_STARTER/_GROWTH are separate, real Stripe
// Price objects that don't exist yet as of this commit -- until they're
// created in the Stripe Dashboard and set as secrets here, this path
// correctly falls through to the same "not configured yet" response the
// Gig tiers already return when unconfigured, never a fake success.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY') ?? '';
const STRIPE_PRICE_ID_BASE = Deno.env.get('STRIPE_PRICE_ID_BASE') ?? '';
const STRIPE_PRICE_ID_PREMIUM = Deno.env.get('STRIPE_PRICE_ID_PREMIUM') ?? '';
const STRIPE_PRICE_ID_FLEET_STARTER = Deno.env.get('STRIPE_PRICE_ID_FLEET_STARTER') ?? '';
const STRIPE_PRICE_ID_FLEET_GROWTH = Deno.env.get('STRIPE_PRICE_ID_FLEET_GROWTH') ?? '';

// Cosmetic only -- Stripe requires a success/cancel URL, but the real
// source of truth for whether a subscription is active is always
// stripe-webhook, never this redirect. A dedicated in-app deep link back
// from the browser is real follow-up work, not required for correctness
// (AppState.premiumEntitled picks up the webhook's DB write the same way
// it already picks up any other profile change, independent of whatever
// page the browser lands on after payment).
const CHECKOUT_SUCCESS_URL = 'https://controlmiles.com/checkout-success';
const CHECKOUT_CANCEL_URL = 'https://controlmiles.com/checkout-cancel';

// Security hardening (2026-08-28): keyed by user_id, not IP -- this
// endpoint is authenticated, so the real identity is more precise than a
// shared NAT/carrier IP and won't wrongly penalize other users behind
// it. A legitimate user never needs more than a couple of these per
// minute; this only stops a compromised/malicious token from hammering
// Stripe's Checkout Session API through this function.
//
// Postgres-backed (check_rate_limit RPC, see migration
// 20260828100000_create_edge_function_rate_limiter.sql), not an
// in-memory Map -- the in-memory version was tried first and verified
// LIVE to not work at all on Supabase's Deno edge runtime (a 25-request
// concurrent burst against report-error returned 200 every time). This
// one is durable and correct under concurrency.
const RATE_LIMIT_MAX = 5;
const RATE_LIMIT_WINDOW_SECONDS = 60;

async function isRateLimited(clientId: string): Promise<boolean> {
  // SECURITY (2026-09-16): this RPC is called with the SERVICE-ROLE key, not
  // the anon/user key. check_rate_limit is EXECUTE-revoked from anon and
  // authenticated so that nobody holding the public key can fill another
  // user's bucket (a targeted lockout) or bloat edge_function_rate_limits at
  // will. The service-role key never leaves the edge function.
  const rlClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
  const { data, error } = await rlClient.rpc('check_rate_limit', {
    p_fn_name: 'create-checkout-session',
    p_client_key: clientId,
    p_max_requests: RATE_LIMIT_MAX,
    p_window_seconds: RATE_LIMIT_WINDOW_SECONDS,
  });
  if (error) {
    console.warn('[create-checkout-session] rate limit check failed (failing open):', error);
    return false;
  }
  return !data;
}

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
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData?.user) {
      return respond({ error: 'Invalid or expired session' }, 401);
    }

    if (await isRateLimited(userData.user.id)) {
      return respond({ error: 'Too many requests, please try again shortly' }, 429);
    }

    let body: any = {};
    try {
      body = await req.json();
    } catch {
      // No/invalid body -- falls through to the Gig default below, same
      // as before Fleet scope existed.
    }

    const isFleet = body?.scope === 'fleet';
    const form = new URLSearchParams();
    form.set('mode', 'subscription');
    form.set('success_url', `${CHECKOUT_SUCCESS_URL}?session_id={CHECKOUT_SESSION_ID}`);
    form.set('cancel_url', CHECKOUT_CANCEL_URL);

    if (isFleet) {
      const organizationId = String(body?.organization_id ?? '');
      const fleetTier = body?.tier === 'growth' ? 'growth' : 'starter';
      const vehicleCount = Number(body?.vehicle_count);

      if (!organizationId) {
        return respond({ error: 'Missing organization_id' }, 400);
      }
      if (!Number.isInteger(vehicleCount) || vehicleCount < 1) {
        return respond({ error: 'vehicle_count must be a positive integer' }, 400);
      }

      // Never trust organization_id bare from the request body -- verify
      // via the caller's OWN RLS-scoped client that they're actually an
      // admin/owner of that org, same discipline
      // generate_report_access_code's target-driver path uses.
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

      form.set('line_items[0][price]', priceId);
      form.set('line_items[0][quantity]', String(vehicleCount));
      form.set('client_reference_id', organizationId);
      if (userData.user.email) form.set('customer_email', userData.user.email);
      form.set('subscription_data[metadata][organization_id]', organizationId);
      form.set('subscription_data[metadata][scope]', 'fleet');
      form.set('subscription_data[metadata][tier]', fleetTier);
    } else {
      let tier = 'premium';
      if (body?.tier === 'base' || body?.tier === 'premium') tier = body.tier;

      const priceId = tier === 'base' ? STRIPE_PRICE_ID_BASE : STRIPE_PRICE_ID_PREMIUM;
      if (!STRIPE_SECRET_KEY || !priceId) {
        return respond({ error: 'Subscriptions not configured yet', configured: false }, 200);
      }

      form.set('line_items[0][price]', priceId);
      form.set('line_items[0][quantity]', '1');
      form.set('client_reference_id', userData.user.id);
      if (userData.user.email) form.set('customer_email', userData.user.email);
      form.set('subscription_data[metadata][user_id]', userData.user.id);
      form.set('subscription_data[metadata][tier]', tier);
      // Explicit user requirement (2026-09-17): Premium only (not Basic)
      // gets its own 5-day free trial. premium_entitled flips true the
      // moment Stripe creates this trialing subscription -- stripe-webhook
      // already treats trialing the same as active, no change needed there.
      if (tier === 'premium') {
        form.set('subscription_data[trial_period_days]', '5');
      }
    }

    const stripeRes = await fetch('https://api.stripe.com/v1/checkout/sessions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
      },
      body: form.toString(),
    });

    if (!stripeRes.ok) {
      const text = await stripeRes.text();
      console.error(`[create-checkout-session] Stripe error ${stripeRes.status}: ${text}`);
      return respond({ error: 'Could not start checkout' }, 502);
    }

    const session = await stripeRes.json();
    return respond({ url: session.url, configured: true });
  } catch (err: any) {
    console.error('[create-checkout-session] Unexpected error:', err);
    return respond({ error: err?.message ?? 'Internal error' }, 500);
  }
});
