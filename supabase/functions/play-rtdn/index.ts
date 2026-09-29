// play-rtdn (2026-09-29): Google Play Real-time Developer Notifications,
// pushed by Cloud Pub/Sub on every renewal, cancellation, grace period,
// expiry, refund or upgrade. Each one re-reads the real state from the Play
// Developer API (the notification itself is never trusted) and recomputes
// the user's Basic/Premium.
//
// Deployed with --no-verify-jwt (Pub/Sub has no Supabase session). Pub/Sub
// push URL: https://<project>.supabase.co/functions/v1/play-rtdn?token=<PLAY_RTDN_SECRET>

import { adminClient, getSubscription, syncPurchase } from '../_shared/google_play.ts';

function ok() {
  // Any 2xx tells Pub/Sub not to retry.
  return new Response('ok', { status: 200 });
}

Deno.serve(async (req: Request) => {
  const secret = Deno.env.get('PLAY_RTDN_SECRET');
  const token = new URL(req.url).searchParams.get('token');
  if (!secret || token !== secret) return new Response('forbidden', { status: 403 });

  try {
    const envelope = await req.json();
    const data = envelope?.message?.data;
    if (!data) return ok();
    const notification = JSON.parse(atob(data));
    const purchaseToken: string | undefined = notification?.subscriptionNotification?.purchaseToken;
    if (!purchaseToken) return ok(); // test notifications, one-time products, voided purchases

    const db = adminClient();
    const sub = await getSubscription(purchaseToken);

    const { data: known } = await db.from('play_subscriptions')
      .select('user_id').eq('purchase_token', purchaseToken).maybeSingle();
    let userId: string | null = known?.user_id ?? sub.externalAccountIdentifiers?.obfuscatedExternalAccountId ?? null;
    if (!userId && sub.linkedPurchaseToken) {
      const { data: linked } = await db.from('play_subscriptions')
        .select('user_id').eq('purchase_token', sub.linkedPurchaseToken).maybeSingle();
      userId = linked?.user_id ?? null;
    }
    if (!userId) {
      console.warn('[play-rtdn] notification for a token with no known user; the app syncs it on next open');
      return ok();
    }

    await syncPurchase(db, userId, purchaseToken, sub);
    return ok();
  } catch (e) {
    console.error('[play-rtdn] error:', e);
    // 500 makes Pub/Sub retry later -- right for a transient Google/API error.
    return new Response('error', { status: 500 });
  }
});
