// verify-play-purchase (2026-09-29): the app sends the Google Play purchase
// token right after a purchase (and on "Restore purchases"); this asks
// Google for the real state and only then turns Basic/Premium on. The app
// never grants anything itself -- a faked purchase has no valid token.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { adminClient, getSubscription, PRODUCT_TIERS, syncPurchase } from '../_shared/google_play.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return respond({ error: 'Missing Authorization header' }, 401);

    const userClient = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData?.user) return respond({ error: 'Invalid or expired session' }, 401);
    const userId = userData.user.id;

    const db = adminClient();
    const { data: allowed } = await db.rpc('check_rate_limit', {
      p_fn_name: 'verify-play-purchase',
      p_client_key: userId,
      p_max_requests: 20,
      p_window_seconds: 60,
    });
    if (allowed === false) return respond({ error: 'Too many requests, please try again shortly' }, 429);

    const body = await req.json().catch(() => ({}));
    const productId = String(body?.productId ?? '');
    const purchaseToken = String(body?.purchaseToken ?? '');
    if (!PRODUCT_TIERS[productId] || !purchaseToken) {
      return respond({ error: 'Invalid purchase' }, 400);
    }

    // A token already on file for someone else is never moved to this user.
    const { data: existing } = await db.from('play_subscriptions')
      .select('user_id').eq('purchase_token', purchaseToken).maybeSingle();
    if (existing && existing.user_id !== userId) {
      return respond({ error: 'PLAY_PURCHASE_OTHER_ACCOUNT' }, 403);
    }

    let sub;
    try {
      sub = await getSubscription(purchaseToken);
    } catch (e) {
      const msg = (e as Error).message;
      if (msg === 'PLAY_NOT_CONFIGURED') return respond({ configured: false }, 200);
      if (msg === 'PLAY_TOKEN_NOT_FOUND') return respond({ error: 'PLAY_PURCHASE_INVALID' }, 400);
      throw e;
    }

    // The app buys with applicationUserName = the user's id, which Google
    // returns here: a purchase made from another ControlMiles account can't
    // be claimed by this one.
    const owner = sub.externalAccountIdentifiers?.obfuscatedExternalAccountId;
    if (owner && owner !== userId) return respond({ error: 'PLAY_PURCHASE_OTHER_ACCOUNT' }, 403);

    const result = await syncPurchase(db, userId, purchaseToken, sub);
    const { data: profile } = await db.from('profiles')
      .select('base_entitled, premium_entitled').eq('id', userId).maybeSingle();

    return respond({
      ...result,
      base_entitled: profile?.base_entitled ?? false,
      premium_entitled: profile?.premium_entitled ?? false,
    });
  } catch (e) {
    console.error('[verify-play-purchase] error:', e);
    return respond({ error: 'Could not verify the purchase' }, 500);
  }
});
