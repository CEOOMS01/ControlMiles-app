// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/stripe-webhook/index.ts
//
// Stripe -> ControlMiles. Deployed with verify_jwt off: the Stripe-Signature
// header (HMAC over the raw body, 5-minute replay window) is the auth.
//
// Fleet plans (metadata.scope = 'fleet') update `organizations`; personal
// plans (metadata.user_id, legacy web checkout) upsert `subscriptions` and
// then recompute_personal_entitlements, the same function the Google Play
// path uses, so a Stripe event can never switch off a live Play plan.
//
// Pre-launch audit fixes (2026-10-03):
// - Every customer.subscription.* event re-reads the subscription from the
//   Stripe API, so events arriving out of order can't revive a cancelled one.
// - A processing failure removes the idempotency row and answers 500, so
//   Stripe retries; before, the event was marked done and lost silently.
// - Database errors are checked instead of ignored.
// - invoice.upcoming sets a fleet's seat quantity to its current vehicle
//   count before each renewal (vehicles added after checkout were never
//   billed).
// - A stale subscription can't overwrite a newer one on the same org.

import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';

const STRIPE_WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? '';
const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY') ?? '';
const CGC_ENDPOINT = Deno.env.get('CGC_ENDPOINT') ?? '';
const CGC_API_KEY = Deno.env.get('CGC_API_KEY') ?? '';
const CGC_PLAN_FOR_SUBSCRIBED = Deno.env.get('CGC_PLAN_FOR_SUBSCRIBED') ?? 'STANDARD';
const STRIPE_PRICE_ID_FLEET_STARTER = Deno.env.get('STRIPE_PRICE_ID_FLEET_STARTER') ?? '';
const STRIPE_PRICE_ID_FLEET_GROWTH = Deno.env.get('STRIPE_PRICE_ID_FLEET_GROWTH') ?? '';

// past_due keeps access while Stripe retries the card (see
// fn_org_effective_tier); unpaid/canceled/incomplete* do not.
const ACTIVE_STATUSES = new Set(['active', 'trialing', 'past_due']);

function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function toHex(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

async function verifyStripeSignature(
  rawBody: string,
  signatureHeader: string | null,
  secret: string,
): Promise<boolean> {
  if (!signatureHeader || !secret) return false;

  let timestamp = '';
  const signatures: string[] = [];
  for (const part of signatureHeader.split(',')) {
    const [k, v] = part.split('=');
    if (k === 't') timestamp = v;
    // Stripe sends several v1 signatures while a secret is being rolled.
    if (k === 'v1' && v) signatures.push(v);
  }
  if (!timestamp || signatures.length === 0) return false;

  const age = Math.abs(Date.now() / 1000 - Number(timestamp));
  if (!Number.isFinite(age) || age > 300) return false;

  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${timestamp}.${rawBody}`));
  const expected = toHex(sig);
  return signatures.some((s) => constantTimeEqual(expected, s));
}

async function stripeApi(path: string, init: RequestInit = {}): Promise<any> {
  const res = await fetch(`https://api.stripe.com/v1/${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
  });
  if (!res.ok) throw new Error(`Stripe ${path} -> ${res.status}: ${await res.text()}`);
  return await res.json();
}

/** Latest state of a subscription; falls back to the event's copy without an API key. */
async function freshSubscription(eventSub: any): Promise<any> {
  if (!STRIPE_SECRET_KEY || !eventSub?.id) return eventSub;
  return await stripeApi(`subscriptions/${eventSub.id}`);
}

function periodEnd(sub: any): string | null {
  // Newer API versions moved current_period_end onto the subscription item.
  const end = sub.current_period_end ?? sub.items?.data?.[0]?.current_period_end;
  return end ? new Date(end * 1000).toISOString() : null;
}

