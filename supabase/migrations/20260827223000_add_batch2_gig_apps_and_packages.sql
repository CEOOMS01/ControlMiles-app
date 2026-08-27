-- Explicit user request (2026-08-27): 12 more gig platforms researched via
-- WebSearch against real Play Store listings -- Grubhub, Gopuff, Curb,
-- Point Pickup, Skipcart, Dispatch, DeliverThat, Wingz, HopSkipDrive, Alto,
-- GoShare, and Curri (the "Courial" app in the user's own request).
--
-- Both registration points needed -- gig_apps (the FK target every real
-- session_sections write depends on, the exact gap found live earlier this
-- session that broke Shipt/Veho/Jitsu/Spark Driver) and gig_app_packages
-- (detection-only, package name -> gig_app_id).
--
-- Wingz and Alto deliberately get NO gig_app_packages row: Wingz's driver
-- app isn't distributed via Google Play at all (confirmed via Wingz's own
-- help docs -- direct download only), and Alto's drivers are W-2 employees
-- with no confirmed public driver-specific APK (only a passenger-app
-- package, which would be the wrong thing to detect against). Both still
-- work for manual trip labeling via the gig_apps row alone -- auto-detect
-- just never resolves to them.
insert into public.gig_apps (id, name, is_active, sort_order) values
  ('grubhub', 'Grubhub', true, 14),
  ('gopuff', 'Gopuff', true, 15),
  ('curb', 'Curb', true, 16),
  ('point_pickup', 'Point Pickup', true, 17),
  ('skipcart', 'Skipcart', true, 18),
  ('dispatch', 'Dispatch', true, 19),
  ('deliverthat', 'DeliverThat', true, 20),
  ('wingz', 'Wingz', true, 21),
  ('hopskipdrive', 'HopSkipDrive', true, 22),
  ('alto', 'Alto', true, 23),
  ('goshare', 'GoShare', true, 24),
  ('curri', 'Curri', true, 25)
on conflict (id) do nothing;

-- Curb and Curri each have two real, currently-listed driver apps from the
-- same official developer account -- both packages mapped to the same
-- gig_app_id rather than guessing which one is "the" real one, same
-- pattern already used for Amazon Flex's two packages.
insert into public.gig_app_packages (gig_app_id, os, package_name) values
  ('grubhub', 'android', 'com.grubhub.driver'),
  ('gopuff', 'android', 'com.gopuff.godrive2.live'),
  ('curb', 'android', 'com.verifone.curb.driver'),
  ('curb', 'android', 'com.curb.one'),
  ('point_pickup', 'android', 'com.pointpickup.partner'),
  ('skipcart', 'android', 'com.skipcart.app.mobile.prod'),
  -- Real brand name is "Dispatch" (dispatchit.com); Play Store package is
  -- literally com.dispatchit -- verified against the actual listing, not
  -- the many unrelated "dispatch"-named logistics-SaaS apps that also
  -- turned up in search.
  ('dispatch', 'android', 'com.dispatchit'),
  ('deliverthat', 'android', 'com.deliverthat.driver'),
  ('hopskipdrive', 'android', 'com.hopskipdrive.driver'),
  ('goshare', 'android', 'co.goshare.driverapp'),
  ('curri', 'android', 'com.Curri.Driver'),
  ('curri', 'android', 'com.Curri.RouteDriver')
on conflict do nothing;
