-- Curri (curri.com / curri.com/drive) -- explicit user request 2026-09-16.
--
-- READ THIS BEFORE "CORRECTING" IT AWAY: a 'curri' row existed briefly on
-- 2026-08-27 and was deleted the same day by
-- 20260827224500_fix_courial_not_curri.sql. That deletion was RIGHT at the
-- time -- back then the user had asked for Courial (courial.com) and the
-- request was misread as Curri. This row is NOT that mistake resurfacing.
-- Curri is a real, separate company (last-mile delivery for construction
-- and building materials) and the user asked for it directly, by URL, this
-- time. Both now coexist on purpose: 'courial' (sort 25) and 'curri'
-- (sort 26).
--
-- Package name verified against the USER'S OWN DEVICE, not a web search:
--   adb shell pm list packages | grep -i curri  ->  com.Curri.Driver
--   (v3.2.1, installed 2026-09-07)
-- Note the capitalisation -- com.Curri.Driver, not com.curri.driver.
-- Package matching in GigAppDetectionService is an exact map lookup, so a
-- lower-cased copy of this string would silently never match. There is also
-- a second, DIFFERENT Curri app on Play (com.Curri.RouteDriver, "Curri
-- Route Driver") -- deliberately NOT added: the user has the Driver app
-- installed, and adding an unverified package would just create a
-- never-matching row.
insert into public.gig_apps (id, name, is_active, sort_order) values
  ('curri', 'Curri', true, 26)
on conflict (id) do nothing;

insert into public.gig_app_packages (gig_app_id, os, package_name) values
  ('curri', 'android', 'com.Curri.Driver')
on conflict do nothing;
