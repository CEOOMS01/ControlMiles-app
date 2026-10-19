-- Fleet features by service and plan (user-approved table, 2026-10-19).
--
-- Each organization gets ONLY what its service (industry_template) and its
-- plan (Starter / Growth) include. Whatever is not included is not offered
-- anywhere -- no menu item, no page, no "upgrade" card -- and the database
-- refuses it here, not just the interface. "Show all modules" no longer
-- has any effect (the web and app stopped reading it).
--
--   Every service, Starter: team & vehicles, GPS trips, odometer photos,
--     Report Portal, revocation, import, fuel log, maintenance, reviews,
--     DVIR inspections (moved down from Growth), per-driver PDFs.
--   Every service, Growth adds: live map, fleet-wide export, activity log,
--     safety scores, fuel alerts, shift schedules, open vehicle assignment.
--   Per service:
--     delivery        Starter: owner-operators          Growth: routes, geofences
--     field_service                                     Growth: routes, geofences
--     trucking        Starter: IFTA, owner-operators    Growth: routes, geofences
--     construction    Starter: IFTA                     Growth: routes, geofences
--     passenger                                         Growth: routes, geofences
--     school_transport Starter: school routes, stops, schools & students,
--                      attendance, bus aides, live map  Growth: live run board,
--                      substitutes, attendance export, geofences
--     sales                                             Growth: geofences, trip approval
--     driving_school  Starter: classes, day schedule, live map   Growth: (base Growth only)
--     general         Starter: IFTA, owner-operators    Growth: routes, geofences
--   Enterprise stays a human service ("Contact us"), no features of its own.
--   The 15-day trial now runs at Growth so a new fleet sees everything it
--   would pay for.
--
-- fn_org_features(org) is the one list the web and the app read.

-- ------------------------------------------------------------------
-- Tier, without the caller-membership check (for triggers/cron), and
-- the public wrapper unchanged in signature.
-- ------------------------------------------------------------------
create or replace function public.fn_org_tier_internal(p_org_id uuid)
returns text
language sql
stable
security definer
set search_path to 'public'
as $$
  select coalesce((
    select case
      when o.tier_enforcement_exempt then 'growth'
      when o.subscription_status in ('active', 'trialing', 'past_due') and o.subscription_tier = 'growth' then 'growth'
      when o.subscription_status in ('active', 'trialing', 'past_due') and o.subscription_tier = 'starter' then 'starter'
      when now() - o.created_at <= interval '15 days' then 'growth'
      else 'none'
    end
    from public.organizations o
    where o.id = p_org_id
  ), 'none');
$$;
revoke execute on function public.fn_org_tier_internal(uuid) from public, anon, authenticated;

create or replace function public.fn_org_effective_tier(p_org_id uuid)
returns text
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  if not public.is_org_member(p_org_id) then
    return 'none';
  end if;
  return public.fn_org_tier_internal(p_org_id);
end;
$$;

-- ------------------------------------------------------------------
-- The service x plan table.
-- ------------------------------------------------------------------
create or replace function public.fn_org_feature_list_internal(p_org_id uuid)
returns text[]
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_tpl text;
  v_tier text;
  f text[] := '{}';