async function syncCgcCore(userId: string, plan: string) {
  if (!CGC_ENDPOINT || !CGC_API_KEY) return;
  try {
    const form = new URLSearchParams();
    form.set('org_id', userId);
    form.set('plan', plan);
    const res = await fetch(`${CGC_ENDPOINT}/billing/upgrade`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: `Bearer ${CGC_API_KEY}`,
      },
      body: form.toString(),
    });
    if (!res.ok) console.warn(`[stripe-webhook] CGC Core billing sync returned ${res.status}`);
  } catch (e) {
    console.warn('[stripe-webhook] CGC Core billing sync failed (non-fatal):', e);
  }
}

function must<T extends { error: any }>(result: T, what: string): T {
  if (result.error) throw new Error(`${what}: ${result.error.message ?? result.error}`);
  return result;
}

// The plan comes from the PRICE, not metadata: a Starter -> Growth switch in
// the Stripe customer portal changes the price but keeps the checkout's
// metadata.tier.
function fleetTier(sub: any): 'starter' | 'growth' {
  const priceId = sub.items?.data?.[0]?.price?.id;
  if (priceId && priceId === STRIPE_PRICE_ID_FLEET_GROWTH) return 'growth';
  if (priceId && priceId === STRIPE_PRICE_ID_FLEET_STARTER) return 'starter';
  return sub.metadata?.tier === 'growth' ? 'growth' : 'starter';
}

async function applyFleetSubscription(db: SupabaseClient, sub: any) {
  const organizationId: string | undefined = sub.metadata?.organization_id;
  if (!organizationId) {
    console.warn('[stripe-webhook] fleet subscription with no metadata.organization_id, skipping');
    return;
  }

  const { data: org } = must(
    await db.from('organizations')
      .select('stripe_subscription_id, subscription_status')
      .eq('id', organizationId)
      .maybeSingle(),
    'load organization',
  );
  if (!org) {
    console.warn(`[stripe-webhook] organization ${organizationId} not found (deleted?), skipping`);
    return;
  }

  // An org whose current subscription is a different, live one keeps it:
  // an old or abandoned subscription must not overwrite it.
  const isCurrent = !org.stripe_subscription_id || org.stripe_subscription_id === sub.id;
  if (!isCurrent && ACTIVE_STATUSES.has(org.subscription_status ?? '')) {
    console.warn(`[stripe-webhook] ignoring ${sub.id} (${sub.status}); org ${organizationId} is on ${org.stripe_subscription_id}`);
    return;
  }

  must(
    await db.from('organizations').update({
      stripe_customer_id: sub.customer,
      stripe_subscription_id: sub.id,
      subscription_tier: fleetTier(sub),
      subscription_status: sub.status,
      subscription_vehicle_count: sub.items?.data?.[0]?.quantity ?? null,
      subscription_updated_at: new Date().toISOString(),
    }).eq('id', organizationId),
    'update organization',
  );
}

async function applyPersonalSubscription(db: SupabaseClient, sub: any) {
  const userId: string | undefined = sub.metadata?.user_id;
  if (!userId) {
    console.warn(`[stripe-webhook] subscription ${sub.id} with no metadata.user_id, skipping`);
    return;
  }
  const tier = sub.metadata?.tier === 'base' ? 'base' : 'premium';

  must(
    await db.from('subscriptions').upsert(
      {
        user_id: userId,
        stripe_customer_id: sub.customer,
        stripe_subscription_id: sub.id,
        status: sub.status,
        price_id: sub.items?.data?.[0]?.price?.id ?? null,
        tier,
        current_period_end: periodEnd(sub),
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'stripe_subscription_id' },
    ),
    'upsert subscription',
  );

  // Play + Stripe together decide Basic/Premium.
  must(await db.rpc('recompute_personal_entitlements', { p_user: userId }), 'recompute entitlements');

  // Never auto-downgrades CGC Core (see the original 2026-08-28 note): only
  // a newly premium user is synced.
  if (tier === 'premium' && ACTIVE_STATUSES.has(sub.status)) {
    await syncCgcCore(userId, CGC_PLAN_FOR_SUBSCRIBED);
  }
}

