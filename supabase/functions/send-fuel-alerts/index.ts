// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/send-fuel-alerts/index.ts
//
// Nightly email digest of NEW fuel anomalies (fuel_anomalies, see
// migration 20260930120000_fuel_anomalies.sql) to each fleet's owners and
// admins -- the "consumption anomaly alert" half of the feature (the web
// Fuel page is the review half). One email per fleet listing what's new
// since the last digest, then notified_at is stamped so nothing is sent
// twice. Sent through Resend, same sender setup as send-driver-invite.
//
// Called by pg_cron only (job 'fuel-anomalies-nightly'), never by a user:
// verify_jwt is off and the X-Sync-Secret header is the gate -- the same
// project-level IFTA_SYNC_SECRET the IFTA rate sync uses (Supabase
// function secrets are shared across the project; the cron reads it from
// Vault by name).

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SYNC_SECRET = Deno.env.get('IFTA_SYNC_SECRET') ?? '';
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
// Sender: alert@ (alerts) -- public addresses set 2026-09-30.
const SENDER = 'alert@controlmiles.com';
const FUEL_PAGE_URL = 'https://controlmiles.com/admin/fuel';

type Anomaly = {
  id: string;
  organization_id: string;
  kind: string;
  severity: 'high' | 'medium' | 'low';
  detail: string;
  vehicle_id: string;
  purchase_id: string;
};

const KIND_LABEL: Record<string, string> = {
  duplicate: 'Possible duplicate receipt',
  over_capacity: 'More fuel than the tank holds',
  location_mismatch: 'Bought where the vehicle wasn’t',
  no_trip: 'No trips around the purchase',
  no_miles: 'Fill-up with no miles driven',
  low_mpg: 'Unusually low MPG',
  price_mismatch: 'Receipt total doesn’t add up',
  price_high: 'Price well above normal',
};

function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