begin
  select industry_template into v_tpl from public.organizations where id = p_org_id;
  if v_tpl is null then
    return f;
  end if;
  v_tier := public.fn_org_tier_internal(p_org_id);
  if v_tier = 'none' then
    return f;
  end if;

  f := array['dvir'];
  if v_tpl in ('delivery', 'trucking', 'general') then f := f || 'owner_operators'::text; end if;
  if v_tpl in ('trucking', 'construction', 'general') then f := f || 'ifta'::text; end if;
  if v_tpl = 'school_transport' then f := f || 'school'::text; end if;
  if v_tpl = 'driving_school' then f := f || 'classes'::text; end if;
  -- A driving school's or school fleet's admin always sees their drivers
  -- live (user rule, 2026-10-19), on any plan.
  if v_tpl in ('school_transport', 'driving_school') then f := f || 'live_map'::text; end if;

  if v_tier = 'growth' then
    if not 'live_map' = any(f) then f := f || 'live_map'::text; end if;
    f := f || array['fleet_export', 'activity_log', 'safety_scores', 'fuel_alerts',
                    'shift_schedules', 'open_assignment'];
    if v_tpl in ('delivery', 'field_service', 'trucking', 'construction', 'passenger', 'general') then
      f := f || 'routes'::text;
    end if;
    if v_tpl <> 'driving_school' then f := f || 'geofences'::text; end if;
    if v_tpl = 'school_transport' then f := f || 'school_live'::text; end if;
    if v_tpl = 'sales' then f := f || 'trip_approval'::text; end if;
  end if;
  return f;
end;
$$;
revoke execute on function public.fn_org_feature_list_internal(uuid) from public, anon, authenticated;

create or replace function public.fn_org_feature_internal(p_org_id uuid, p_feature text)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select p_feature = any(public.fn_org_feature_list_internal(p_org_id));
$$;
revoke execute on function public.fn_org_feature_internal(uuid, text) from public, anon, authenticated;

-- For RLS and RPCs: the caller must belong to the org AND the org must have it.
create or replace function public.fn_org_has_feature(p_org_id uuid, p_feature text)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select public.is_org_member(p_org_id) and public.fn_org_feature_internal(p_org_id, p_feature);
$$;
revoke execute on function public.fn_org_has_feature(uuid, text) from public, anon;
grant execute on function public.fn_org_has_feature(uuid, text) to authenticated;

-- What the web and the app read: empty for a non-member.
create or replace function public.fn_org_features(p_org_id uuid)
returns text[]
language sql
stable
security definer
set search_path to 'public'
as $$
  select case when public.is_org_member(p_org_id)
              then public.fn_org_feature_list_internal(p_org_id)
              else '{}'::text[] end;
$$;
revoke execute on function public.fn_org_features(uuid) from public, anon;
grant execute on function public.fn_org_features(uuid) to authenticated;

create or replace function public.fn_require_org_feature(p_org_id uuid, p_feature text)
returns void
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  if p_org_id is null or not public.fn_org_feature_internal(p_org_id, p_feature) then
    raise exception 'FEATURE_NOT_IN_PLAN';
  end if;
end;
$$;
revoke execute on function public.fn_require_org_feature(uuid, text) from public, anon;
grant execute on function public.fn_require_org_feature(uuid, text) to authenticated;

