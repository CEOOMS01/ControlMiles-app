// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/create-portal-session/index.ts
//
// Creates a Stripe Billing Portal session so a subscribed user can
// update their payment method or cancel on Stripe's own hosted page --
// same "ControlMiles never touches card data" principle as
// create-checkout-session (see [[project_controlmiles]]). Powers the
// existing "manage_subscription" i18n key's real action.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY') ?? '';
const PORTAL_RETURN_URL = 'https://controlmiles.com/account';

// Security hardening (2026-08-28): same Postgres-backed pattern as
// create-checkout-session's own rate limiter -- see its comment for why
// this isn't an in-memory Map (verified live not to work on Supabase's
// Deno edge runtime).
const RATE_LIMIT_MAX = 5;
const RATE_LIMIT_WINDOW_SECONDS = 60;

async function isRateLimited(client: ReturnType<typeof createClient>, clientId: string): Promise<boolean> {
  const { data, error } = await client.rpc('check_rate_limit', {
    p_fn_name: 'create-portal-session',
    p_client_key: clientId,
    p_max_requests: RATE_LIMIT_MAX,
    p_window_seconds: RATE_LIMIT_WINDOW_SECONDS,
  });
  if (error) {
    console.warn('[create-portal-session] rate limit check failed (failing open):', error);
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

    if (!STRIPE_SECRET_KEY) {
      return respond({ error: 'Subscriptions not configured yet', configured: false }, 200);
    }

    // RLS-gated -- subscriptions_select_own means this only ever returns
    // the caller's own row(s).
    const { data: subs, error: subError } = await userClient
      .from('subscriptions')
      .select('stripe_customer_id')
      .eq('user_id', userData.user.id)
      .not('stripe_customer_id', 'is', null)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (subError || !subs?.stripe_customer_id) {
      return respond({ error: 'No subscription found for this account' }, 404);
    }

    const form = new URLSearchParams();
    form.set('customer', subs.stripe_customer_id);
    form.set('return_url', PORTAL_RETURN_URL);

    const stripeRes = await fetch('https://api.stripe.com/v1/billing_portal/sessions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
      },
      body: form.toString(),
    });

    if (!stripeRes.ok) {
      const text = await stripeRes.text();
      console.error(`[create-portal-session] Stripe error ${stripeRes.status}: ${text}`);
      return respond({ error: 'Could not open billing portal' }, 502);
    }

    const session = await stripeRes.json();
    return respond({ url: session.url, configured: true });
  } catch (err: any) {
    console.error('[create-portal-session] Unexpected error:', err);
    return respond({ error: err?.message ?? 'Internal error' }, 500);
  }
});
