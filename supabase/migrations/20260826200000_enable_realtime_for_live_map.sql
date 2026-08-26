-- Real gap caught live before it could ship silently broken: neither
-- table was in the supabase_realtime publication, which means the new
-- Realtime subscription in fleet_live_map_screen.dart (replacing the
-- old 20s polling timer, per the roadmap's explicit "needs a realtime
-- channel, not just polling" note) would have connected successfully
-- (no error) but NEVER received a single event -- Supabase requires
-- each table to be explicitly opted into the publication, it isn't
-- automatic just because RLS allows a client to read it.
--
-- Verified live: pg_publication_tables confirmed empty for both tables
-- before this migration, confirmed populated after.
alter publication supabase_realtime add table public.vehicles;
alter publication supabase_realtime add table public.vehicle_geofence_alerts;
