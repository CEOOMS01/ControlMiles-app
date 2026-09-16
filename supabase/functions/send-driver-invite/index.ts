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

async function isRateLimited(clientId: string): Promise<boolean> {
  // SECURITY (2026-09-16): this RPC is called with the SERVICE-ROLE key, not
  // the anon/user key. check_rate_limit is EXECUTE-revoked from anon and
  // authenticated so that nobody holding the public key can fill another
  // user's bucket (a targeted lockout) or bloat edge_function_rate_limits at
  // will. The service-role key never leaves the edge function.
  const rlClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
  const { data, error } = await rlClient.rpc('check_rate_limit', {
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

// Rediseño de marca (pedido explícito, 2026-09-16): antes era HTML genérico
// azul-sobre-blanco sin logo, sin relación visual con la identidad real de
// controlmiles.com (landing.css: fondo cream #faf6ee, tinta #211c14, azul
// de marca #2c6c99, ámbar #bd5b26, serif Fraunces para titulares). Este
// email ahora usa esa misma paleta y el logo real (servido públicamente
// desde controlmiles-web/public/logo_controlmiles.png) para que sea
// reconocible como ControlMiles desde el primer vistazo, no un correo
// transaccional genérico. Tabla + estilos inline a propósito -- es lo único
// que Outlook/Gmail/Apple Mail renderizan de forma consistente; CSS externo
// o flexbox/grid no son opciones seguras en HTML de email.
function buildEmailHtml(orgName: string, inviteUrl: string): string {
  const safeOrgName = orgName.replace(/[<>&]/g, '');
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>ControlMiles</title>
</head>
<body style="margin:0; padding:0; background-color:#faf6ee; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#faf6ee; padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="max-width:480px; width:100%; background-color:#ffffff; border:1px solid #e3d9c4; border-radius:16px; overflow:hidden;">
          <tr>
            <td style="padding:32px 40px 0 40px;" align="left">
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="vertical-align:middle; padding-right:10px;">
                    <img src="https://controlmiles.com/logo_controlmiles.png" width="32" height="32" alt="ControlMiles" style="display:block; border-radius:8px;">
                  </td>
                  <td style="vertical-align:middle; font-size:19px; font-weight:700; color:#211c14;">
                    Control<span style="color:#2c6c99;">Miles</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:28px 40px 0 40px;">
              <p style="margin:0; font-size:11px; font-weight:600; letter-spacing:0.18em; text-transform:uppercase; color:#bd5b26;">
                FLEET INVITE
              </p>
              <h1 style="margin:10px 0 0 0; font-size:26px; line-height:1.25; font-weight:700; color:#211c14;">
                You've been invited to join<br>${safeOrgName}
              </h1>
              <p style="margin:16px 0 0 0; font-size:15px; line-height:1.6; color:#6b6250;">
                <strong style="color:#211c14;">${safeOrgName}</strong> has invited you to join their fleet on ControlMiles as a driver — GPS trip tracking, odometer verification, and mileage records ready for tax season.
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding:28px 40px 0 40px;" align="center">
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="border-radius:999px; background-color:#2c6c99;">
                    <a href="${inviteUrl}" style="display:inline-block; padding:13px 32px; font-size:15px; font-weight:600; color:#ffffff; text-decoration:none;">
                      Accept invitation
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:24px 40px 32px 40px;">
              <p style="margin:0; font-size:12px; line-height:1.6; color:#9a9080; text-align:center;">
                This link expires in 7 days. If you weren't expecting this invitation, you can safely ignore this email.
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding:18px 40px; background-color:#faf6ee; border-top:1px solid #e3d9c4;" align="center">
              <p style="margin:0; font-size:11px; color:#9a9080;">
                ControlMiles by Olimsys
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
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

    if (await isRateLimited(userData.user.id)) {
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
