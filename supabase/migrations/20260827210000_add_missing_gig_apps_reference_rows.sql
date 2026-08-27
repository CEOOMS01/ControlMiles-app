-- Real bug found live (2026-08-27, "ninguna de las apps nuevas responden
-- al switch en modo manual"): session_sections.gig_app has a FOREIGN KEY
-- constraint (session_sections_gig_app_fkey) referencing gig_apps(id) --
-- a reference/lookup table entirely separate from gig_app_packages (which
-- only maps a package name to a gig_app_id for foreground-app detection).
-- When Shipt/Veho/Jitsu/Spark Driver were added earlier this session, they
-- were registered in GigAppCatalog (Dart, for UI) and gig_app_packages (DB,
-- for detection) but never in THIS table -- every switch attempt to any of
-- the 4 failed with a 23503 foreign key violation ("Key is not present in
-- table gig_apps"), both via manual carousel tap and the automatic
-- mid-trip switch RPC, confirmed live via logcat before this fix.
insert into public.gig_apps (id, name, is_active, sort_order) values
  ('shipt', 'Shipt', true, 10),
  ('veho', 'Veho', true, 11),
  ('jitsu', 'Jitsu', true, 12),
  ('walmart_spark', 'Spark Driver', true, 13)
on conflict (id) do nothing;
