-- 2026-10-08: account deletion failed for anyone who touched fleet data.
--
-- Found deleting a test fleet driver (al.soler02@gmail.com): deleting the
-- auth user (what the delete-account edge function does) raised 23503 on
-- vehicle_odometer_checkpoints_start_captured_by_fkey. 16 foreign keys to
-- auth.users / profiles had ON DELETE NO ACTION, so the in-app "Delete
-- account" (required by Google Play) failed for every fleet driver and
-- admin who had captured an odometer, done an inspection, accepted an
-- invite, created a geofence/shift/route, etc.
--
-- Rule applied:
--  * "Who did it" columns (captured_by, created_by, accepted_by,
--    reviewed_by, generated_by, assigned_driver_id) -> ON DELETE SET NULL:
--    the record stays (it belongs to the vehicle/fleet), the person goes.
--  * Rows OWNED by the user (vehicle_inspections, trip_incidents,
--    fuel_purchases, session_gps_breadcrumbs, user_id NOT NULL):
--    personal rows (organization_id IS NULL) are deleted with the account;
--    fleet rows are kept for the fleet with user_id set to NULL.

-- 1. Actor columns -> SET NULL (same constraint names and targets).
do $$
declare r record;
begin
  for r in
    select c.conrelid::regclass as tbl, c.conname, a.attname as col, c.confrelid::regclass as target
    from pg_constraint c
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
    where c.contype = 'f'
      and c.confrelid in ('auth.users'::regclass, 'public.profiles'::regclass)
      and c.confdeltype in ('a', 'r')
      and (c.conrelid, c.conname) in (
        ('public.reports'::regclass, 'reports_generated_by_fkey'),
        ('public.vehicle_geofences'::regclass, 'vehicle_geofences_created_by_fkey'),
        ('public.fleet_driver_slots'::regclass, 'fleet_driver_slots_created_by_fkey'),
        ('public.routes'::regclass, 'routes_assigned_driver_id_fkey'),
        ('public.routes'::regclass, 'routes_created_by_fkey'),
        ('public.vehicle_odometer_checkpoints'::regclass, 'vehicle_odometer_checkpoints_start_captured_by_fkey'),
        ('public.vehicle_odometer_checkpoints'::regclass, 'vehicle_odometer_checkpoints_end_captured_by_fkey'),
        ('public.driver_invites'::regclass, 'driver_invites_created_by_fkey'),
        ('public.driver_invites'::regclass, 'driver_invites_accepted_by_fkey'),
        ('public.shifts'::regclass, 'shifts_created_by_fkey'),
        ('public.shift_blocks'::regclass, 'shift_blocks_created_by_fkey'),
        ('public.fuel_anomalies'::regclass, 'fuel_anomalies_reviewed_by_fkey')
      )
  loop
    execute format('alter table %s drop constraint %I', r.tbl, r.conname);
    execute format('alter table %s add constraint %I foreign key (%I) references %s(id) on delete set null',
                   r.tbl, r.conname, r.col, r.target);
  end loop;
end $$;

-- 2. Owned rows: fleet rows survive without the user.
alter table public.vehicle_inspections alter column user_id drop not null;
alter table public.trip_incidents alter column user_id drop not null;
alter table public.fuel_purchases alter column user_id drop not null;
alter table public.session_gps_breadcrumbs alter column user_id drop not null;

alter table public.vehicle_inspections drop constraint vehicle_inspections_user_id_fkey,
  add constraint vehicle_inspections_user_id_fkey foreign key (user_id) references public.profiles(id) on delete set null;
alter table public.trip_incidents drop constraint trip_incidents_user_id_fkey,
  add constraint trip_incidents_user_id_fkey foreign key (user_id) references public.profiles(id) on delete set null;
alter table public.fuel_purchases drop constraint fuel_purchases_user_id_fkey,
  add constraint fuel_purchases_user_id_fkey foreign key (user_id) references public.profiles(id) on delete set null;
alter table public.session_gps_breadcrumbs drop constraint session_gps_breadcrumbs_user_id_fkey,
  add constraint session_gps_breadcrumbs_user_id_fkey foreign key (user_id) references public.profiles(id) on delete set null;

-- 3. Personal rows go with the account (runs before the FK actions).
create or replace function public.fn_delete_personal_rows_on_profile_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.vehicle_inspections where user_id = old.id and organization_id is null;
  delete from public.trip_incidents where user_id = old.id and organization_id is null;
  delete from public.fuel_purchases where user_id = old.id and organization_id is null;
  delete from public.session_gps_breadcrumbs where user_id = old.id and organization_id is null;
  return old;
end $$;

revoke all on function public.fn_delete_personal_rows_on_profile_delete() from public, anon, authenticated;

drop trigger if exists trg_delete_personal_rows_on_profile_delete on public.profiles;
create trigger trg_delete_personal_rows_on_profile_delete
  before delete on public.profiles
  for each row execute function public.fn_delete_personal_rows_on_profile_delete();
