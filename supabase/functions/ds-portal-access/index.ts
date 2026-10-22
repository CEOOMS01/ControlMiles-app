// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/ds-portal-access/index.ts
//
// Driving school client portal (2026-10-22): the sign-in and welcome
// emails. Clients (adult students and parents of minors) use the website
// only and sign in with a link sent by email, no password
// (migration 20261022200000_ds_client_portal.sql). Two calls:
//
//   * { email } -- no user JWT (the person isn't signed in yet). One link
//     per school where that email has an active profile, valid 30 minutes.
//     The answer is the same whether or not the email has any (owner's
//     rule: no public screen reveals which emails exist), and it is
//     rate-limited on the caller's IP and on the email itself.
//   * { token } -- with a staff member's JWT, after ds_client_welcome_link:
//     the welcome email. The token is re-resolved here, so only the email
//     the database issued for that token, to that address, can go out, and
//     only staff (owner, admin, operator) of that school can send it.
//
// verify_jwt is off: the first call has no JWT; the second checks it here.

import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';

declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void };

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
const SENDER_EMAIL = 'account@controlmiles.com';
const LINK_BASE = 'https://controlmiles.com/lessons/access';

// Every error carries its code from ERROR_CODES.md.
const SESSION_EXPIRED = { error: 'Your session expired. Please sign in again.', code: 402 };
const RATE_LIMITED = { error: 'Too many attempts. Try again in a few minutes.', code: 420 };
const INVITE_INVALID = { error: 'This invitation is no longer valid. Create a new one.', code: 450 };
const NOT_ALLOWED = { error: 'Only the school staff can send this invitation.', code: 450 };
const UNEXPECTED = { error: 'Unexpected server error', code: 701 };
const SENT = { sent: true };

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function isRateLimited(
  adminClient: SupabaseClient,
  fnName: string,
  clientKey: string,
  max: number,
  windowSeconds: number,
): Promise<boolean> {
  const { data, error } = await adminClient.rpc('check_rate_limit', {
    p_fn_name: fnName,
    p_client_key: clientKey,
    p_max_requests: max,
    p_window_seconds: windowSeconds,
  });
  if (error) {
    console.warn(`[ds-portal-access] rate limit check failed for ${fnName} (failing open):`, error);
    return false;
  }
  return !data;
}