const esc = (s: string) => s.replace(/[<>&"]/g, (c) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;' })[c]!);

function buildHtml(orgName: string, rows: { vehicle: string; date: string; a: Anomaly }[]): string {
  const color = { high: '#b42318', medium: '#b54708', low: '#475467' };
  const items = rows
    .map(
      (r) => `<tr><td style="padding:10px 0; border-top:1px solid #eee4d2; font-size:14px; line-height:1.45; color:#211c14;">
        <strong style="color:${color[r.a.severity]};">${esc(KIND_LABEL[r.a.kind] ?? r.a.kind)}</strong>
        &middot; ${esc(r.vehicle)} &middot; ${esc(r.date)}<br>
        <span style="color:#5c5446;">${esc(r.a.detail)}</span></td></tr>`,
    )
    .join('');
  return `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>ControlMiles</title></head>
<body style="margin:0; padding:0; background-color:#faf6ee; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#faf6ee; padding:32px 16px;"><tr><td align="center">
<table role="presentation" width="520" cellpadding="0" cellspacing="0" style="max-width:520px; width:100%; background-color:#ffffff; border:1px solid #e3d9c4; border-radius:16px;">
<tr><td style="padding:28px 36px 0 36px; font-size:19px; font-weight:700; color:#211c14;">
<img src="https://controlmiles.com/logo_controlmiles.png" width="28" height="28" alt="" style="vertical-align:middle; border-radius:7px; margin-right:8px;">Control<span style="color:#2c6c99;">Miles</span></td></tr>
<tr><td style="padding:20px 36px 0 36px;">
<h1 style="margin:0; font-size:20px; color:#211c14;">${rows.length} new fuel alert${rows.length === 1 ? '' : 's'} for ${esc(orgName)}</h1>
<p style="margin:8px 0 0 0; font-size:14px; line-height:1.5; color:#5c5446;">Receipts your drivers logged that don't match the vehicle's trips or its usual consumption. Review each one: dismiss it if there's an explanation, confirm it if it's a real problem.</p>
</td></tr>
<tr><td style="padding:12px 36px 0 36px;"><table role="presentation" width="100%" cellpadding="0" cellspacing="0">${items}</table></td></tr>
<tr><td style="padding:20px 36px 32px 36px;"><a href="${FUEL_PAGE_URL}" style="display:inline-block; background-color:#2c6c99; color:#ffffff; text-decoration:none; font-weight:600; font-size:14px; padding:11px 20px; border-radius:10px;">Review fuel alerts</a></td></tr>
</table></td></tr></table></body></html>`;
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return respond({ error: 'Method not allowed' }, 405);
  if (!SYNC_SECRET || req.headers.get('X-Sync-Secret') !== SYNC_SECRET) {
    return respond({ error: 'Unauthorized' }, 401);
  }
  if (!RESEND_API_KEY) return respond({ error: 'RESEND_API_KEY not configured' }, 500);

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  // Test mode (pre-launch check, 2026-09-30): {"test_org_id": "..."} sends
  // a sample digest, marked [TEST], to that fleet's owners/admins only --
  // proves Resend delivery end to end without touching real alerts.
  let body: { test_org_id?: string } = {};
  try {
    body = await req.json();
  } catch {
    // cron sends {} -- the normal path
  }
  if (body.test_org_id) {
    const [{ data: org }, { data: members }] = await Promise.all([
      admin.from('organizations').select('name').eq('id', body.test_org_id).maybeSingle(),
      admin
        .from('organization_members')
        .select('profiles(email)')
        .eq('organization_id', body.test_org_id)
        .in('member_role', ['owner', 'admin'])
        .eq('is_active', true),
    ]);
    const to = [
      ...new Set(
        (members ?? [])
          .map((m) => (Array.isArray(m.profiles) ? m.profiles[0] : m.profiles) as { email?: string } | null)
          .map((p) => p?.email)
          .filter((e): e is string => !!e),
      ),
    ];
    if (!org || to.length === 0) return respond({ error: 'No such fleet or no admin email' }, 404);
    const sample = (kind: string, severity: Anomaly['severity'], detail: string) => ({
      vehicle: 'Sample vehicle (CM-T0000)',
      date: new Date().toISOString().slice(0, 10),
      a: { id: '', organization_id: '', kind, severity, detail, vehicle_id: '', purchase_id: '' } as Anomaly,
    });
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: `ControlMiles <${SENDER}>`,
        to,
        subject: `[TEST] 2 new fuel alerts — ${org.name}`,
        html: buildHtml(`${org.name} (test email — sample data)`, [
          sample('no_miles', 'high', '25.0 gal bought, but no miles were driven since the last fill-up.'),
          sample('price_high', 'low', '$5.200/gal, 49% above the fleet’s usual $3.500/gal for gasoline.'),
        ]),
      }),
    });
    if (!res.ok) return respond({ error: 'Resend error', status: res.status, detail: await res.text() }, 502);
    return respond({ test_sent_to: to.length });
  }

  const { data: anomalies, error } = await admin
    .from('fuel_anomalies')
    .select('id, organization_id, kind, severity, detail, vehicle_id, purchase_id')
    .eq('status', 'open')
    .is('notified_at', null)
    .order('created_at', { ascending: true })
    .limit(1000);
  if (error) return respond({ error: error.message }, 500);
  if (!anomalies || anomalies.length === 0) return respond({ orgs: 0, sent: 0 });

  const byOrg = new Map<string, Anomaly[]>();
  for (const a of anomalies as Anomaly[]) {
    byOrg.set(a.organization_id, [...(byOrg.get(a.organization_id) ?? []), a]);
  }

  const vehicleIds = [...new Set(anomalies.map((a) => a.vehicle_id))];
  const purchaseIds = [...new Set(anomalies.map((a) => a.purchase_id))];
  const [{ data: vehicles }, { data: purchases }, { data: orgs }, { data: members }] = await Promise.all([
    admin.from('vehicles').select('id, display_id, nickname, make, model').in('id', vehicleIds),
    admin.from('fuel_purchases').select('id, purchase_date').in('id', purchaseIds),
    admin.from('organizations').select('id, name').in('id', [...byOrg.keys()]),
    admin
      .from('organization_members')
      .select('organization_id, profiles(email)')
      .in('organization_id', [...byOrg.keys()])
      .in('member_role', ['owner', 'admin'])
      .eq('is_active', true),
  ]);

  const vehicleLabel = new Map(
    (vehicles ?? []).map((v) => {
      const name = v.nickname || [v.make, v.model].filter(Boolean).join(' ');
      return [v.id, name ? `${name} (${v.display_id ?? ''})` : v.display_id ?? 'Vehicle'];
    }),
  );
  const purchaseDate = new Map((purchases ?? []).map((p) => [p.id, p.purchase_date as string]));
  const orgName = new Map((orgs ?? []).map((o) => [o.id, o.name as string]));

  let sent = 0;
  const failures: string[] = [];
  for (const [orgId, list] of byOrg) {
    const emails = [
      ...new Set(
        (members ?? [])
          .filter((m) => m.organization_id === orgId)
          .map((m) => {
            const p = Array.isArray(m.profiles) ? m.profiles[0] : m.profiles;
            return (p as { email?: string } | null)?.email;
          })
          .filter((e): e is string => !!e),
      ),
    ];
    if (emails.length === 0) continue;

    const rank = { high: 0, medium: 1, low: 2 };
    const rows = list
      .sort((a, b) => rank[a.severity] - rank[b.severity])
      .map((a) => ({ a, vehicle: vehicleLabel.get(a.vehicle_id) ?? 'Vehicle', date: purchaseDate.get(a.purchase_id) ?? '' }));
    const name = orgName.get(orgId) ?? 'your fleet';

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: `ControlMiles <${SENDER}>`,
        to: emails,
        subject: `${list.length} new fuel alert${list.length === 1 ? '' : 's'} — ${name}`,
        html: buildHtml(name, rows),
      }),
    });
    if (!res.ok) {
      console.error('[send-fuel-alerts] Resend error', res.status, await res.text());
      failures.push(orgId);
      continue;
    }
    await admin
      .from('fuel_anomalies')
      .update({ notified_at: new Date().toISOString() })
      .in('id', list.map((a) => a.id));
    sent += 1;
  }

  return respond({ orgs: byOrg.size, sent, failed: failures.length });
});
