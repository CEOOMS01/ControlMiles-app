// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/create-checkout-session/index.ts
//
// Creates a Stripe Checkout Session for ControlMiles Premium. Real
// payment integration (see [[project_controlmiles]]) -- the whole point
// of Stripe Checkout here is that ControlMiles NEVER sees a card number:
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
const STRIPE_PRICE_ID = Deno.env.get('STRIPE_PRICE_ID') ?? '';

// Cosmetic only -- Stripe requires a success/cancel URL, but the real
// source of truth for whether a subscription is active is always
// stripe-webhook, never this redirect. A dedicated in-app deep link back
// from the browser is real follow-up work, not required for correctness
// (AppState.premiumEntitled picks up the webhook's DB write the same way
// it already picks up any other profile change, independent of whatever
// page the browser lands on after payment).
const CHECKOUT_SUCCESS_URL = 'https://controlmiles.com/checkout-success';
const CHECKOUT_CANCEL_URL = 'https://controlmiles.com/checkout-cancel';

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

    if (!STRIPE_SECRET_KEY || !STRIPE_PRICE_ID) {
      return respond({ error: 'Subscriptions not configured yet', configured: false }, 200);
    }

    const form = new URLSearchParams();
    form.set('mode', 'subscription');
    form.set('line_items[0][price]', STRIPE_PRICE_ID);
    form.set('line_items[0][quantity]', '1');
    form.set('client_reference_id', userData.user.id);
    if (userData.user.email) form.set('customer_email', userData.user.email);
    form.set('subscription_data[metadata][user_id]', userData.user.id);
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
