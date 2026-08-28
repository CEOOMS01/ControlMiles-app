// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/cgc-seal-trip/index.ts
//
// Connects a just-closed trip to CGC Core's governance pipeline
// (https://cgc-cre.vercel.app, see [[project_cgc_core]]): POST
// /governance/decision runs a real multi-module governance pipeline and
// PoD (Proof-of-Decision) cryptographically seals the outcome -- SHA-256
// triplet hash + RSA-PSS signature, chained into CGC Core's own Postgres.
// This closes ControlMiles' own flagged gap: the antifraud engine and its
// hash-chain audit log (audit_service.dart) run entirely client-side --
// nothing server-side proves a trip record wasn't fabricated. This
// function is the server-side hop that adds an independent, non-client
// proof, same pattern LedgiProof already uses for transaction
// classification (supabase/functions/cgc-evaluate in that repo).
//
// Security: session_id comes from the body, but everything else
// (ownership, org_id, total_miles, duration, vehicle_id, the acting
// user's real email) is derived server-side from a SELECT run with the
// CALLER's own JWT (userClient, not the service role) -- Postgres RLS is
// what actually decides whether this caller may see/seal that session
// (owner, or an org admin for a Fleet trip), matching this project's
// existing sessions RLS rather than re-implementing that check here. The
// only client-supplied values forwarded to CGC Core are the antifraud
// tick counters (total_gps_ticks/rejected_gps_ticks/
// min_driving_signature_score) -- diagnostic signal only, not the mileage
// figure itself, which always comes from the verified DB row.
//
// Best-effort by design: sealing must never block or fail trip-close for
// the driver. Any failure here (CGC Core down, not configured, timeout)
// returns a 200 with sealed:false rather than an error -- the caller
// (TrackingController.stopTracking) doesn't await this anyway.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const CGC_ENDPOINT = Deno.env.get('CGC_ENDPOINT') ?? '';
const CGC_API_KEY = Deno.env.get('CGC_API_KEY') ?? '';
const CGC_TIMEOUT_MS = 10000; // Vercel cold starts on CGC Core (SCM/KMS,
// TCO, ComplianceEngine init) can comfortably exceed 5s on the first call
// after idle -- same value LedgiProof's report-error uses, tuned live.

// Security hardening (2026-08-28): same Postgres-backed pattern as
// create-checkout-session's own rate limiter (see its comment for why
// this isn't an in-memory Map) -- a normal driver seals one trip at a
// time, at most a handful per hour; this only stops a compromised token
// from spamming CGC Core through this function.
const RATE_LIMIT_MAX = 15;
const RATE_LIMIT_WINDOW_SECONDS = 60;

async function isRateLimited(client: ReturnType<typeof createClient>, clientId: string): Promise<boolean> {
  const { data, error } = await client.rpc('check_rate_limit', {
    p_fn_name: 'cgc-seal-trip',
    p_client_key: clientId,
    p_max_requests: RATE_LIMIT_MAX,
    p_window_seconds: RATE_LIMIT_WINDOW_SECONDS,
  });
  if (error) {
    console.warn('[cgc-seal-trip] rate limit check failed (failing open):', error);
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
      return respond({ sealed: false, reason: 'Missing Authorization header' }, 401);
    }

    let body: {
      session_id?: string;
      total_gps_ticks?: number;
      rejected_gps_ticks?: number;
      min_driving_signature_score?: number;
    };
    try {
      body = await req.json();
    } catch {
      return respond({ sealed: false, reason: 'Invalid JSON body' }, 400);
    }

    if (!body.session_id) {
      return respond({ sealed: false, reason: 'Missing required field: session_id' }, 400);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

    // User-scoped client -- RLS decides visibility, not this function.
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData?.user) {
      return respond({ sealed: false, reason: 'Invalid or expired session' }, 401);
    }

    if (await isRateLimited(userClient, userData.user.id)) {
      return respond({ sealed: false, reason: 'rate_limited' }, 429);
    }

    const { data: session, error: sessionError } = await userClient
      .from('sessions')
      .select('id, user_id, organization_id, vehicle_id, total_miles, total_duration_seconds, session_status')
      .eq('id', body.session_id)
      .maybeSingle();

    if (sessionError || !session) {
      // RLS made this look identical to "doesn't exist" whether it's
      // truly missing or just not visible to this caller -- correct,
      // don't leak which.
      return respond({ sealed: false, reason: 'Session not found or not accessible' }, 404);
    }

    if (session.session_status !== 'closed') {
      return respond({ sealed: false, reason: 'Session is not closed yet' }, 400);
    }

    if (!CGC_ENDPOINT || !CGC_API_KEY) {
      return respond({ sealed: false, reason: 'CGC governance not configured' }, 200);
    }

    // Fleet trip -> the org is the real tenant; Gig trip -> the driver's
    // own user id is the tenant, so one compromised individual account
    // can only ever exhaust its own CGC Core rate-limit/quota bucket,
    // never another driver's.
    const orgId: string = session.organization_id ?? session.user_id;

    const inputData = {
      trip_id: session.id,
      total_miles: session.total_miles,
      duration_seconds: session.total_duration_seconds,
      vehicle_id: session.vehicle_id,
      total_gps_ticks: body.total_gps_ticks ?? null,
      rejected_gps_ticks: body.rejected_gps_ticks ?? null,
      min_driving_signature_score: body.min_driving_signature_score ?? null,
    };

    const form = new URLSearchParams();
    form.set('org_id', orgId);
    form.set('action', 'controlmiles.trip_completed');
    form.set('input_data', JSON.stringify(inputData));
    form.set('user_email', userData.user.email ?? 'unknown@controlmiles');
    form.set('data_domains', JSON.stringify(['mileage_tracking']));
    form.set('app_source', 'controlmiles');

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), CGC_TIMEOUT_MS);

    let cgcRes: Response;
    try {
      cgcRes = await fetch(`${CGC_ENDPOINT}/governance/decision`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          Authorization: `Bearer ${CGC_API_KEY}`,
        },
        body: form.toString(),
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timeout);
    }

    if (!cgcRes.ok) {
      const text = await cgcRes.text();
      console.warn(`[cgc-seal-trip] CGC Core returned ${cgcRes.status}: ${text}`);
      return respond({ sealed: false, reason: `CGC Core error ${cgcRes.status}` }, 200);
    }

    const data = await cgcRes.json();
    const decisionId: string | undefined = data?.decision_id;

    if (decisionId) {
      // Same userClient -- RLS governs this write too (owner or org
      // admin), consistent with the read above.
      await userClient
        .from('sessions')
        .update({ cgc_decision_id: decisionId, cgc_sealed_at: new Date().toISOString() })
        .eq('id', session.id);
    }

    return respond({ sealed: !!decisionId, decision_id: decisionId ?? null });
  } catch (err: any) {
    if (err?.name === 'AbortError') {
      return respond({ sealed: false, reason: 'CGC Core timeout' }, 200);
    }
    console.error('[cgc-seal-trip] Unexpected error:', err);
    return respond({ sealed: false, reason: err?.message ?? 'Internal error' }, 200);
  }
});
