-- Admin Activity page (2026-09-29, "Fleet tarda en cargar"): it lists a
-- fleet's latest non-GPS events, but audit_events had no index by
-- organization, so every load scanned the whole table (96% GPS_TICK rows)
-- and ran the RLS check on each. Partial index = exactly that query.
-- Measured: ~1.4 s -> ~0.38 s warm.
create index if not exists idx_audit_org_activity
  on public.audit_events (organization_id, created_at desc)
  where event_type <> 'GPS_TICK';