const clean = (s: string) => s.replace(/[<>&"]/g, '');

function buildEmailHtml(opts: { school: string; firstName: string; url: string; welcome: boolean; minutes: string }): string {
  const school = clean(opts.school);
  const name = clean(opts.firstName);
  const title = opts.welcome ? `Welcome to ${school}` : `Sign in to ${school}`;
  const body = opts.welcome
    ? `${school} opened your online portal: upcoming lessons, hours completed, each lesson's report card and the certificate. No app to install, no password: this button signs you in.`
    : `Here is your sign-in link for ${school}. No password needed: this button signs you in.`;
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
                DRIVING LESSONS
              </p>
              <h1 style="margin:10px 0 0 0; font-size:26px; line-height:1.25; font-weight:700; color:#211c14;">
                ${title}
              </h1>
              <p style="margin:16px 0 0 0; font-size:15px; line-height:1.6; color:#6b6250;">
                Hi ${name}, ${body}
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding:28px 40px 0 40px;" align="center">
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="border-radius:999px; background-color:#2c6c99;">
                    <a href="${opts.url}" style="display:inline-block; padding:13px 32px; font-size:15px; font-weight:600; color:#ffffff; text-decoration:none;">
                      Open my portal
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:24px 40px 32px 40px;">
              <p style="margin:0; font-size:12px; line-height:1.6; color:#9a9080; text-align:center;">
                The link works once and expires in ${opts.minutes}. If you didn't ask for it, you can safely ignore this email.
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

async function sendEmail(to: string, subject: string, html: string): Promise<boolean> {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from: `ControlMiles <${SENDER_EMAIL}>`, to: [to], subject, html }),
  });
  if (!res.ok) {
    console.error('[ds-portal-access] Resend API error:', res.status, await res.text());
  }
  return res.ok;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (!RESEND_API_KEY) {
      console.error('[ds-portal-access] RESEND_API_KEY not configured');
      return respond(UNEXPECTED, 503);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    let email: string | undefined;
    let token: string | undefined;
    try {
      const body = await req.json();
      email = typeof body?.email === 'string' ? body.email.trim().toLowerCase() : undefined;
      token = typeof body?.token === 'string' ? body.token.trim() : undefined;
    } catch {
      return respond(UNEXPECTED, 400);
    }

    // ---- Welcome email (staff) ----
    if (token) {
      const authHeader = req.headers.get('Authorization');
      const userClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader ?? '' } },
      });
      const { data: userData, error: userError } = authHeader
        ? await userClient.auth.getUser()
        : { data: null, error: true };
      if (userError || !userData?.user) {
        return respond(SESSION_EXPIRED, 401);
      }
      if (await isRateLimited(adminClient, 'ds-portal-access-welcome', userData.user.id, 30, 60)) {
        return respond(RATE_LIMITED, 429);
      }

      const { data: info, error: infoError } = await adminClient.rpc('ds_client_link_info', { p_token: token });
      const row = Array.isArray(info) ? info[0] : null;
      if (infoError || !row) {
        return respond(INVITE_INVALID, 400);
      }
      const { data: membership } = await adminClient
        .from('organization_members')
        .select('member_role')
        .eq('organization_id', row.organization_id)
        .eq('user_id', userData.user.id)
        .eq('is_active', true)
        .maybeSingle();
      if (!membership || !['owner', 'admin', 'operator'].includes(membership.member_role)) {
        return respond(NOT_ALLOWED, 403);
      }

      const ok = await sendEmail(
        row.email,
        `${row.school}: your driving lessons portal`,
        buildEmailHtml({ school: row.school, firstName: row.first_name, url: `${LINK_BASE}/${token}`, welcome: true, minutes: '7 days' }),
      );
      return ok ? respond(SENT) : respond(UNEXPECTED, 502);
    }

    // ---- Sign-in link (anyone) ----
    const clientIp = req.headers.get('x-forwarded-for')?.split(',')[0].trim()
      ?? req.headers.get('cf-connecting-ip')
      ?? 'unknown';
    if (await isRateLimited(adminClient, 'ds-portal-access-ip', clientIp, 10, 900)) {
      return respond(RATE_LIMITED, 429);
    }
    // A malformed email gets the same answer as an unknown one.
    if (!email || email.length > 120 || !EMAIL_RE.test(email)) {
      return respond(SENT);
    }
    // Per email: also the same answer when limited, so the limit itself
    // reveals nothing; it only stops the mailbox from being flooded.
    if (await isRateLimited(adminClient, 'ds-portal-access-email', email, 3, 900)) {
      return respond(SENT);
    }

    // Looked up and sent after the answer: the reply takes the same time
    // whether or not the email has a profile.
    const to = email;
    EdgeRuntime.waitUntil((async () => {
      const { data: links, error: linksError } = await adminClient.rpc('ds_client_request_links', { p_email: to });
      if (linksError) {
        console.error('[ds-portal-access] ds_client_request_links failed:', linksError);
        return;
      }
      for (const l of (links ?? []) as { school: string; first_name: string; token: string }[]) {
        await sendEmail(
          to,
          `${l.school}: your sign-in link`,
          buildEmailHtml({ school: l.school, firstName: l.first_name, url: `${LINK_BASE}/${l.token}`, welcome: false, minutes: '30 minutes' }),
        );
      }
    })());
    return respond(SENT);
  } catch (err: unknown) {
    console.error('[ds-portal-access] Unexpected error:', err);
    return respond(UNEXPECTED, 500);
  }
});
