-- Domain boundaries check (2026-10-22). Read-only: run it after every
-- migration (Supabase SQL editor, or psql against a branch). Any row it
-- returns is a boundary break to fix or to justify in the allow-list.
--
-- One database, several services:
--   gig            ControlMiles personal (gig drivers, Play billing)
--   fleet          ControlMiles Fleet, shared by every fleet type
--   school_bus     Fleet > school bus transport (routes, stops, riders)
--   driving_school Fleet > driving school (students, classes, portal)
--   core           tables both apps use; rows tell the service apart:
--                  organization_id IS NULL = gig, NOT NULL = fleet
--
-- Rules:
--   R1  a function touches gig tables and fleet-side tables
--   R2  a function touches school_bus and driving_school tables
--   R3  a trigger on a core table that is not in the trigger registry
--   R4  a gig/fleet trigger on a core table without its WHEN guard
--
-- Table and trigger domains live below; a new table or trigger is added
-- here in the same migration that creates it.

with table_domain(tbl, domain) as (values
  -- gig
  ('gig_apps', 'gig'), ('gig_app_packages', 'gig'), ('play_subscriptions', 'gig'),
  -- fleet (every fleet type)
  ('organizations', 'fleet'), ('organization_members', 'fleet'), ('branches', 'fleet'),
  ('branch_moves', 'fleet'), ('driver_invites', 'fleet'), ('driver_workdays', 'fleet'),
  ('fleet_driver_slots', 'fleet'), ('driver_slot_claim_attempts', 'fleet'),
  ('fleet_type_changes', 'fleet'), ('fuel_anomalies', 'fleet'), ('vehicle_geofences', 'fleet'),
  ('vehicle_geofence_alerts', 'fleet'), ('vehicle_inspections', 'fleet'),
  ('trip_approvals', 'fleet'), ('driver_safety_events', 'fleet'),
  ('driver_notifications', 'fleet'), ('shifts', 'fleet'), ('shift_blocks', 'fleet'),
  ('trip_incidents', 'fleet'),
  -- school bus
  ('routes', 'school_bus'), ('route_stops', 'school_bus'), ('route_runs', 'school_bus'),
  ('route_stop_events', 'school_bus'), ('route_crew_overrides', 'school_bus'),
  ('students', 'school_bus'), ('student_stop_assignments', 'school_bus'),
  ('ridership_events', 'school_bus'), ('school_sites', 'school_bus'),
  -- driving school
  ('ds_students', 'driving_school'), ('ds_student_private', 'driving_school'),
  ('ds_programs', 'driving_school'), ('ds_packages', 'driving_school'),
  ('ds_student_packages', 'driving_school'), ('ds_skills', 'driving_school'),
  ('ds_evaluations', 'driving_school'), ('ds_evaluation_scores', 'driving_school'),
  ('ds_certificates', 'driving_school'), ('ds_availability', 'driving_school'),
  ('ds_time_off', 'driving_school'), ('ds_settings', 'driving_school'),
  ('ds_portal_links', 'driving_school'), ('ds_public_pages', 'driving_school'),
  ('ds_enrollment_requests', 'driving_school'), ('ds_slot_notices', 'driving_school'),
  ('ds_reminders_sent', 'driving_school')
),
-- Functions allowed to cross: account/organization lifecycle has to reach
-- every service's rows by design. Each entry says why.
allowed(fn) as (values
  ('delete_organization'),        -- removes an organization and everything under it
  ('delete_my_account'),          -- account deletion reaches personal and fleet rows
  ('fn_delete_personal_rows_on_profile_delete')
),
-- Triggers on core tables, by the service they serve. 'core' ones run for
-- every row on purpose; the others must carry their WHEN guard.
trigger_domain(tbl, tg, domain, guard) as (values
  ('sessions', 'sessions_notify_trip_safety', 'fleet', 'organization_id IS NOT NULL'),
  ('sessions', 'sessions_vehicle_active_trip', 'core', null),
  ('sessions', 'tr_sessions_block_cross_app_open_trip', 'core', null),
  ('sessions', 'tr_sessions_enforce_active_org_membership', 'fleet', 'organization_id IS NOT NULL'),
  ('sessions', 'tr_sessions_enforce_trial', 'gig', 'organization_id IS NULL'),
  ('sessions', 'tr_sessions_guard_tenant', 'core', null),
  ('sessions', 'tr_sessions_link_shift_block', 'fleet', 'shift_block_id IS NOT NULL'),
  ('sessions', 'tr_sessions_touch_updated_at', 'core', null),
  ('sessions', 'trg_discard_zero_mile_trip', 'core', null),
  ('sessions', 'trg_freeze_closed_session', 'core', null),
  ('sessions', 'trg_session_miles_from_sections', 'core', null),
  ('vehicles', 'tr_vehicles_block_switch_during_session', 'core', null),
  ('vehicles', 'tr_vehicles_driving_school_cycle', 'driving_school', 'organization_id IS NOT NULL'),
  ('vehicles', 'tr_vehicles_enforce_count_limit', 'gig', 'organization_id IS NULL'),
  ('vehicles', 'tr_vehicles_enforce_odometer_cycle_tier', 'gig', 'organization_id IS NULL'),
  ('vehicles', 'tr_vehicles_enforce_odometer_floor', 'core', null),
  ('vehicles', 'tr_vehicles_school_limit', 'driving_school', 'organization_id IS NOT NULL'),
  ('vehicles', 'tr_vehicles_set_cycle_anchor', 'core', null),
  ('vehicles', 'tr_vehicles_touch_updated_at', 'core', null),
  ('vehicles', 'trg_assign_vehicle_display_id', 'core', null),
  ('vehicles', 'trg_freeze_vehicle_display_id', 'core', null),
  ('vehicles', 'trg_vehicles_route_run_stops', 'school_bus', 'organization_id IS NOT NULL')
),
-- Function bodies without comments and string literals, so a feature name
-- like 'students' or a comment does not count as touching a table.
fn_code as (
  select p.proname as fn,
         regexp_replace(regexp_replace(p.prosrc, '--[^\n]*', '', 'g'), '''[^'']*''', '', 'g') as code
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
  where p.prokind = 'f'
    and not exists (select 1 from pg_depend e where e.objid = p.oid and e.deptype = 'e')
    and p.proname not in (select fn from allowed)
),
fn_touches as (
  select f.fn, d.domain
  from fn_code f
  join table_domain d
    on f.code ~* ('(^|[^a-z0-9_])(public\.)?' || d.tbl || '([^a-z0-9_]|$)')
  group by 1, 2
),
fn_domains as (
  select fn, array_agg(domain order by domain) as domains from fn_touches group by fn
)
select 'R1' as rule, fn as object, array_to_string(domains, ', ') as detail
  from fn_domains
 where 'gig' = any(domains)
   and domains && array['fleet', 'school_bus', 'driving_school']
union all
select 'R2', fn, array_to_string(domains, ', ')
  from fn_domains
 where domains @> array['school_bus', 'driving_school']
union all
select 'R3', c.relname || '.' || t.tgname, 'trigger not in the registry'
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
 where c.relnamespace = 'public'::regnamespace
   and c.relname in (select distinct tbl from trigger_domain)
   and not t.tgisinternal
   and not exists (select 1 from trigger_domain r where r.tbl = c.relname and r.tg = t.tgname)
union all
select 'R4', r.tbl || '.' || r.tg, r.domain || ' trigger needs WHEN (' || r.guard || ')'
  from trigger_domain r
  join pg_class c on c.relname = r.tbl and c.relnamespace = 'public'::regnamespace
  join pg_trigger t on t.tgrelid = c.oid and t.tgname = r.tg
 where r.guard is not null
   and position(upper(r.guard) in upper(pg_get_triggerdef(t.oid))) = 0
order by 1, 2;
