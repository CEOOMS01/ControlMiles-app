// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/send-class-reminders/index.ts
//
// Driving school class reminders (2026-10-19, students module phase 1):
// an email to the student and to their parent/guardian before each class,
// within the school's window (ds_settings.reminder_hours, 24 by default).
// ds_due_class_reminders lists what's due (plan feature class_reminders,
// active students, not sent yet); ds_reminders_sent makes it once per
// recipient. Sent through Resend like the other ControlMiles emails.
//
// Freed times (phase 2, 2026-10-20): when a student cancels, the other
// students of the same program (and their guardian when the program says
// so) get one email that the time is open to book from their portal link.
// ds_due_slot_notices skips times already taken again or in the past;
// ds_slot_notices.sent_at makes it once per freed time.
//
// Called by pg_cron hourly (job 'class-reminders-hourly'), never by a user:
// verify_jwt off, the X-Sync-Secret header is the gate (IFTA_SYNC_SECRET,
// same as send-fuel-alerts).

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SYNC_SECRET = Deno.env.get('IFTA_SYNC_SECRET') ?? '';
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
const SENDER = 'alert@controlmiles.com';

type Due = {
  shift_block_id: string;
  organization_id: string;
  school: string;
  timezone: string;
  block_date: string;
  start_time: string;
  student_first_name: string;
  recipient: string;
  instructor: string | null;
};

type Notice = {
  notice_id: string;
  school: string;
  block_date: string;
  start_time: string;
  instructor: string | null;
  recipient: string;
  first_name: string;
};

function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}

const esc = (s: string) => s.replace(/[<>&"]/g, (c) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;' })[c]!);

function when(d: { block_date: string; start_time: string }): string {
  const [h, m] = d.start_time.split(':').map(Number);
  const time = `${((h + 11) % 12) + 1}:${String(m).padStart(2, '0')} ${h >= 12 ? 'PM' : 'AM'}`;
  const day = new Date(`${d.block_date}T12:00:00Z`).toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    timeZone: 'UTC',
  });
  return `${day} at ${time}`;
}

function buildHtml(d: Due): string {
  return `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>ControlMiles</title></head>
<body style="margin:0; padding:0; background-color:#faf6ee; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#faf6ee; padding:32px 16px;"><tr><td align="center">
<table role="presentation" width="520" cellpadding="0" cellspacing="0" style="max-width:520px; width:100%; background-color:#ffffff; border:1px solid #e3d9c4; border-radius:16px;">
<tr><td style="padding:28px 36px 0 36px; font-size:15px; font-weight:700; color:#2c6c99;">${esc(d.school)}</td></tr>
<tr><td style="padding:12px 36px 32px 36px;">
<h1 style="margin:0; font-size:20px; color:#211c14;">Driving lesson reminder</h1>
<p style="margin:10px 0 0 0; font-size:15px; line-height:1.5; color:#211c14;"><strong>${esc(d.student_first_name)}</strong> has a driving lesson on <strong>${esc(when(d))}</strong>${d.instructor ? ` with ${esc(d.instructor)}` : ''}.</p>
<p style="margin:10px 0 0 0; font-size:13px; line-height:1.5; color:#5c5446;">Bring the learner's permit. If you need to reschedule, please contact the school.</p>
</td></tr>
</table>
<p style="font-size:11px; color:#8a8170; margin-top:12px;">Sent by ControlMiles for ${esc(d.school)}.</p>
</td></tr></table></body></html>`;
}

function buildNoticeHtml(n: Notice): string {
  return `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>ControlMiles</title></head>
<body style="margin:0; padding:0; background-color:#faf6ee; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#faf6ee; padding:32px 16px;"><tr><td align="center">
<table role="presentation" width="520" cellpadding="0" cellspacing="0" style="max-width:520px; width:100%; background-color:#ffffff; border:1px solid #e3d9c4; border-radius:16px;">
<tr><td style="padding:28px 36px 0 36px; font-size:15px; font-weight:700; color:#2c6c99;">${esc(n.school)}</td></tr>
<tr><td style="padding:12px 36px 32px 36px;">
<h1 style="margin:0; font-size:20px; color:#211c14;">A lesson time just opened</h1>
<p style="margin:10px 0 0 0; font-size:15px; line-height:1.5; color:#211c14;">A driving lesson on <strong>${esc(when(n))}</strong>${n.instructor ? ` with ${esc(n.instructor)}` : ''} is free again.</p>
<p style="margin:10px 0 0 0; font-size:13px; line-height:1.5; color:#5c5446;">To book it for ${esc(n.first_name)}, open the lesson link the school sent you. First come, first served.</p>
</td></tr>
</table>
<p style="font-size:11px; color:#8a8170; margin-top:12px;">Sent by ControlMiles for ${esc(n.school)}.</p>
</td></tr></table></body></html>`;
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return respond({ error: 'Method not allowed' }, 405);
  if (!SYNC_SECRET || req.headers.get('X-Sync-Secret') !== SYNC_SECRET) return respond({ error: 'Unauthorized' }, 401);
  if (!RESEND_API_KEY) return respond({ error: 'RESEND_API_KEY not configured' }, 500);

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data, error } = await admin.rpc('ds_due_class_reminders');
  if (error) return respond({ error: error.message }, 500);
  const due = (data ?? []) as Due[];

  let sent = 0;
  const failed: string[] = [];
  for (const d of due) {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: `${d.school} via ControlMiles <${SENDER}>`,
        to: [d.recipient],
        subject: `Driving lesson ${when(d)}`,
        html: buildHtml(d),
      }),
    });
    if (!res.ok) {
      failed.push(d.shift_block_id);
      continue;
    }
    // Stamped only after Resend accepted it, so a failure retries next hour.
    await admin.from('ds_reminders_sent').insert({ shift_block_id: d.shift_block_id, recipient: d.recipient });
    sent++;
  }

  // Freed times: one email per recipient, then the notice is closed (a
  // failed address isn't retried, so nobody gets the same notice twice).
  const { data: noticeRows, error: noticeError } = await admin.rpc('ds_due_slot_notices');
  if (noticeError) return respond({ due: due.length, sent, failed: failed.length, notices_error: noticeError.message });
  const notices = (noticeRows ?? []) as Notice[];
  const seen = new Set<string>();
  const done = new Set<string>();
  let noticesSent = 0;
  for (const n of notices) {
    const key = `${n.notice_id}|${n.recipient}`;
    if (seen.has(key)) continue; // a student who is also a guardian
    seen.add(key);
    done.add(n.notice_id);
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: `${n.school} via ControlMiles <${SENDER}>`,
        to: [n.recipient],
        subject: `Lesson time open: ${when(n)}`,
        html: buildNoticeHtml(n),
      }),
    });
    if (res.ok) noticesSent++;
  }
  if (done.size > 0) {
    await admin.from('ds_slot_notices').update({ sent_at: new Date().toISOString() }).in('id', [...done]);
  }

  return respond({ due: due.length, sent, failed: failed.length, notices: done.size, notice_emails: noticesSent });
});
