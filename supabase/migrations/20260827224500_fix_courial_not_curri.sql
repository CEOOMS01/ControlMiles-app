-- Correction to 20260827223000_add_batch2_gig_apps_and_packages.sql:
-- the user's original "Courial" request was initially misread as Curri
-- (curri.com), a real but entirely unrelated company, before the user
-- pointed to the actual site (courial.com). Removes the wrong entry, adds
-- the correct one -- a forward correction, not a rewrite of the already-
-- applied migration above (no session_sections row ever referenced
-- 'curri', added and corrected within the same session, so this is safe).
--
-- Courial's real driver app is "Courial Partner" (live.courial.partner),
-- distinct from com.courial.user (their customer-facing app) -- verified
-- via the actual Play Store listing, same driver-vs-customer split every
-- other platform in this catalog has.
delete from public.gig_app_packages where gig_app_id = 'curri';
delete from public.gig_apps where id = 'curri';

insert into public.gig_apps (id, name, is_active, sort_order) values
  ('courial', 'Courial', true, 25)
on conflict (id) do nothing;

insert into public.gig_app_packages (gig_app_id, os, package_name) values
  ('courial', 'android', 'live.courial.partner')
on conflict do nothing;
