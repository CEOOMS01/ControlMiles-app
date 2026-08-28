// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/report-error/index.ts
//
// Client crash-report proxy -- forwards Flutter uncaught exceptions
// (FlutterError.onError / PlatformDispatcher.instance.onError, wired in
// main.dart) to CGC Core's /monitor/error endpoint, same pattern
// LedgiProof and LedgiProof Tax Pro already use (see [[project_cgc_core]]
// -- report-error in that repo is the template this mirrors).
//
// Deliberately requires NO signed-in user: a crash on the login screen or
// before a session exists is exactly the kind worth catching, so this
// only needs the app's anon key (sent automatically by
// supabase.functions.invoke()), not an authenticated session.
//
// Never fails loudly to the caller -- error reporting must not itself
// become a source of errors in the app.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const CGC_ENDPOINT = Deno.env.get('CGC_ENDPOINT') ?? '';
const CGC_API_KEY = Deno.env.get('CGC_API_KEY') ?? '';

// Security hardening (2026-08-28): this endpoint deliberately requires no
// signed-in user (see comment above) -- that also makes it the one
// ControlMiles edge function reachable by anyone holding the public anon
// key, with no per-user identity to scope abuse to. Each call also fans
// out to a real outbound request to CGC Core, so unbounded spam here is
// both a local cost (this function's own invocations) and an
// amplification vector against CGC Core's own quota.
//
// REAL FIX, not the first attempt: an in-memory Map-based limiter was
// tried first and verified LIVE to NOT work -- a genuine 25-request
// concurrent burst against this exact function returned 200 every time,
// zero 429s. Supabase's Deno edge runtime doesn't reliably share
// module-level state across invocations the way a traditional warm
// server does. Replaced with check_rate_limit(), a real Postgres-backed
// SECURITY DEFINER function (see migration
// 20260828100000_create_edge_function_rate_limiter.sql) -- durable,
// correct under concurrency (advisory-locked), the same fix CGC Core's
// own TenantManager already needed for the identical reason.
const RATE_LIMIT_MAX = 10;
const RATE_LIMIT_WINDOW_SECONDS = 60;

async function isRateLimited(clientId: string): Promise<boolean> {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const client = createClient(supabaseUrl, anonKey);
  const { data, error } = await client.rpc('check_rate_limit', {
    p_fn_name: 'report-error',
    p_client_key: clientId,
    p_max_requests: RATE_LIMIT_MAX,
    p_window_seconds: RATE_LIMIT_WINDOW_SECONDS,
  });
  if (error) {
    // Fails open, same as every other guard in this project's edge
    // functions -- a broken rate-limit check must never block a real
    // crash report from being recorded.
    console.warn('[report-error] rate limit check failed (failing open):', error);
    return false;
  }
  return !data;
}

// Authoritative allow-list lives server-side in CGC Core itself
// (api/v1/endpoints/monitor.py's ALLOWED_APP_SOURCES) -- this is just the
// same client-side pre-check LedgiProof's report-error already does, to
// fail fast without a round trip for an obviously wrong app_source.
const ALLOWED_APP_SOURCES = new Set(['controlmiles']);

interface ErrorReportBody {
  app_source: string;
  environment?: string;
  severity?: string;
  message: string;
  stack?: string;
  context?: Record<string, unknown>;
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
    const clientId = req.headers.get('x-forwarded-for')?.split(',')[0].trim()
      ?? req.headers.get('cf-connecting-ip')
      ?? 'unknown';
    if (await isRateLimited(clientId)) {
      return respond({ accepted: false, reason: 'rate_limited' }, 429);
    }

    const body: ErrorReportBody = await req.json();

    if (!body.message || typeof body.message !== 'string') {
      return respond({ accepted: false, reason: 'Missing required field: message' }, 400);
    }
    if (!ALLOWED_APP_SOURCES.has(body.app_source)) {
      return respond({ accepted: false, reason: 'Invalid app_source' }, 400);
    }

    if (!CGC_ENDPOINT || !CGC_API_KEY) {
      // Monitoring not configured for this environment -- drop silently, not an error.
      return respond({ accepted: false, reason: 'monitoring_not_configured' }, 200);
    }

    const payload = {
      app_source: body.app_source,
      environment: body.environment ?? 'production',
      severity: body.severity ?? 'error',
      message: body.message.slice(0, 2000),
      stack: (body.stack ?? '').slice(0, 4000),
      context: body.context ?? {},
    };

    const controller = new AbortController();
    // 10s, not 5s -- Vercel cold starts on CGC Core can comfortably
    // exceed 5s on the first call after idle (same tuning LedgiProof's
    // report-error already settled on, live).
    const timeout = setTimeout(() => controller.abort(), 10000);

    let cgcRes: Response;
    try {
      cgcRes = await fetch(`${CGC_ENDPOINT}/monitor/error`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${CGC_API_KEY}`,
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timeout);
    }

    if (!cgcRes.ok) {
      const text = await cgcRes.text();
      console.warn(`[report-error] CGC Core returned ${cgcRes.status}: ${text}`);
      return respond({ accepted: false, reason: `CGC Core error ${cgcRes.status}` }, 200);
    }

    const data = await cgcRes.json();
    return respond({ accepted: true, ...data }, 200);
  } catch (err: any) {
    console.error('[report-error] error:', err);
    // Swallow -- a broken monitoring pipe must never surface to the caller.
    return respond({ accepted: false, reason: err?.message ?? 'unknown error' }, 200);
  }
});
