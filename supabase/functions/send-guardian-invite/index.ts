// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/send-guardian-invite/index.ts
//
// School bus parents (2026-10-22): sends the email for
// create_guardian_invite. Same split as send-driver-invite: the RPC checks
// who may authorize a parent and mints the token; this function only
// delivers the email (Resend key stays server-side). It re-resolves the
// token itself, so it can only ever send the email the database already
// committed to for that exact token, to that exact address.
//
// Parents use only the ControlMiles Fleet app (the website is for fleet
// owners, admins and operators): the link opens the app at
// https://controlmiles.com/invite/parent/<token>; on a computer the same
// address shows a page that sends them to their phone.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
const INVITE_SENDER_EMAIL = 'account@controlmiles.com';
const INVITE_LINK_BASE = 'https://controlmiles.com/invite/parent';

// Every error carries its code from ERROR_CODES.md and a message the
// web's AppError.from() recognizes.
const SESSION_EXPIRED = { error: 'Your session expired. Please sign in again.', code: 402 };
const RATE_LIMITED = { error: 'Too many attempts. Try again in a few minutes.', code: 420 };
const INVITE_INVALID = { error: 'This invitation is no longer valid. Create a new one.', code: 450 };
const NOT_ALLOWED = { error: 'Only an admin or the owner can send this invitation.', code: 450 };
const UNEXPECTED = { error: 'Unexpected server error', code: 701 };

const RATE_LIMIT_MAX = 10;
const RATE_LIMIT_WINDOW_SECONDS = 60;

function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function isRateLimited(adminClient: ReturnType<typeof createClient>, clientId: string): Promise<boolean> {
  const { data, error } = await adminClient.rpc('check_rate_limit', {
    p_fn_name: 'send-guardian-invite',
    p_client_key: clientId,
    p_max_requests: RATE_LIMIT_MAX,
    p_window_seconds: RATE_LIMIT_WINDOW_SECONDS,
  });
  if (error) {
    console.warn('[send-guardian-invite] rate limit check failed (failing open):', error);
    return false;
  }
  return !data;
}

function buildEmailHtml(orgName: string, inviteUrl: string, parentId: string, students: string[]): string {
  const safeOrgName = orgName.replace(/[<>&]/g, '');
  const safeStudents = students.map((s) => s.replace(/[<>&]/g, '')).join(', ') || 'your child';
  const safeParentId = parentId.replace(/[^A-Za-z0-9-]/g, '');
  const idBlock = `<p style="margin:16px 0 0 0; padding:12px 14px; background-color:#faf6ee; border:1px solid #e3d9c4; border-radius:10px; font-size:14px; line-height:1.5; color:#211c14;">
                Your parent ID is <strong style="font-family:Menlo,Consolas,monospace; letter-spacing:0.04em;">${safeParentId}</strong>. In the app you sign in with this ID and the password you choose when you accept.
              </p>`;
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
                PARENT ACCESS
              </p>
              <h1 style="margin:10px 0 0 0; font-size:26px; line-height:1.25; font-weight:700; color:#211c14;">
                Follow your child's school bus
              </h1>
              <p style="margin:16px 0 0 0; font-size:15px; line-height:1.6; color:#6b6250;">
                <strong style="color:#211c14;">${safeOrgName}</strong> gave you access to ControlMiles Fleet for ${safeStudents}: when the bus will reach their stop, when they have been dropped off, and a way to tell the school when they won't ride.
              </p>
              ${idBlock}
            </td>
          </tr>
          <tr>
            <td style="padding:28px 40px 0 40px;" align="center">
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="border-radius:999px; background-color:#2c6c99;">
                    <a href="${inviteUrl}" style="display:inline-block; padding:13px 32px; font-size:15px; font-weight:600; color:#ffffff; text-decoration:none;">
                      Open in ControlMiles Fleet
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:24px 40px 32px 40px;">
              <p style="margin:0; font-size:12px; line-height:1.6; color:#9a9080; text-align:center;">
                Open this link on your phone with the ControlMiles Fleet app installed. It expires in 7 days. If you weren't expecting this email, you can safely ignore it.
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
      console.error('[send-guardian-invite] RESEND_API_KEY not configured');
      return respond(UNEXPECTED, 503);
    }

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return respond(SESSION_EXPIRED, 401);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData?.user) {
      return respond(SESSION_EXPIRED, 401);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey);
    if (await isRateLimited(adminClient, userData.user.id)) {
      return respond(RATE_LIMITED, 429);
    }

    let token: string | undefined;
    try {
      const body = await req.json();
      token = typeof body?.token === 'string' ? body.token.trim() : undefined;
    } catch {
      return respond(UNEXPECTED, 400);
    }
    if (!token) {
      return respond(UNEXPECTED, 400);
    }

    const { data: invite, error: inviteError } = await adminClient
      .from('guardian_invites')
      .select('organization_id, guardian_id, email, status, expires_at')
      .eq('token_hash', await sha256Hex(token))
      .maybeSingle();
    if (inviteError || !invite || invite.status !== 'pending' || new Date(invite.expires_at) <= new Date()) {
      return respond(INVITE_INVALID, 400);
    }

    // Same rule as create_guardian_invite: only the fleet's owner or an admin.
    const { data: membership } = await adminClient
      .from('organization_members')
      .select('member_role')
      .eq('organization_id', invite.organization_id)
      .eq('user_id', userData.user.id)
      .eq('is_active', true)
      .maybeSingle();
    if (!membership || !['owner', 'admin'].includes(membership.member_role)) {
      return respond(NOT_ALLOWED, 403);
    }

    const [{ data: org }, { data: guardian }, { data: links }] = await Promise.all([
      adminClient.from('organizations').select('name').eq('id', invite.organization_id).maybeSingle(),
      adminClient.from('school_guardians').select('display_id, is_active').eq('id', invite.guardian_id).maybeSingle(),
      adminClient
        .from('student_guardians')
        .select('students(first_name)')
        .eq('guardian_id', invite.guardian_id)
        .eq('is_active', true),
    ]);
    if (!org?.name || !guardian?.display_id || !guardian.is_active) {
      return respond(INVITE_INVALID, 400);
    }
    // The embedded students(...) comes back as an object or a one-item
    // list depending on the client's type inference; accept both.
    const students = (links ?? []).flatMap((l: { students: unknown }) => {
      const s = l.students as { first_name?: string } | { first_name?: string }[] | null;
      return (Array.isArray(s) ? s : s ? [s] : [])
        .map((x) => x.first_name)
        .filter((n): n is string => !!n);
    });

    const resendResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: `ControlMiles <${INVITE_SENDER_EMAIL}>`,
        to: [invite.email],
        subject: `${org.name}: follow your child's school bus on ControlMiles Fleet`,
        html: buildEmailHtml(org.name, `${INVITE_LINK_BASE}/${token}`, guardian.display_id, students),
      }),
    });
    if (!resendResponse.ok) {
      console.error('[send-guardian-invite] Resend API error:', resendResponse.status, await resendResponse.text());
      return respond(UNEXPECTED, 502);
    }

    return respond({ sent: true });
  } catch (err: any) {
    console.error('[send-guardian-invite] Unexpected error:', err);
    return respond(UNEXPECTED, 500);
  }
});

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}
