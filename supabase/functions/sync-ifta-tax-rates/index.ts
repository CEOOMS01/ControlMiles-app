// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/sync-ifta-tax-rates/index.ts
//
// Fetches IFTA, Inc.'s real quarterly fuel tax rate matrix (iftach.org --
// the actual consortium that governs the agreement, not a third-party
// aggregator) and upserts it into ifta_fuel_tax_rates. This is the piece
// that was missing to eventually make the state-mileage report (see
// ifta_service.dart / compute_state_mileage) into a real tax-due
// calculation -- rate x miles, netted against fuel already taxed at the
// pump. Fuel GALLONS PURCHASED per jurisdiction is a separate, later
// piece (private receipt data no public source can provide); this
// function only handles the rate side, which genuinely is public.
//
// No user JWT on this call -- same shape as stripe-webhook: the caller is
// pg_cron (see migration 20260917200000_ifta_fuel_tax_rates.sql) or a
// manual admin trigger, never an end user's session. Authenticity comes
// from a shared secret header instead (X-Sync-Secret / IFTA_SYNC_SECRET),
// not JWT verification -- there's no per-user identity to check here, so
// verify_jwt stays false and this check is the real gate.
//
// PARSING NOTES (verified against the real Q3 2026 file via a raw curl
// before writing this, not assumed):
// - iftach.org's CSV repeats its own header block partway through the
//   file (right before Wyoming, in the Q3 2026 file) -- there is no fixed
//   "header is the first N lines" assumption anywhere below. A row is
//   only ever treated as DATA when its currency column is literally
//   'U.S.' or 'Can'; every other row (titles, repeated headers, blank
//   separator rows) is silently skipped by that same rule, uniformly.
// - Only 'U.S.' rows are stored -- ifta_us_state_boundaries (what
//   compute_state_mileage attributes GPS miles to) is US-only today, so
//   Canadian-dollar rows have no matching jurisdiction to join against
//   yet and would just be unused noise.
// - A jurisdiction name can carry a trailing IFTA footnote reference
//   ("ALABAMA #35", "WASHINGTON #10") -- stripped before matching against
//   ifta_us_state_boundaries.name. Non-IFTA-member jurisdictions (Alaska,
//   Hawaii, D.C. -- confirmed absent from the real file, not a parsing
//   bug) simply produce no match and are skipped, which is correct: IFTA
//   itself doesn't cover them.
// - "$-" means the fuel type isn't taxed/applicable in that jurisdiction
//   (not a parsing failure) -- stored as a null rate_usd, not zero or a
//   missing row, so a caller can tell "no tax on this fuel here" apart
//   from "we don't have data for this fuel here".
// - Fuel-type column order is hardcoded (FUEL_TYPES below) rather than
//   parsed from the file's own 2-row wrapped header ("Special" on one
//   line, "Diesel" continuing it on the next) -- that header repeats
//   mid-file too, so parsing it generically bought nothing over pinning
//   the known, stable IFTA-published column set directly.
// - A few states (Indiana, Kentucky, Virginia in the real Q3 2026 file)
//   carry a SEPARATE "<STATE> SurChg" row for a real per-gallon surcharge
//   on top of their base rate -- a genuine second IFTA line item, not a
//   duplicate or a parsing artifact. Deliberately NOT merged into the
//   base state's rate here (that would silently misstate the number);
//   it fails the name match like any other unrecognized jurisdiction and
//   shows up in the response's unmatched_jurisdictions, visible rather
//   than silently dropped. Folding surcharges into the real tax-due
//   calculation is future work for whoever builds that calculation, not
//   this sync step -- confirmed live against the real file, not assumed.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const IFTA_SYNC_SECRET = Deno.env.get('IFTA_SYNC_SECRET') ?? '';

// IFTA, Inc.'s own stable column order for the quarterly matrix --
// confirmed against the real Q3 2026 file. "Special Diesel" is IFTA's
// own formal name for diesel (the source file's 2-row wrapped header:
// "Special" then "Diesel" on the continuation line).
const FUEL_TYPES = [
  'gasoline',
  'special_diesel',
  'gasohol',
  'propane',
  'lng',
  'cng',
  'ethanol',
  'methanol',
  'e85',
  'm85',
  'a55',
  'biodiesel',
  'electricity',
  'hydrogen',
  'hythane',
] as const;

function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/** '2026-07-15' -> '3Q2026' -- IFTA's own quarter-label shape, matching
 * their file naming (`/taxmatrix/charts/{label}.csv`). */
function currentQuarterLabel(now: Date): string {
  const quarter = Math.floor(now.getUTCMonth() / 3) + 1;
  return `${quarter}Q${now.getUTCFullYear()}`;
}

function quarterLabelToNormalized(label: string): string {
  const match = /^(\d)Q(\d{4})$/.exec(label);
  if (!match) return label;
  return `${match[2]}-Q${match[1]}`;
}

/** '$ 0.3519 ' -> 0.3519, '$-' -> null. */
function parseRate(raw: string): number | null {
  const trimmed = raw.trim().replace(/^\$\s*/, '').trim();
  if (trimmed === '-' || trimmed === '') return null;
  const value = Number(trimmed);
  return Number.isFinite(value) ? value : null;
}

