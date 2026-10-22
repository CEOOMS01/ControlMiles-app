// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/resolve-driver-login/index.ts
//
// Fleet driver ID login (explicit user request, 2026-09-17): a
// fleet_driver account logs in with their CM-D#### ID instead of email
// (and, since 2026-10-22, a school bus parent with their CM-###### ID) --
// but Supabase Auth itself only ever authenticates by email under the
// hood, so this is the translation layer. No user JWT exists on this
// call (the caller isn't logged in yet -- that's the whole point),
// verify_jwt stays false, same shape as check-email-exists.
//
// SECURITY: this endpoint performs a REAL password check (via
// signInWithPassword using the anon key, server-side -- exactly what the
// Supabase client SDK itself does, just proxied through here instead of
// called directly from the device), so it's a genuine credential-guessing
// target.
// Two independent defenses, both required:
//   1. The error response is IDENTICAL whether the ID doesn't exist, the
//      ID exists but isn't claimed, or the password is wrong -- never
//      reveals which case it was, so this can't be used to enumerate
//      real IDs (owner's rule: no public screen reveals which emails or
//      IDs exist).
//   2. Rate-limited on BOTH the caller's IP AND the display_id itself
//      (dual-key, unlike every other rate limiter in this project) --
//      IP alone doesn't stop an attacker spread across many IPs from
//      hammering one specific driver's account; display_id alone doesn't
//      stop one attacker IP from spraying many IDs.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const RATE_LIMIT_MAX = 5;
const RATE_LIMIT_WINDOW_SECONDS = 300;

function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function isRateLimited(adminClient: ReturnType<typeof createClient>, fnName: string, clientKey: string): Promise<boolean> {
  const { data, error } = await adminClient.rpc('check_rate_limit', {
    p_fn_name: fnName,
    p_client_key: clientKey,
    p_max_requests: RATE_LIMIT_MAX,
    p_window_seconds: RATE_LIMIT_WINDOW_SECONDS,
  });
  if (error) {
    console.warn(`[resolve-driver-login] rate limit check failed for ${fnName} (failing open):`, error);
    return false;
  }
  return !data;
}

// Every error carries its code from ERROR_CODES.md and a message the apps'
// AppError.from() recognizes. A wrong ID and a wrong password are the SAME
// error on purpose (400, invalid credentials) -- see this file's header.
const INVALID_CREDENTIALS = { error: 'Invalid credentials', code: 400 };
const RATE_LIMITED = { error: 'Too many attempts. Try again in a few minutes.', code: 420 };
const UNEXPECTED = { error: 'Unexpected server error', code: 701 };

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const clientIp = req.headers.get('x-forwarded-for')?.split(',')[0].trim()
      ?? req.headers.get('cf-connecting-ip')
      ?? 'unknown';

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    if (await isRateLimited(adminClient, 'resolve-driver-login-ip', clientIp)) {
      return respond(RATE_LIMITED, 429);
    }

    let displayId: string | undefined;
    let password: string | undefined;
    try {
      const body = await req.json();
      displayId = typeof body?.display_id === 'string' ? body.display_id.trim().toUpperCase() : undefined;
      password = typeof body?.password === 'string' ? body.password : undefined;
    } catch {
      return respond(UNEXPECTED, 400);
    }

    if (!displayId || !password) {
      return respond(INVALID_CREDENTIALS, 400);
    }

    if (await isRateLimited(adminClient, 'resolve-driver-login-id', displayId)) {
      return respond(RATE_LIMITED, 429);
    }

    // Only a CLAIMED driver slot (claimed_by not null) has a real account
    // behind it -- an admin-created, not-yet-confirmed slot has no password
    // to check against at all. Not a driver ID: a school bus parent's ID
    // (CM-######, school_guardians, 2026-10-22), active and accepted.
    // Same error (400, invalid credentials) either way.
    const { data: slot, error: slotError } = await adminClient
      .from('fleet_driver_slots')
      .select('claimed_by')
      .eq('display_id', displayId)
      .not('claimed_by', 'is', null)
      .maybeSingle();

    let accountId: string | null = slotError ? null : (slot?.claimed_by ?? null);
    if (!accountId) {
      const { data: guardianUser, error: guardianError } = await adminClient
        .rpc('guardian_login_user', { p_display_id: displayId });
      accountId = guardianError ? null : ((guardianUser as string | null) ?? null);
    }

    if (!accountId) {
      return respond(INVALID_CREDENTIALS, 401);
    }

    const { data: profile, error: profileError } = await adminClient
      .from('profiles')
      .select('email')
      .eq('id', accountId)
      .maybeSingle();

    if (profileError || !profile?.email) {
      return respond(INVALID_CREDENTIALS, 401);
    }

    // The real password check -- same mechanism the client SDK itself
    // uses, just proxied server-side so the app never needs to know this
    // account's real email.
    const authClient = createClient(supabaseUrl, anonKey);
    const { data: signInData, error: signInError } = await authClient.auth.signInWithPassword({
      email: profile.email,
      password,
    });

    if (signInError || !signInData.session) {
      return respond(INVALID_CREDENTIALS, 401);
    }

    return respond({
      access_token: signInData.session.access_token,
      refresh_token: signInData.session.refresh_token,
    });
  } catch (err: any) {
    console.error('[resolve-driver-login] Unexpected error:', err);
    return respond(UNEXPECTED, 500);
  }
});
