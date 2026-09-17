-- IFTA fuel tax rate sync, piece 1 (explicit user request, 2026-09-17):
-- the real blocker on a fileable IFTA return has always been the
-- per-jurisdiction fuel tax RATE -- separate from fuel PRICE (EIA has a
-- public API for that, but it's not the same number) and separate from
-- fuel GALLONS PURCHASED (private receipt data this app doesn't capture
-- yet, a different future piece). Audited CGC Core first: no existing
-- module fits (its "TCO" is Traceability & Cognitive Oversight, an
-- AI-governance audit chain -- unrelated to vehicle costs, a naming
-- collision with an earlier assumption in ifta_service.dart's old
-- comment). This lives directly in ControlMiles instead, same pattern as
-- every other scheduled/background piece of this project.
--
-- Source: iftach.org (IFTA, Inc., the real consortium that publishes
-- these), a public CSV per quarter, no login, no key -- verified live via
-- a plain curl before writing this migration.
create table public.ifta_fuel_tax_rates (
  id uuid primary key default gen_random_uuid(),
  quarter text not null,              -- e.g. '2026-Q3', normalized (not the raw '3Q2026' source filename shape)
  jurisdiction_code text not null,    -- matches ifta_us_state_boundaries.state_code
  fuel_type text not null,            -- e.g. 'gasoline', 'special_diesel', 'propane', ...
  rate_usd numeric,                   -- null when IFTA's own matrix shows "$-" (fuel type not taxed/applicable there)
  source_quarter_label text not null, -- the raw source label, e.g. '3Q2026' -- traceability back to iftach.org's own filename
  fetched_at timestamptz not null default now(),
  unique (quarter, jurisdiction_code, fuel_type)
);

alter table public.ifta_fuel_tax_rates enable row level security;

-- Public reference data, not org-scoped -- every authenticated user can
-- read it (same reasoning as ifta_us_state_boundaries, which has no RLS
-- restriction beyond requiring a real session). Only the sync edge
-- function (service role, bypasses RLS by definition) ever writes here --
-- no INSERT/UPDATE/DELETE policy exists for anon/authenticated on purpose.
create policy ifta_fuel_tax_rates_select
on public.ifta_fuel_tax_rates
for select
using (auth.role() = 'authenticated');

create index ifta_fuel_tax_rates_quarter_idx on public.ifta_fuel_tax_rates (quarter);

-- pg_net for the cron job's outbound HTTP call to the edge function;
-- pg_cron for the schedule itself. Both ship with Supabase, just not
-- enabled by default on a fresh project -- first scheduled job in this
-- codebase (grepped for any existing pg_cron usage first, found none).
create extension if not exists pg_net;
create extension if not exists pg_cron;

-- Real IFTA quarter boundaries (Jan/Apr/Jul/Oct 1st), 06:00 UTC -- well
-- after IFTA, Inc. actually publishes the new quarter's matrix (their own
-- stated practice is publishing before the quarter starts, not exactly
-- at midnight on day 1), with enough margin that a same-day check isn't
-- racing their own publish. The shared secret this reads by NAME (never
-- the value) is created separately via a one-off vault.create_secret call
-- outside this migration file -- a real secret value has no business
-- living in a file that ends up in git history.
-- The function URL itself isn't sensitive (same project ref already
-- appears throughout this codebase's own client config) -- only the
-- shared secret needs Vault; hardcoding the URL literal here avoids a
-- GUC-configuration step that would otherwise be one more manual thing
-- to set up before this job can ever fire.
select cron.schedule(
  'ifta-quarterly-rate-sync',
  '0 6 1 1,4,7,10 *',
  $$
  select net.http_post(
    url := 'https://zuujwmcftycmdaxesdya.supabase.co/functions/v1/sync-ifta-tax-rates',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-Sync-Secret', (select decrypted_secret from vault.decrypted_secrets where name = 'ifta_sync_shared_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);