function stripFootnote(name: string): string {
  return name.replace(/\s*#\d+\s*$/, '').trim();
}

type ParsedRow = { jurisdictionName: string; rates: (number | null)[] };

/** Every row whose currency column is exactly 'U.S.' is data; everything
 * else (the quarter title, both header lines, the repeated header block
 * mid-file, blank separator rows) is skipped by the same rule -- see this
 * file's own header comment for why that's deliberate, not incomplete. */
function parseUsRows(csvText: string): ParsedRow[] {
  const rows: ParsedRow[] = [];
  const lines = csvText.replace(/^﻿/, '').split(/\r?\n/);

  for (const line of lines) {
    if (!line.trim()) continue;
    const cols = line.split(',');
    const currency = (cols[1] ?? '').trim();
    if (currency !== 'U.S.') continue;

    const jurisdictionName = stripFootnote((cols[0] ?? '').trim());
    if (!jurisdictionName) continue;

    const rates = FUEL_TYPES.map((_, i) => parseRate(cols[2 + i] ?? ''));
    rows.push({ jurisdictionName, rates });
  }

  return rows;
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return respond({ error: 'Method not allowed' }, 405);
  }

  if (!IFTA_SYNC_SECRET || req.headers.get('X-Sync-Secret') !== IFTA_SYNC_SECRET) {
    return respond({ error: 'Unauthorized' }, 401);
  }

  let quarterLabel = currentQuarterLabel(new Date());
  try {
    const body = await req.json();
    if (typeof body?.quarter === 'string' && /^\dQ\d{4}$/.test(body.quarter)) {
      quarterLabel = body.quarter;
    }
  } catch {
    // No/invalid body -- use the real current quarter, the normal
    // (cron-triggered) path.
  }

  const csvUrl = `https://www.iftach.org/taxmatrix/charts/${quarterLabel}.csv`;

  try {
    const csvRes = await fetch(csvUrl, {
      // IFTA, Inc.'s own site (unrelated to the Overpass 406 lesson from
      // the speed-limit service, but the same real-world habit) -- a
      // generic/missing User-Agent is a common reason a public data host
      // silently blocks a script.
      headers: { 'User-Agent': 'ControlMiles/1.0 (+https://controlmiles.com)' },
    });

    if (!csvRes.ok) {
      // A 404 here most often means the new quarter's file genuinely
      // isn't published yet (IFTA, Inc. sometimes finalizes a few days
      // into the quarter) -- not a bug, so this is reported distinctly
      // from an unexpected error rather than as a 500.
      return respond(
        { error: `IFTA source returned ${csvRes.status} for ${quarterLabel}`, quarter: quarterLabel, not_yet_published: csvRes.status === 404 },
        502,
      );
    }

    const csvText = await csvRes.text();
    const parsedRows = parseUsRows(csvText);

    if (parsedRows.length === 0) {
      return respond({ error: 'No U.S. rows parsed -- source format may have changed', quarter: quarterLabel }, 502);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: boundaries, error: boundariesError } = await adminClient
      .from('ifta_us_state_boundaries')
      .select('state_code, name');

    if (boundariesError || !boundaries) {
      return respond({ error: 'Could not load ifta_us_state_boundaries for jurisdiction matching' }, 500);
    }

    const nameToCode = new Map(boundaries.map((b: { state_code: string; name: string }) => [b.name.toLowerCase(), b.state_code]));
    const normalizedQuarter = quarterLabelToNormalized(quarterLabel);
    const fetchedAt = new Date().toISOString();

    const upsertRows: {
      quarter: string;
      jurisdiction_code: string;
      fuel_type: string;
      rate_usd: number | null;
      source_quarter_label: string;
      fetched_at: string;
    }[] = [];
    const unmatchedJurisdictions: string[] = [];

    for (const row of parsedRows) {
      const code = nameToCode.get(row.jurisdictionName.toLowerCase());
      if (!code) {
        // Expected for non-IFTA-member jurisdictions (Alaska, Hawaii) and
        // for any Canadian province name that happens to slip through --
        // recorded for visibility in the response, not treated as an
        // error (see this file's own header comment).
        unmatchedJurisdictions.push(row.jurisdictionName);
        continue;
      }
      FUEL_TYPES.forEach((fuelType, i) => {
        upsertRows.push({
          quarter: normalizedQuarter,
          jurisdiction_code: code,
          fuel_type: fuelType,
          rate_usd: row.rates[i],
          source_quarter_label: quarterLabel,
          fetched_at: fetchedAt,
        });
      });
    }

    const { error: upsertError } = await adminClient
      .from('ifta_fuel_tax_rates')
      .upsert(upsertRows, { onConflict: 'quarter,jurisdiction_code,fuel_type' });

    if (upsertError) {
      return respond({ error: upsertError.message, quarter: quarterLabel }, 500);
    }

    return respond({
      quarter: normalizedQuarter,
      source_quarter_label: quarterLabel,
      jurisdictions_matched: parsedRows.length - unmatchedJurisdictions.length,
      unmatched_jurisdictions: unmatchedJurisdictions,
      rows_upserted: upsertRows.length,
    });
  } catch (err: any) {
    return respond({ error: err?.message ?? 'Internal error', quarter: quarterLabel }, 500);
  }
});
