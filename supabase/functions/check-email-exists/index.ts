// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/check-email-exists/index.ts
//
// Pre-auth check for the "forgot password" screen (explicit user request,
// 2026-09-04): before ControlMiles ever calls Supabase's own
// resetPasswordForEmail(), the app needs to know whether the typed email
// actually has a ControlMiles account -- if not, show an in-app "this
// email isn't linked to ControlMiles" message and send NO email at all.
//
// SECURITY TRADEOFF, disclosed explicitly (not hidden in a comment nobody
// reads): Supabase's own resetPasswordForEmail() deliberately returns the
// same response whether or not the email exists -- that's the industry-
// standard defense against user enumeration (an attacker probing which
// emails have accounts). This endpoint is the opposite on purpose, per
// explicit product decision: it tells the caller yes/no. Rate-limited by
// IP (same Postgres-backed check_rate_limit() every other public endpoint
// in this project already uses) to at least slow down bulk harvesting,
// but a determined attacker with many IPs can still enumerate real
// ControlMiles accounts through this endpoint. That's a real, accepted
// cost of the requested UX, not an oversight.
//
// No auth required -- this must work before the user has a session
// (that's the whole point of "forgot password").

import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

// Stricter than most public endpoints in this project (report-error is
// 10/60s) -- this one exists specifically to answer "does this email have
// an account", so it needs a tighter ceiling than a crash-report sink.
const RATE_LIMIT_MAX = 8;
const RATE_LIMIT_WINDOW_SECONDS = 60;

function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function isRateLimited(client: ReturnType<typeof createClient>, clientId: string): Promise<boolean> {
  const { data, error } = await client.rpc('check_rate_limit', {
    p_fn_name: 'check-email-exists',
    p_client_key: clientId,
    p_max_requests: RATE_LIMIT_MAX,
    p_window_seconds: RATE_LIMIT_WINDOW_SECONDS,
  });
  if (error) {
    // Fails open, same convention as every other rate-limit check in this
    // project -- a broken limiter must never block the real feature.
    console.warn('[check-email-exists] rate limit check failed (failing open):', error);
    return false;
  }
  return !data;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const clientId = req.headers.get('x-forwarded-for')?.split(',')[0].trim()
      ?? req.headers.get('cf-connecting-ip')
      ?? 'unknown';

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const anonClient = createClient(supabaseUrl, anonKey);

    if (await isRateLimited(anonClient, clientId)) {
      return respond({ exists: false, reason: 'rate_limited' }, 429);
    }

    let email: string | undefined;
    try {
      const body = await req.json();
      email = typeof body?.email === 'string' ? body.email.trim() : undefined;
    } catch {
      return respond({ error: 'Invalid JSON body' }, 400);
    }
    if (!email) {
      return respond({ error: 'Missing required field: email' }, 400);
    }

    // Service-role client -- profiles' own RLS (profiles_select_own) only
    // ever lets a user read their OWN row, which is exactly wrong for this
    // check (the caller has no session yet). This lookup is the entire
    // reason this function needs to exist server-side at all, rather than
    // as a plain client-side query.
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data, error } = await adminClient
      .from('profiles')
      .select('id')
      .ilike('email', email)
      .limit(1)
      .maybeSingle();

    if (error) {
      console.error('[check-email-exists] profiles lookup failed:', error);
      return respond({ error: 'Lookup failed' }, 500);
    }

    return respond({ exists: !!data });
  } catch (err: any) {
    console.error('[check-email-exists] Unexpected error:', err);
    return respond({ error: err?.message ?? 'Internal error' }, 500);
  }
});