/** Before a fleet renewal, bill the vehicles the org has now. */
async function syncFleetSeats(db: SupabaseClient, invoice: any) {
  if (!STRIPE_SECRET_KEY) return;
  const subId: string | undefined =
    typeof invoice.subscription === 'string'
      ? invoice.subscription
      : invoice.parent?.subscription_details?.subscription;
  if (!subId) return;

  const sub = await stripeApi(`subscriptions/${subId}`);
  if (sub.metadata?.scope !== 'fleet' || !sub.metadata?.organization_id) return;
  const item = sub.items?.data?.[0];
  if (!item) return;

  const { data: seats } = must(
    await db.rpc('fn_org_billable_vehicles', { p_org_id: sub.metadata.organization_id }),
    'count billable vehicles',
  );
  const quantity = Math.max(Number(seats) || 1, 1);
  if (quantity === item.quantity) return;

  const form = new URLSearchParams();
  form.set('quantity', String(quantity));
  // The renewal invoice is billed at the new count; no mid-period proration.
  form.set('proration_behavior', 'none');
  await stripeApi(`subscription_items/${item.id}`, { method: 'POST', body: form.toString() });

  must(
    await db.from('organizations')
      .update({ subscription_vehicle_count: quantity, subscription_updated_at: new Date().toISOString() })
      .eq('id', sub.metadata.organization_id),
    'update seat count',
  );
  console.log(`[stripe-webhook] org ${sub.metadata.organization_id} seats ${item.quantity} -> ${quantity}`);
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return respond({ error: 'Method not allowed' }, 405);
  }

  // The signature covers the exact raw bytes -- read text before parsing.
  const rawBody = await req.text();
  const signature = req.headers.get('Stripe-Signature');

  if (!STRIPE_WEBHOOK_SECRET) {
    // 503 so Stripe keeps retrying until the secret is set, instead of the
    // event being dropped for good.
    console.warn('[stripe-webhook] STRIPE_WEBHOOK_SECRET not set');
    return respond({ received: false, reason: 'not_configured' }, 503);
  }

  if (!(await verifyStripeSignature(rawBody, signature, STRIPE_WEBHOOK_SECRET))) {
    console.error('[stripe-webhook] Signature verification failed');
    return respond({ error: 'Invalid signature' }, 400);
  }

  let event: any;
  try {
    event = JSON.parse(rawBody);
  } catch {
    return respond({ error: 'Invalid JSON' }, 400);
  }

  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  // Idempotency: a duplicate stripe_event_id means it was already processed.
  const { error: insertError } = await db.from('subscription_events').insert({
    stripe_event_id: event.id,
    event_type: event.type,
    user_id: event.data?.object?.metadata?.user_id ?? null,
    payload: event,
  });
  if (insertError) {
    if (insertError.code === '23505') return respond({ received: true, duplicate: true });
    console.error('[stripe-webhook] Failed to log event:', insertError);
    return respond({ error: 'Could not record event' }, 500);
  }

  try {
    switch (event.type) {
      case 'customer.subscription.created':
      case 'customer.subscription.updated':
      case 'customer.subscription.deleted':
      case 'customer.subscription.paused':
      case 'customer.subscription.resumed': {
        const sub = await freshSubscription(event.data.object);
        if (sub.metadata?.scope === 'fleet') {
          await applyFleetSubscription(db, sub);
        } else {
          await applyPersonalSubscription(db, sub);
        }
        break;
      }
      case 'invoice.upcoming':
        await syncFleetSeats(db, event.data.object);
        break;
      default:
        // checkout.session.completed, invoice.payment_failed, ...: kept in
        // subscription_events for the record; customer.subscription.* is
        // the single source of truth for status.
        break;
    }
    return respond({ received: true });
  } catch (err: any) {
    console.error(`[stripe-webhook] ${event.type} ${event.id} failed:`, err);
    // Let Stripe retry: forget the event so the retry isn't a "duplicate".
    await db.from('subscription_events').delete().eq('stripe_event_id', event.id);
    return respond({ error: 'Processing failed' }, 500);
  }
});
