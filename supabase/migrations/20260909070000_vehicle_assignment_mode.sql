-- Fleet Sprint 4 (open/rotating vehicle assignment, explicit user
-- requirement, 2026-09-09): lets an org choose between 'fixed' (today's
-- only behavior -- admin pre-assigns one vehicle per driver via
-- assigned_driver_id) and 'open' (driver picks from the org's vehicle
-- list at trip start, e.g. a rotating fleet where vehicles aren't
-- 1:1 with drivers).
--
-- No new RPC needed: organizations_update_admin RLS already lets an
-- admin/owner UPDATE any column on their own org row (same mechanism
-- already used by the web dashboard's org-rename form) -- this is
-- purely a new column for that existing right to write to.
--
-- Standing architecture decision, reaffirmed by the user this same
-- session: the ADMIN-facing toggle for this lives on the web dashboard
-- (controlmiles-web /admin/settings) exclusively, not the mobile app --
-- heavy fleet-admin configuration is web-only going forward. The DRIVER-
-- facing vehicle picker (a driver's own action, not admin config) stays
-- mobile-side, same as every other trip-start interaction.
alter table public.organizations
  add column if not exists vehicle_assignment_mode text not null default 'fixed'
  check (vehicle_assignment_mode in ('fixed', 'open'));
