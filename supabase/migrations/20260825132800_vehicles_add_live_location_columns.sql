-- Fleet Phase 5: live map. Nothing in this codebase has ever written a
-- vehicle's current position anywhere -- processGpsTick/_smartSync only
-- ever synced total_miles + an audit log entry (score, no coordinates).
-- Adding "current position" as a property of the vehicle itself (not a new
-- table) so vehicles_select's existing RLS (owner OR org member) covers
-- read access for free, no new SELECT policy needed.
alter table public.vehicles
  add column last_latitude double precision,
  add column last_longitude double precision,
  add column last_speed double precision,
  add column last_location_at timestamptz;