-- Classes now follow the table (driving school, any paid plan or trial).
create or replace function public.fn_org_has_classes(p_org uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select public.fn_org_feature_internal(p_org, 'classes');
$$;

-- ------------------------------------------------------------------
-- Guards added to existing functions. Each insert is checked: if the
-- anchor text is missing the migration fails instead of silently
-- leaving a function unguarded. Re-running skips functions that already
-- carry the guard.
-- ------------------------------------------------------------------
create or replace function pg_temp.add_guard(p_fn regprocedure, p_anchor text, p_guard text)
returns void
language plpgsql
as $$
declare
  d text := pg_get_functiondef(p_fn);
  pos int;
begin
  if strpos(d, p_guard) > 0 then
    return;
  end if;
  pos := strpos(d, p_anchor);
  if pos = 0 then
    raise exception 'add_guard: anchor not found in %', p_fn;
  end if;
  execute overlay(d placing p_anchor || p_guard from pos for length(p_anchor));
end;
$$;

-- IFTA
select pg_temp.add_guard('public.compute_ifta_vehicle_state_miles(uuid,date,date)',
  E'raise exception ''Not authorized for this organization'';\n  end if;\n',
  E'  perform public.fn_require_org_feature(p_organization_id, ''ifta'');\n');
select pg_temp.add_guard('public.set_vehicle_ifta(uuid,boolean,text)',
  E'raise exception ''Not authorized'';\n  end if;\n',
  E'  perform public.fn_require_org_feature(v_org, ''ifta'');\n');
select pg_temp.add_guard('public.correct_fuel_purchase_ifta(uuid,text,text,boolean)',
  E'raise exception ''Not authorized'';\n  end if;\n',
  E'  perform public.fn_require_org_feature(v_org, ''ifta'');\n');

-- Safety scores (admin page, driver app card, and the notifications drivers get)
select pg_temp.add_guard('public.driver_safety_scores(uuid,date,date,text)',
  E'raise exception ''Not authorized for this organization'';\n  end if;\n',
  E'  perform public.fn_require_org_feature(p_organization_id, ''safety_scores'');\n');
select pg_temp.add_guard('public.fn_notify_trip_safety()',
  E'    return null;\n  end if;\n',
  E'  if not public.fn_org_feature_internal(new.organization_id, ''safety_scores'') then\n    return null;\n  end if;\n');
select pg_temp.add_guard('public.fn_send_safety_summaries()',
  E'where m.member_role = ''driver'' and m.is_active',
  E'\n      and public.fn_org_feature_internal(m.organization_id, ''safety_scores'')');

-- Fuel alerts
select pg_temp.add_guard('public.review_fuel_anomaly(uuid,text,text)',
  E'raise exception ''Not authorized'';\n  end if;\n',
  E'  perform public.fn_require_org_feature(v_org, ''fuel_alerts'');\n');

-- Owner-operators
select pg_temp.add_guard('public.register_my_own_vehicle(uuid,text,text,integer,text,text)',
  E'raise exception ''Not authorized for this organization'';\n  end if;\n',
  E'  perform public.fn_require_org_feature(p_organization_id, ''owner_operators'');\n');

-- Shift schedules (recurring weekly shifts)
select pg_temp.add_guard('public.my_shift_today(uuid)',
  E'raise exception ''Not authorized for this organization'';\n  end if;\n',
  E'  if not public.fn_org_feature_internal(p_organization_id, ''shift_schedules'') then\n    return;\n  end if;\n');

-- School runs (driver and bus aide in the app)
select pg_temp.add_guard('public.fn_my_open_run(uuid)',
  E'raise exception ''ROUTE_NOT_ASSIGNED'';\n  end if;\n',
  E'  perform public.fn_require_org_feature(v_run.organization_id, ''school'');\n');
select pg_temp.add_guard('public.fn_my_crew_run(uuid)',
  E'raise exception ''ROUTE_NOT_ASSIGNED'';\n  end if;\n',
  E'  perform public.fn_require_org_feature(v_run.organization_id, ''school'');\n');
select pg_temp.add_guard('public.start_route_run(uuid,uuid)',
  E'raise exception ''ROUTE_NOT_ASSIGNED'';\n  end if;\n',
  E'  perform public.fn_require_org_feature(v_route.organization_id, ''school'');\n');
select pg_temp.add_guard('public.my_school_routes_today(uuid)',
  E'if auth.uid() is null then raise exception ''Not authenticated''; end if;\n',
  E'  if not public.fn_org_feature_internal(p_organization_id, ''school'') then return ''[]''::jsonb; end if;\n');

-- DVIR: every paid plan (was Growth only).
select pg_temp.add_guard('public.submit_vehicle_inspection(uuid,text,jsonb,numeric)',
  E'raise exception ''Not authorized to inspect this vehicle'';\n  end if;\n',
  E'  if v_org is not null then\n    perform public.fn_require_org_feature(v_org, ''dvir'');\n  end if;\n');
do $$
declare d text := pg_get_functiondef('public.submit_vehicle_inspection(uuid,text,jsonb,numeric)'::regprocedure);
begin
  d := replace(d,
    E'  if v_org is not null and public.fn_org_effective_tier(v_org) <> ''growth'' then\n    raise exception ''FLEET_GROWTH_REQUIRED'';\n  end if;\n', '');
  execute d;
end $$;

-- Live map: new positions are only stored for fleets that have the live map.
-- Geofence checks keep using the reported point, so they don't depend on it.
do $$
declare d text := pg_get_functiondef('public.update_vehicle_location(uuid,double precision,double precision,double precision)'::regprocedure);
begin
  if strpos(d, 'fn_org_feature_internal(v_org, ''live_map'')') = 0 then
    d := replace(d,
      E'  update public.vehicles\n  set last_latitude = p_latitude, last_longitude = p_longitude, last_speed = p_speed, last_location_at = now()\n  where id = p_vehicle_id;\n',
      E'  if public.fn_org_feature_internal(v_org, ''live_map'') then\n    update public.vehicles\n    set last_latitude = p_latitude, last_longitude = p_longitude, last_speed = p_speed, last_location_at = now()\n    where id = p_vehicle_id;\n  end if;\n');
    if strpos(d, 'fn_org_feature_internal(v_org, ''live_map'')') = 0 then
      raise exception 'update_vehicle_location: anchor not found';
    end if;
    execute d;
  end if;
end $$;

-- Open vehicle assignment
create or replace function public.fn_enforce_vehicle_assignment_mode_tier()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.vehicle_assignment_mode = 'open'
     and new.vehicle_assignment_mode is distinct from old.vehicle_assignment_mode
     and not public.fn_org_feature_internal(new.id, 'open_assignment') then
    raise exception 'FEATURE_NOT_IN_PLAN';
  end if;
  return new;
end;
$$;

-- Org switches that belong to a feature can only be turned on with it.
create or replace function public.fn_enforce_org_feature_switches()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.allow_driver_owned_vehicles and not coalesce(old.allow_driver_owned_vehicles, false)
     and not public.fn_org_feature_internal(new.id, 'owner_operators') then
    raise exception 'FEATURE_NOT_IN_PLAN';
  end if;
  if new.use_shift_schedules and not coalesce(old.use_shift_schedules, false)
     and not public.fn_org_feature_internal(new.id, 'shift_schedules') then
    raise exception 'FEATURE_NOT_IN_PLAN';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_enforce_org_feature_switches on public.organizations;
create trigger trg_enforce_org_feature_switches
  before update of allow_driver_owned_vehicles, use_shift_schedules on public.organizations
  for each row execute function public.fn_enforce_org_feature_switches();

-- ------------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------------

-- Routes: general routes need 'routes', school routes need 'school'.
create or replace function public.fn_route_feature_ok(p_org_id uuid, p_route_type text)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select public.is_org_member(p_org_id) and public.fn_org_feature_internal(p_org_id,
           case when p_route_type in ('school_am', 'school_pm') then 'school' else 'routes' end);
$$;
revoke execute on function public.fn_route_feature_ok(uuid, text) from public, anon;
grant execute on function public.fn_route_feature_ok(uuid, text) to authenticated;

drop policy if exists routes_select_admin on public.routes;
create policy routes_select_admin on public.routes for select to authenticated
  using (public.is_org_operator_or_above(organization_id) and public.fn_route_feature_ok(organization_id, route_type));
drop policy if exists routes_select_assigned_driver on public.routes;
create policy routes_select_assigned_driver on public.routes for select to authenticated
  using (assigned_driver_id = auth.uid() and public.fn_route_feature_ok(organization_id, route_type));
drop policy if exists routes_insert_admin on public.routes;
create policy routes_insert_admin on public.routes for insert to authenticated
  with check (public.is_org_operator_or_above(organization_id) and created_by = auth.uid()
              and public.fn_route_feature_ok(organization_id, route_type));
drop policy if exists routes_update_admin on public.routes;
create policy routes_update_admin on public.routes for update to authenticated
  using (public.is_org_operator_or_above(organization_id) and public.fn_route_feature_ok(organization_id, route_type))
  with check (public.is_org_operator_or_above(organization_id) and public.fn_route_feature_ok(organization_id, route_type));
drop policy if exists routes_delete_admin on public.routes;
create policy routes_delete_admin on public.routes for delete to authenticated
  using (public.is_org_operator_or_above(organization_id) and status = 'draft'
         and public.fn_route_feature_ok(organization_id, route_type));

-- School tables: 'school'.
do $$
declare t text;
begin
  foreach t in array array['school_sites', 'students', 'student_stop_assignments', 'route_stops'] loop
    execute format('drop policy if exists %1$s_select_admin on public.%1$s', t);
    execute format('create policy %1$s_select_admin on public.%1$s for select to authenticated
                      using (public.is_org_operator_or_above(organization_id)
                             and public.fn_org_has_feature(organization_id, ''school''))', t);
    execute format('drop policy if exists %1$s_write_admin on public.%1$s', t);
    execute format('create policy %1$s_write_admin on public.%1$s for all to authenticated
                      using (public.is_org_operator_or_above(organization_id)
                             and public.fn_org_has_feature(organization_id, ''school''))
                      with check (public.is_org_operator_or_above(organization_id)
                             and public.fn_org_has_feature(organization_id, ''school''))', t);
  end loop;
  foreach t in array array['route_runs', 'route_stop_events', 'ridership_events'] loop
    execute format('drop policy if exists %1$s_select_admin on public.%1$s', t);
    execute format('create policy %1$s_select_admin on public.%1$s for select to authenticated
                      using (public.is_org_operator_or_above(organization_id)
                             and public.fn_org_has_feature(organization_id, ''school''))', t);
  end loop;
end $$;

-- Substitutes for the day: 'school_live'.
drop policy if exists route_crew_overrides_read on public.route_crew_overrides;
create policy route_crew_overrides_read on public.route_crew_overrides for select to authenticated
  using (public.is_org_operator_or_above(organization_id)
         and public.fn_org_has_feature(organization_id, 'school_live'));
drop policy if exists route_crew_overrides_write_admin on public.route_crew_overrides;
create policy route_crew_overrides_write_admin on public.route_crew_overrides for all to authenticated
  using (public.is_org_operator_or_above(organization_id)
         and public.fn_org_has_feature(organization_id, 'school_live'))
  with check (public.is_org_operator_or_above(organization_id)
         and public.fn_org_has_feature(organization_id, 'school_live')
         and exists (select 1 from public.routes r
                      where r.id = route_crew_overrides.route_id and r.organization_id = route_crew_overrides.organization_id)
         and (vehicle_id is null or exists (select 1 from public.vehicles v
                      where v.id = route_crew_overrides.vehicle_id and v.organization_id = route_crew_overrides.organization_id))
         and (driver_id is null or exists (select 1 from public.organization_members m
                      where m.user_id = route_crew_overrides.driver_id and m.organization_id = route_crew_overrides.organization_id
                        and m.is_active)));

-- Geofences: 'geofences' (was: Growth for every fleet type).
drop policy if exists vehicle_geofences_select on public.vehicle_geofences;
create policy vehicle_geofences_select on public.vehicle_geofences for select
  using (public.fn_org_has_feature(organization_id, 'geofences'));
drop policy if exists vehicle_geofences_insert on public.vehicle_geofences;
create policy vehicle_geofences_insert on public.vehicle_geofences for insert
  with check (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'geofences'));
drop policy if exists vehicle_geofences_update on public.vehicle_geofences;
create policy vehicle_geofences_update on public.vehicle_geofences for update
  using (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'geofences'))
  with check (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'geofences'));
drop policy if exists vehicle_geofences_delete on public.vehicle_geofences;
create policy vehicle_geofences_delete on public.vehicle_geofences for delete
  using (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'geofences'));
