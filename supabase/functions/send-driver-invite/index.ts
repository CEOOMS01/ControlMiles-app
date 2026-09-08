// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/send-driver-invite/index.ts
//
// Fleet Sprint 1 (explicit user spec, 2026-09-04): sends the actual
// invite email for the driver_invites/create_driver_invite/
// resolve_driver_invite/accept_driver_invite flow added in migration
// 20260904060000_driver_invites.sql. Splitting the concerns this way
// on purpose: create_driver_invite (a plain RPC, called directly by the
// Flutter app) already does the authorization check (is_org_admin_or_owner)
// and generates the token -- this function's ONLY job is to actually
// deliver the email via Resend, which needs a server-side API key the
// Flutter app must never hold.
//
// This function does NOT trust the caller's supplied email/org_name --
// it re-resolves the token itself with the service-role client (same
// resolve_driver_invite RPC the public landing screen uses) so a caller
// can never use this endpoint to send an arbitrary email to an arbitrary
// address; it can only ever send the email that create_driver_invite
// already committed to the database for that exact token.
//
// Deep link lands on the (separate, follow-up) mobile invite landing
// screen at https://controlmiles.com/invite/<token>.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
const INVITE_SENDER_EMAIL = Deno.env.get('INVITE_SENDER_EMAIL') ?? 'invites@controlmiles.com';
const INVITE_LINK_BASE = 'https://controlmiles.com/invite';

// Authenticated endpoint (org admin/owner only, in practice) -- keyed by
// user_id, same reasoning as create-checkout-session: the real identity
// is more precise than a shared IP, and a legitimate admin never needs
// more than a handful of these per minute.
const RATE_LIMIT_MAX = 10;
const RATE_LIMIT_WINDOW_SECONDS = 60;

function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function isRateLimited(client: ReturnType<typeof createClient>, clientId: string): Promise<boolean> {
  const { data, error } = await client.rpc('check_rate_limit', {
    p_fn_name: 'send-driver-invite',
    p_client_key: clientId,
    p_max_requests: RATE_LIMIT_MAX,
    p_window_seconds: RATE_LIMIT_WINDOW_SECONDS,
  });
  if (error) {
    console.warn('[send-driver-invite] rate limit check failed (failing open):', error);
    return false;
  }
  return !data;
}

function buildEmailHtml(orgName: string, inviteUrl: string): string {
  const safeOrgName = orgName.replace(/[<>&]/g, '');
  return `
    <div style="font-family: -apple-system, Segoe UI, Roboto, sans-serif; max-width: 480px; margin: 0 auto;">
      <h2 style="color:#111827;">You've been invited to join ${safeOrgName} on ControlMiles</h2>
      <p style="color:#374151; line-height:1.5;">
        <strong>${safeOrgName}</strong> has invited you to join their fleet on ControlMiles
        as a driver. Tap the link below to accept the invitation:
      </p>
      <p style="text-align:center; margin:32px 0;">
        <a href="${inviteUrl}" style="background:#2563eb; color:#fff; padding:12px 24px; border-radius:8px; text-decoration:none; font-weight:600;">
          Accept invitation
        </a>
      </p>
      <p style="color:#9ca3af; font-size:13px;">
        This link expires in 7 days. If you weren't expecting this invitation, you can safely ignore this email.
      </p>
    </div>
  `;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (!RESEND_API_KEY) {
      console.error('[send-driver-invite] RESEND_API_KEY not configured');
      return respond({ error: 'Email delivery is not configured' }, 503);
    }

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return respond({ error: 'Missing Authorization header' }, 401);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

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

    let token: string | undefined;
    try {
      const body = await req.json();
      token = typeof body?.token === 'string' ? body.token.trim() : undefined;
    } catch {
      return respond({ error: 'Invalid JSON body' }, 400);
    }
    if (!token) {
      return respond({ error: 'Missing required field: token' }, 400);
    }

    // Service-role client for the re-resolve + admin-check below --
    // resolve_driver_invite itself is granted to anon, but the
    // organization_members admin check that follows needs to bypass RLS
    // to look at a row that doesn't belong to the caller as "self".
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: resolved, error: resolveError } = await adminClient
      .rpc('resolve_driver_invite', { p_token: token })
      .maybeSingle();

    if (resolveError || !resolved || !resolved.valid) {
      return respond({ error: 'Invalid or expired invite' }, 400);
    }

    // Defense in depth: create_driver_invite already required the caller
    // to be an admin/owner to mint this token in the first place, but
    // re-check here too since this endpoint is the one actually spending
    // Resend sends -- never trust that a valid session alone means
    // "authorized to send this specific invite".
    const { data: inviteRow, error: inviteRowError } = await adminClient
      .from('driver_invites')
      .select('organization_id')
      .eq('token_hash', await sha256Hex(token))
      .maybeSingle();

    if (inviteRowError || !inviteRow) {
      return respond({ error: 'Invalid or expired invite' }, 400);
    }

    // Not using the is_org_admin_or_owner RPC here -- it reads auth.uid()
    // internally, which is NULL for a service-role call. Direct row check
    // against the caller's own user id instead.
    const { data: membership } = await adminClient
      .from('organization_members')
      .select('member_role')
      .eq('organization_id', inviteRow.organization_id)
      .eq('user_id', userData.user.id)
      .eq('is_active', true)
      .maybeSingle();

    if (!membership || !['owner', 'admin'].includes(membership.member_role)) {
      return respond({ error: 'Only an org admin or owner can send this invite' }, 403);
    }

    const inviteUrl = `${INVITE_LINK_BASE}/${token}`;

    const resendResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: `ControlMiles <${INVITE_SENDER_EMAIL}>`,
        to: [resolved.email],
        subject: `${resolved.organization_name} invited you to ControlMiles`,
        html: buildEmailHtml(resolved.organization_name, inviteUrl),
      }),
    });

    if (!resendResponse.ok) {
      const errText = await resendResponse.text();
      console.error('[send-driver-invite] Resend API error:', resendResponse.status, errText);
      return respond({ error: 'Failed to send invite email' }, 502);
    }

    return respond({ sent: true });
  } catch (err: any) {
    console.error('[send-driver-invite] Unexpected error:', err);
    return respond({ error: err?.message ?? 'Internal error' }, 500);
  }
});

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}
