// Google Play Developer API helpers (2026-09-29) for the app's personal
// plans, now billed natively through Google Play (see migration
// 20260929190000_google_play_subscriptions.sql for the why).
//
// Secret GOOGLE_PLAY_SERVICE_ACCOUNT = the JSON key of a Google Cloud service
// account that has access to this app in Play Console (Users & permissions:
// "View financial data" + "Manage orders and subscriptions").

import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';

export const PACKAGE_NAME = 'com.olimsys.controlmiles';

// Play Console subscription product IDs -> app tier. Premium includes Base.
export const PRODUCT_TIERS: Record<string, 'base' | 'premium'> = {
  controlmiles_basic_monthly: 'base',
  controlmiles_premium_monthly: 'premium',
};

type ServiceAccount = { client_email: string; private_key: string };

function b64url(data: ArrayBuffer | Uint8Array | string): string {
  const bytes = typeof data === 'string'
    ? new TextEncoder().encode(data)
    : data instanceof Uint8Array ? data : new Uint8Array(data);
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

let cachedToken: { value: string; expiresAt: number } | null = null;

async function accessToken(): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) return cachedToken.value;
  const raw = Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT');
  if (!raw) throw new Error('PLAY_NOT_CONFIGURED');
  const sa = JSON.parse(raw) as ServiceAccount;

  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${header}.${claims}`),
  );
  const jwt = `${header}.${claims}.${b64url(signature)}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt }),
  });
  if (!res.ok) throw new Error(`Google token exchange failed: ${res.status}`);
  const json = await res.json();
  cachedToken = { value: json.access_token, expiresAt: Date.now() + (json.expires_in ?? 3600) * 1000 };
  return cachedToken.value;
}

export type PlaySubscription = {
  subscriptionState: string;
  acknowledgementState?: string;
  latestOrderId?: string;
  linkedPurchaseToken?: string;
  externalAccountIdentifiers?: { obfuscatedExternalAccountId?: string };
  lineItems?: {
    productId: string;
    expiryTime?: string;
    autoRenewingPlan?: { autoRenewEnabled?: boolean };
  }[];
};

export async function getSubscription(purchaseToken: string): Promise<PlaySubscription> {
  const token = await accessToken();
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE_NAME}` +
    `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (res.status === 404 || res.status === 410) throw new Error('PLAY_TOKEN_NOT_FOUND');
  if (!res.ok) throw new Error(`Play API error ${res.status}`);
  return await res.json();
}

async function acknowledge(productId: string, purchaseToken: string): Promise<void> {
  const token = await accessToken();
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE_NAME}` +
    `/purchases/subscriptions/${productId}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: '{}',
  });
  // Google refunds a purchase nobody acknowledged within 3 days; the app
  // also acknowledges (completePurchase), so a failure here is only logged.
  if (!res.ok) console.warn(`[google_play] acknowledge failed: ${res.status}`);
}

export function adminClient(): SupabaseClient {
  return createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
}

/**
 * Stores Google's real state for one purchase token under [userId] and
 * recomputes that user's Basic/Premium.
 */
export async function syncPurchase(
  db: SupabaseClient,
  userId: string,
  purchaseToken: string,
  sub: PlaySubscription,
): Promise<{ tier: 'base' | 'premium'; state: string; expiry: string | null }> {
  const item = (sub.lineItems ?? []).find((li) => PRODUCT_TIERS[li.productId]);
  if (!item) throw new Error('PLAY_UNKNOWN_PRODUCT');
  const tier = PRODUCT_TIERS[item.productId];
  const expiry = item.expiryTime ?? null;
  const nowIso = new Date().toISOString();

  const { error } = await db.from('play_subscriptions').upsert({
    purchase_token: purchaseToken,
    user_id: userId,
    product_id: item.productId,
    tier,
    order_id: sub.latestOrderId ?? null,
    state: sub.subscriptionState,
    expiry_time: expiry,
    auto_renewing: item.autoRenewingPlan?.autoRenewEnabled ?? null,
    linked_purchase_token: sub.linkedPurchaseToken ?? null,
    raw: sub,
    updated_at: nowIso,
  }, { onConflict: 'purchase_token' });
  if (error) throw error;

  // An upgrade (Basic -> Premium) replaces the old purchase: from now on
  // only the new one grants anything.
  if (sub.linkedPurchaseToken) {
    await db.from('play_subscriptions')
      .update({ state: 'SUBSCRIPTION_STATE_EXPIRED', expiry_time: nowIso, updated_at: nowIso })
      .eq('purchase_token', sub.linkedPurchaseToken);
  }

  if (sub.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING' &&
      sub.subscriptionState === 'SUBSCRIPTION_STATE_ACTIVE') {
    await acknowledge(item.productId, purchaseToken);
  }

  const { error: recomputeError } = await db.rpc('recompute_personal_entitlements', { p_user: userId });
  if (recomputeError) throw recomputeError;

  return { tier, state: sub.subscriptionState, expiry };
}