drop policy if exists vehicle_geofence_alerts_select on public.vehicle_geofence_alerts;
create policy vehicle_geofence_alerts_select on public.vehicle_geofence_alerts for select
  using (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'geofences'));

-- Recurring shifts: 'shift_schedules'.
drop policy if exists shifts_select on public.shifts;
create policy shifts_select on public.shifts for select
  using (public.fn_org_has_feature(organization_id, 'shift_schedules'));
drop policy if exists shifts_insert on public.shifts;
create policy shifts_insert on public.shifts for insert
  with check (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'shift_schedules'));
drop policy if exists shifts_update on public.shifts;
create policy shifts_update on public.shifts for update
  using (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'shift_schedules'));
drop policy if exists shifts_delete on public.shifts;
create policy shifts_delete on public.shifts for delete
  using (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'shift_schedules'));

-- Fuel alerts: 'fuel_alerts'.
drop policy if exists fuel_anomalies_select on public.fuel_anomalies;
create policy fuel_anomalies_select on public.fuel_anomalies for select
  using (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'fuel_alerts'));

-- Safety events (admin view): 'safety_scores'.
drop policy if exists driver_safety_events_select on public.driver_safety_events;
create policy driver_safety_events_select on public.driver_safety_events for select
  using (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'safety_scores'));

