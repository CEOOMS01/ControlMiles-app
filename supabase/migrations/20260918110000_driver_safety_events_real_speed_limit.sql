-- Real fix (explicit user request, 2026-09-18): driver_safety_events'
-- "speeding" rows only ever recorded a fixed-threshold judgment call,
-- with no record of what the actual posted limit was. Adding columns to
-- store the real per-road limit (when SpeedLimitService's OpenStreetMap
-- lookup finds one) and its source, so the admin dashboard can show "62
-- mph in a 55 zone" instead of just a bare "speeding" badge. Nullable:
-- harsh_braking/hard_acceleration rows never set these (not road-limit
-- events), and a speeding row whose lookup came back unavailable also
-- leaves them null -- both are honest "we don't know the posted limit
-- here" states, not a missing-data bug.

alter table public.driver_safety_events
  add column if not exists speed_limit_mps double precision,
  add column if not exists speed_limit_source text
    check (speed_limit_source is null or speed_limit_source in ('osm', 'fixed_fallback'));
