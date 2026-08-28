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

import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY') ?? '';
const STRIPE_PRICE_ID_BASE = Deno.env.get('STRIPE_PRICE_ID_BASE') ?? '';
const STRIPE_PRICE_ID_PREMIUM = Deno.env.get('STRIPE_PRICE_ID_PREMIUM') ?? '';

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

async function isRateLimited(client: ReturnType<typeof createClient>, clientId: string): Promise<boolean> {
  const { data, error } = await client.rpc('check_rate_limit', {
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

    if (await isRateLimited(userClient, userData.user.id)) {
      return respond({ error: 'Too many requests, please try again shortly' }, 429);
    }

    let tier = 'premium';
    try {
      const body = await req.json();
      if (body?.tier === 'base' || body?.tier === 'premium') tier = body.tier;
    } catch {
      // No/invalid body -- default to premium (the only tier that existed
      // before this became a two-tier system, keeps any existing caller
      // working unchanged).
    }

    const priceId = tier === 'base' ? STRIPE_PRICE_ID_BASE : STRIPE_PRICE_ID_PREMIUM;
    if (!STRIPE_SECRET_KEY || !priceId) {
      return respond({ error: 'Subscriptions not configured yet', configured: false }, 200);
    }

    const form = new URLSearchParams();
    form.set('mode', 'subscription');
    form.set('line_items[0][price]', priceId);
    form.set('line_items[0][quantity]', '1');
    form.set('client_reference_id', userData.user.id);
    if (userData.user.email) form.set('customer_email', userData.user.email);
    form.set('subscription_data[metadata][user_id]', userData.user.id);
    form.set('subscription_data[metadata][tier]', tier);
    form.set('success_url', `${CHECKOUT_SUCCESS_URL}?session_id={CHECKOUT_SESSION_ID}`);
    form.set('cancel_url', CHECKOUT_CANCEL_URL);

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