-- Org-wide activity log: 'activity_log'. Everyone still reads their own events.
drop policy if exists audit_select on public.audit_events;
create policy audit_select on public.audit_events for select to authenticated
  using (user_id = auth.uid()
         or (organization_id is not null and public.fn_org_has_feature(organization_id, 'activity_log')));

-- ------------------------------------------------------------------
-- Trip approval (sales fleets, Growth): the admin approves or rejects each
-- closed trip, like an expense report. Kept apart from sessions so the
-- sealed trip record is never touched.
-- ------------------------------------------------------------------
create table if not exists public.trip_approvals (
  session_id uuid primary key references public.sessions(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  status text not null check (status in ('approved', 'rejected')),
  note text check (note is null or length(note) <= 500),
  decided_by uuid not null references auth.users(id),
  decided_at timestamptz not null default now()
);
create index if not exists trip_approvals_org_idx on public.trip_approvals (organization_id, decided_at desc);
alter table public.trip_approvals enable row level security;

drop policy if exists trip_approvals_select on public.trip_approvals;
create policy trip_approvals_select on public.trip_approvals for select to authenticated
  using (public.fn_org_has_feature(organization_id, 'trip_approval')
         and (public.is_org_operator_or_above(organization_id)
              or exists (select 1 from public.sessions s where s.id = trip_approvals.session_id and s.user_id = auth.uid())));

create or replace function public.set_trip_approval(p_session_id uuid, p_status text, p_note text default null)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_org uuid;
  v_closed boolean;
begin
  select organization_id, coalesce(is_closed, false) into v_org, v_closed
  from public.sessions where id = p_session_id;
  if v_org is null or not public.is_org_admin_or_owner(v_org) then
    raise exception 'Not authorized';
  end if;
  perform public.fn_require_org_feature(v_org, 'trip_approval');
  if not v_closed then
    raise exception 'TRIP_NOT_FINISHED';
  end if;
  if p_status is null then
    delete from public.trip_approvals where session_id = p_session_id;
    return;
  end if;
  if p_status not in ('approved', 'rejected') then
    raise exception 'Unknown status: %', p_status;
  end if;
  insert into public.trip_approvals (session_id, organization_id, status, note, decided_by)
  values (p_session_id, v_org, p_status, nullif(btrim(p_note), ''), auth.uid())
  on conflict (session_id) do update
    set status = excluded.status, note = excluded.note,
        decided_by = excluded.decided_by, decided_at = now();
end;
$$;
revoke execute on function public.set_trip_approval(uuid, text, text) from public, anon;
grant execute on function public.set_trip_approval(uuid, text, text) to authenticated;
