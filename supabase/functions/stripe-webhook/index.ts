// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/stripe-webhook/index.ts
//
// Receives Stripe's own server-to-server webhook calls -- this is the
// ONLY place profiles.premium_entitled gets flipped by a real
// subscription event (see [[project_controlmiles]]). No user JWT exists
// on this call (Stripe is calling us, not the app), so authenticity
// comes entirely from verifying the Stripe-Signature header against
// STRIPE_WEBHOOK_SECRET -- constant-time HMAC-SHA256 comparison, per
// Stripe's own documented scheme, implemented directly (no extra SDK
// dependency needed for just this).
//
// Idempotency: Stripe redelivers events (network retries, manual resend
// from the dashboard) -- stripe_event_id is UNIQUE on subscription_events,
// so a duplicate delivery is detected and skipped before touching
// subscriptions/profiles at all, rather than double-processing.
//
// subscription.metadata.user_id (set at Checkout time by
// create-checkout-session's subscription_data[metadata][user_id]) is how
// every subscription.* event here knows which ControlMiles user it's
// about, without a second API call back to Stripe.
//
// Runs as the service role (no caller JWT to scope a userClient to) --
// this is the one legitimate place in this project's subscription code
// that needs to write across users, since Stripe's own call is the
// authority here, not any one user's session.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const STRIPE_WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? '';
const CGC_ENDPOINT = Deno.env.get('CGC_ENDPOINT') ?? '';
const CGC_API_KEY = Deno.env.get('CGC_API_KEY') ?? '';
// Best-effort sync only (see verifyAndUpsert below) -- not a hardcoded
// business decision about what ControlMiles Premium "should" map to in
// CGC Core's own quota tiers. STANDARD is CGC Core's own existing
// default for any unregistered org, so this call is largely a
// confirmation today; change this env var if/when a real decision is
// made to give paying ControlMiles users higher CGC Core quotas.
const CGC_PLAN_FOR_SUBSCRIBED = Deno.env.get('CGC_PLAN_FOR_SUBSCRIBED') ?? 'STANDARD';

const ACTIVE_STATUSES = new Set(['active', 'trialing']);

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

  const parts = Object.fromEntries(
    signatureHeader.split(',').map((p) => {
      const [k, v] = p.split('=');
      return [k, v];
    }),
  );
  const timestamp = parts['t'];
  const v1 = parts['v1'];
  if (!timestamp || !v1) return false;

  // Replay protection -- reject anything older than 5 minutes, Stripe's
  // own documented tolerance.
  const age = Math.abs(Date.now() / 1000 - Number(timestamp));
  if (!Number.isFinite(age) || age > 300) return false;

  const signedPayload = `${timestamp}.${rawBody}`;
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(signedPayload));
  return constantTimeEqual(toHex(sig), v1);
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
    if (!res.ok) {
      console.warn(`[stripe-webhook] CGC Core billing sync returned ${res.status}`);
    }
  } catch (e) {
    console.warn('[stripe-webhook] CGC Core billing sync failed (non-fatal):', e);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return respond({ error: 'Method not allowed' }, 405);
  }

  // Signature is computed over the exact raw bytes Stripe sent -- must
  // read as text BEFORE any JSON parsing, or the signature will never
  // match (re-serialized JSON is not byte-identical to what was signed).
  const rawBody = await req.text();
  const signature = req.headers.get('Stripe-Signature');

  if (!STRIPE_WEBHOOK_SECRET) {
    // Not configured yet -- 200 so Stripe doesn't retry forever, but
    // never process an unverifiable event.
    console.warn('[stripe-webhook] STRIPE_WEBHOOK_SECRET not set, dropping event');
    return respond({ received: false, reason: 'not_configured' });
  }

  const verified = await verifyStripeSignature(rawBody, signature, STRIPE_WEBHOOK_SECRET);
  if (!verified) {
    console.error('[stripe-webhook] Signature verification failed');
    return respond({ error: 'Invalid signature' }, 400);
  }

  let event: any;
  try {
    event = JSON.parse(rawBody);
  } catch {
    return respond({ error: 'Invalid JSON' }, 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  try {
    // Idempotency guard -- a UNIQUE violation on stripe_event_id means
    // this exact event was already processed; treat as a clean no-op,
    // not an error (Stripe still gets its 200, stops retrying).
    const { error: insertError } = await adminClient
      .from('subscription_events')
      .insert({
        stripe_event_id: event.id,
        event_type: event.type,
        user_id: event.data?.object?.metadata?.user_id ?? null,
        payload: event,
      });

    if (insertError) {
      if (insertError.code === '23505') {
        return respond({ received: true, duplicate: true });
      }
      console.error('[stripe-webhook] Failed to log event:', insertError);
      // Still fall through -- logging failure shouldn't block processing
      // a real, newly-seen event.
    }

    if (event.type === 'customer.subscription.created' || event.type === 'customer.subscription.updated') {
      const sub = event.data.object;
      const userId: string | undefined = sub.metadata?.user_id;
      if (userId) {
        const status = sub.status as string;
        const priceId = sub.items?.data?.[0]?.price?.id ?? null;
        const currentPeriodEnd = sub.current_period_end
          ? new Date(sub.current_period_end * 1000).toISOString()
          : null;

        await adminClient.from('subscriptions').upsert(
          {
            user_id: userId,
            stripe_customer_id: sub.customer,
            stripe_subscription_id: sub.id,
            status,
            price_id: priceId,
            current_period_end: currentPeriodEnd,
            updated_at: new Date().toISOString(),
          },
          { onConflict: 'stripe_subscription_id' },
        );

        const entitled = ACTIVE_STATUSES.has(status);
        await adminClient
          .from('profiles')
          .update({ premium_entitled: entitled })
          .eq('id', userId);

        // Only sync CGC Core on becoming entitled -- deliberately never
        // auto-downgrades a tenant's CGC Core plan on a bad/cancelled
        // subscription, since that could unexpectedly throttle a real
        // user's governance rate-limit far below what they were already
        // using. CGC Core's plan stays whatever it already was; someone
        // can always adjust it directly via /billing/upgrade later.
        if (entitled) {
          await syncCgcCore(userId, CGC_PLAN_FOR_SUBSCRIBED);
        }
      } else {
        console.warn(`[stripe-webhook] ${event.type} with no metadata.user_id, skipping`);
      }
    } else if (event.type === 'customer.subscription.deleted') {
      const sub = event.data.object;
      const userId: string | undefined = sub.metadata?.user_id;

      await adminClient
        .from('subscriptions')
        .update({ status: 'canceled', updated_at: new Date().toISOString() })
        .eq('stripe_subscription_id', sub.id);

      if (userId) {
        await adminClient.from('profiles').update({ premium_entitled: false }).eq('id', userId);
      }
    }
    // checkout.session.completed / invoice.payment_failed: already
    // recorded in subscription_events above for audit visibility.
    // checkout.session.completed's own object doesn't carry the full
    // subscription (status/price/period), and invoice.payment_failed
    // doesn't necessarily mean a final cancellation (Stripe's dunning
    // can still resolve it) -- both are intentionally NOT what drives
    // subscriptions/profiles here, customer.subscription.* is the single
    // source of truth for that, to avoid two code paths disagreeing.

    return respond({ received: true });
  } catch (err: any) {
    console.error('[stripe-webhook] Processing error:', err);
    // Still 200 -- once the event is durably logged in
    // subscription_events above, a processing bug shouldn't cause Stripe
    // to retry indefinitely; the raw event is preserved for manual
    // reconciliation either way.
    return respond({ received: true, processing_error: err?.message ?? 'unknown' });
  }
});
