-- School transportation (fleet type `school_transport`), phase 0 + 1
-- (2026-10-09, approved plan: controlmiles-web/docs/plan-fleet-school-transportation.md).
--
-- A school route is an ordered list of stops run every service day (AM/PM).
-- Each day's execution is a `route_run` tied to the driver's GPS session:
-- arrival at each stop is marked automatically when the bus's live location
-- (vehicles.last_*, written every ~15 s by update_vehicle_location) enters
-- the stop's radius -- so it works with the phone locked -- or by hand.
-- Students are kept minimal (first name + last initial, grade, school);
-- boarding/alighting is recorded per run. The route finishes with a
-- mandatory "no child left on board" check.
--
-- Drivers never read the tables directly: they go through the
-- SECURITY DEFINER RPCs below, which only return their own routes for today.

-- 1. Fleet type -------------------------------------------------------------
alter table public.organizations drop constraint if exists organizations_industry_template_check;
alter table public.organizations add constraint organizations_industry_template_check
  check (industry_template in ('general', 'delivery', 'field_service', 'trucking', 'construction',
                               'passenger', 'sales', 'driving_school', 'school_transport'));

create or replace function public.fn_valid_fleet_profile(p text)
returns boolean language sql immutable set search_path = public as $$
  select p in ('general', 'delivery', 'field_service', 'trucking', 'construction', 'passenger', 'sales',
               'driving_school', 'school_transport');
$$;

create or replace function public.fn_profile_requires_pretrip(p text)
returns boolean language sql immutable set search_path = public as $$
  select p in ('general', 'trucking', 'construction', 'passenger', 'driving_school', 'school_transport');
$$;

-- 2. Schools ----------------------------------------------------------------
create table if not exists public.school_sites (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  address text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);
create index if not exists school_sites_org_idx on public.school_sites (organization_id);

-- 3. Routes: school fields --------------------------------------------------
alter table public.routes
  add column if not exists route_type text not null default 'general'
    check (route_type in ('general', 'school_am', 'school_pm')),
  add column if not exists school_site_id uuid references public.school_sites(id) on delete set null,
  -- ISO weekday numbers, 1 = Monday ... 7 = Sunday.
  add column if not exists service_days smallint[] not null default '{1,2,3,4,5}';

-- 4. Stops ------------------------------------------------------------------
create table if not exists public.route_stops (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.routes(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  seq integer not null,
  name text not null check (length(trim(name)) > 0),
  address text,
  latitude double precision not null,
  longitude double precision not null,
  radius_meters integer not null default 80 check (radius_meters between 20 and 500),
  scheduled_time time,
  stop_kind text not null default 'pickup' check (stop_kind in ('pickup', 'school', 'dropoff')),
  created_at timestamptz not null default now(),
  unique (route_id, seq) deferrable initially deferred
);
create index if not exists route_stops_route_idx on public.route_stops (route_id, seq);

-- 5. Students ---------------------------------------------------------------
create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  first_name text not null check (length(trim(first_name)) > 0),
  last_initial text check (last_initial is null or length(last_initial) <= 2),
  grade text,
  school_site_id uuid references public.school_sites(id) on delete set null,
  external_id text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists students_org_idx on public.students (organization_id);

create table if not exists public.student_stop_assignments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  route_id uuid not null references public.routes(id) on delete cascade,
  stop_id uuid not null references public.route_stops(id) on delete cascade,
  action text not null check (action in ('board', 'alight')),
  unique (student_id, route_id, action)
);
create index if not exists student_stop_assignments_stop_idx on public.student_stop_assignments (stop_id);

-- 6. Daily execution ----------------------------------------------------------
create table if not exists public.route_runs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  route_id uuid not null references public.routes(id) on delete cascade,
  run_date date not null,
  driver_id uuid references public.profiles(id) on delete set null,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  session_id uuid references public.sessions(id) on delete set null,
  status text not null default 'in_progress' check (status in ('in_progress', 'completed')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  child_check_at timestamptz,
  child_check_latitude double precision,
  child_check_longitude double precision,
  unique (route_id, run_date)
);
create index if not exists route_runs_org_date_idx on public.route_runs (organization_id, run_date);
create index if not exists route_runs_vehicle_active_idx on public.route_runs (vehicle_id) where status = 'in_progress';

create table if not exists public.route_stop_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  run_id uuid not null references public.route_runs(id) on delete cascade,
  stop_id uuid not null references public.route_stops(id) on delete cascade,
  arrived_at timestamptz not null default now(),
  departed_at timestamptz,
  method text not null default 'auto' check (method in ('auto', 'manual')),
  unique (run_id, stop_id)
);

create table if not exists public.ridership_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  run_id uuid not null references public.route_runs(id) on delete cascade,
  stop_id uuid references public.route_stops(id) on delete set null,
  student_id uuid not null references public.students(id) on delete cascade,
  action text not null check (action in ('board', 'alight')),
  at timestamptz not null default now(),
  method text not null default 'manual' check (method in ('manual')),
  unique (run_id, student_id, action)
);
create index if not exists ridership_events_run_idx on public.ridership_events (run_id);

-- 7. RLS: admins/operators manage; drivers only via RPCs --------------------
do $$
declare t text;
begin
  foreach t in array array['school_sites', 'route_stops', 'students', 'student_stop_assignments',
                           'route_runs', 'route_stop_events', 'ridership_events']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_select_admin', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.is_org_operator_or_above(organization_id))',
                   t || '_select_admin', t);
    execute format('revoke all on public.%I from anon', t);
  end loop;
  -- Planning tables: admins/operators write them from the dashboard.
  foreach t in array array['school_sites', 'route_stops', 'students', 'student_stop_assignments']
  loop
    execute format('drop policy if exists %I on public.%I', t || '_write_admin', t);
    execute format('create policy %I on public.%I for all to authenticated using (public.is_org_operator_or_above(organization_id)) with check (public.is_org_operator_or_above(organization_id))',
                   t || '_write_admin', t);
  end loop;
end $$;
-- Execution tables are written only by the RPCs/trigger below.
revoke insert, update, delete, truncate on public.route_runs, public.route_stop_events, public.ridership_events from authenticated;

-- A stop/assignment must belong to the same fleet as its route.
create or replace function public.fn_school_same_org()
returns trigger language plpgsql set search_path = public as $$
begin
  if TG_TABLE_NAME = 'route_stops' then
    if not exists (select 1 from public.routes r where r.id = new.route_id and r.organization_id = new.organization_id) then
      raise exception 'Route belongs to another fleet';
    end if;
  elsif TG_TABLE_NAME = 'student_stop_assignments' then
    if not exists (
      select 1 from public.route_stops s join public.students st on st.id = new.student_id
       where s.id = new.stop_id and s.route_id = new.route_id
         and s.organization_id = new.organization_id and st.organization_id = new.organization_id
    ) then
      raise exception 'Student, stop and route must belong to the same fleet';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_route_stops_same_org on public.route_stops;
create trigger trg_route_stops_same_org before insert or update on public.route_stops
  for each row execute function public.fn_school_same_org();
drop trigger if exists trg_student_stop_assignments_same_org on public.student_stop_assignments;
create trigger trg_student_stop_assignments_same_org before insert or update on public.student_stop_assignments
  for each row execute function public.fn_school_same_org();

-- 8. Helpers ------------------------------------------------------------------
create or replace function public.fn_meters_between(lat1 double precision, lon1 double precision,
                                                      lat2 double precision, lon2 double precision)
returns double precision language sql immutable set search_path = public as $$
  select 6371000 * acos(least(1.0, greatest(-1.0,
    cos(radians(lat1)) * cos(radians(lat2)) * cos(radians(lon2) - radians(lon1)) +
    sin(radians(lat1)) * sin(radians(lat2)))));
$$;

create or replace function public.fn_org_today(p_org uuid)
returns date language sql stable set search_path = public as $$
  select (now() at time zone coalesce((select timezone from public.organizations where id = p_org), 'America/New_York'))::date;
$$;

-- 9. Driver RPCs --------------------------------------------------------------
-- Today's school routes assigned to the caller, with stops, students and the
-- day's run (if started).
create or replace function public.my_school_routes_today(p_organization_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_today date := public.fn_org_today(p_organization_id);
  v_dow smallint := extract(isodow from v_today)::smallint;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', r.id, 'name', r.name, 'route_type', r.route_type,
      'scheduled_start_time', r.scheduled_start_time,
      'vehicle_id', r.assigned_vehicle_id,
      'school', (select ss.name from public.school_sites ss where ss.id = r.school_site_id),
      'run', (select jsonb_build_object('id', rr.id, 'status', rr.status, 'started_at', rr.started_at,
                                        'completed_at', rr.completed_at)
                from public.route_runs rr where rr.route_id = r.id and rr.run_date = v_today),
      'stops', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', s.id, 'seq', s.seq, 'name', s.name, 'address', s.address,
          'latitude', s.latitude, 'longitude', s.longitude, 'radius_meters', s.radius_meters,
          'scheduled_time', s.scheduled_time, 'stop_kind', s.stop_kind,
          'arrived_at', (select e.arrived_at from public.route_stop_events e
                           join public.route_runs rr on rr.id = e.run_id
                          where e.stop_id = s.id and rr.route_id = r.id and rr.run_date = v_today),
          'students', coalesce((
            select jsonb_agg(jsonb_build_object(
              'id', st.id, 'name', st.first_name || coalesce(' ' || st.last_initial || '.', ''),
              'grade', st.grade, 'action', a.action,
              'done', exists (select 1 from public.ridership_events re
                                join public.route_runs rr on rr.id = re.run_id
                               where re.student_id = st.id and re.action = a.action
                                 and rr.route_id = r.id and rr.run_date = v_today))
              order by st.first_name)
              from public.student_stop_assignments a
              join public.students st on st.id = a.student_id and st.is_active
             where a.stop_id = s.id), '[]'::jsonb))
          order by s.seq)
          from public.route_stops s where s.route_id = r.id), '[]'::jsonb))
      order by r.scheduled_start_time nulls last, r.name)
      from public.routes r
     where r.organization_id = p_organization_id
       and r.assigned_driver_id = auth.uid()
       and r.route_type in ('school_am', 'school_pm')
       and r.status = 'active'
       and v_dow = any (r.service_days)
  ), '[]'::jsonb);
end $$;

create or replace function public.start_route_run(p_route_id uuid, p_session_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_route public.routes%rowtype;
  v_session public.sessions%rowtype;
  v_today date;
  v_run_id uuid;
  v_status text;
begin
  select * into v_route from public.routes where id = p_route_id;
  if not found or v_route.assigned_driver_id is distinct from auth.uid() then
    raise exception 'ROUTE_NOT_ASSIGNED';
  end if;
  if v_route.status <> 'active' or v_route.route_type not in ('school_am', 'school_pm') then
    raise exception 'ROUTE_NOT_ACTIVE';
  end if;
  select * into v_session from public.sessions
   where id = p_session_id and user_id = auth.uid() and not coalesce(is_closed, false);
  if not found then
    raise exception 'TRIP_NOT_ACTIVE';
  end if;
  v_today := public.fn_org_today(v_route.organization_id);

  select id, status into v_run_id, v_status from public.route_runs
   where route_id = p_route_id and run_date = v_today;
  if v_status = 'completed' then
    raise exception 'ROUTE_ALREADY_COMPLETED';
  end if;
  if v_run_id is not null then
    -- Resumed (app restarted, new trip): keep the run, point it at this trip.
    update public.route_runs
       set session_id = p_session_id, vehicle_id = coalesce(v_session.vehicle_id, vehicle_id), driver_id = auth.uid()
     where id = v_run_id;
    return v_run_id;
  end if;

  if exists (
    select 1 from public.route_runs
     where driver_id = auth.uid() and status = 'in_progress' and run_date = v_today
  ) then
    raise exception 'ANOTHER_ROUTE_IN_PROGRESS';
  end if;

  insert into public.route_runs (organization_id, route_id, run_date, driver_id, vehicle_id, session_id)
  values (v_route.organization_id, p_route_id, v_today, auth.uid(),
          coalesce(v_session.vehicle_id, v_route.assigned_vehicle_id), p_session_id)
  returning id into v_run_id;
  return v_run_id;
end $$;

create or replace function public.fn_my_open_run(p_run_id uuid)
returns public.route_runs language plpgsql stable security definer set search_path = public as $$
declare v_run public.route_runs%rowtype;
begin
  select * into v_run from public.route_runs where id = p_run_id;
  if not found or v_run.driver_id is distinct from auth.uid() then
    raise exception 'ROUTE_NOT_ASSIGNED';
  end if;
  if v_run.status <> 'in_progress' then
    raise exception 'ROUTE_ALREADY_COMPLETED';
  end if;
  return v_run;
end $$;

create or replace function public.mark_stop_arrived(p_run_id uuid, p_stop_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_run public.route_runs%rowtype := public.fn_my_open_run(p_run_id);
begin
  if not exists (select 1 from public.route_stops where id = p_stop_id and route_id = v_run.route_id) then
    raise exception 'Stop is not on this route';
  end if;
  insert into public.route_stop_events (organization_id, run_id, stop_id, method)
  values (v_run.organization_id, p_run_id, p_stop_id, 'manual')
  on conflict (run_id, stop_id) do nothing;
end $$;

create or replace function public.record_ridership(p_run_id uuid, p_stop_id uuid, p_student_id uuid,
                                                   p_action text, p_done boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_run public.route_runs%rowtype := public.fn_my_open_run(p_run_id);
begin
  if p_action not in ('board', 'alight') then raise exception 'Invalid action'; end if;
  if not exists (
    select 1 from public.student_stop_assignments
     where student_id = p_student_id and route_id = v_run.route_id and stop_id = p_stop_id and action = p_action
  ) then
    raise exception 'Student is not assigned to this stop';
  end if;
  if p_done then
    insert into public.ridership_events (organization_id, run_id, stop_id, student_id, action)
    values (v_run.organization_id, p_run_id, p_stop_id, p_student_id, p_action)
    on conflict (run_id, student_id, action) do nothing;
  else
    delete from public.ridership_events
     where run_id = p_run_id and student_id = p_student_id and action = p_action;
  end if;
end $$;

-- Finishing requires the "no child left on board" check; the place where it
-- was done is kept with the run.
create or replace function public.complete_route_run(p_run_id uuid, p_child_check boolean,
                                                     p_latitude double precision, p_longitude double precision)
returns void language plpgsql security definer set search_path = public as $$
declare v_run public.route_runs%rowtype := public.fn_my_open_run(p_run_id);
begin
  if not coalesce(p_child_check, false) then
    raise exception 'CHILD_CHECK_REQUIRED';
  end if;
  update public.route_stop_events set departed_at = coalesce(departed_at, now())
   where run_id = p_run_id;
  update public.route_runs
     set status = 'completed', completed_at = now(), child_check_at = now(),
         child_check_latitude = p_latitude, child_check_longitude = p_longitude
   where id = p_run_id;
end $$;

-- 10. Automatic arrival from the bus's live location ---------------------------
create or replace function public.fn_route_run_track_stops()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_run record;
  v_stop record;
begin
  if new.last_latitude is null or new.last_longitude is null then
    return new;
  end if;
  for v_run in
    select id, organization_id, route_id from public.route_runs
     where vehicle_id = new.id and status = 'in_progress'
  loop
    -- Left a stop it had arrived at.
    update public.route_stop_events e
       set departed_at = now()
      from public.route_stops s
     where e.run_id = v_run.id and e.stop_id = s.id and e.departed_at is null
       and public.fn_meters_between(s.latitude, s.longitude, new.last_latitude, new.last_longitude) > s.radius_meters * 1.5;
    -- Entered a stop not yet visited.
    for v_stop in
      select s.id from public.route_stops s
       where s.route_id = v_run.route_id
         and public.fn_meters_between(s.latitude, s.longitude, new.last_latitude, new.last_longitude) <= s.radius_meters
         and not exists (select 1 from public.route_stop_events e where e.run_id = v_run.id and e.stop_id = s.id)
    loop
      insert into public.route_stop_events (organization_id, run_id, stop_id, method)
      values (v_run.organization_id, v_run.id, v_stop.id, 'auto')
      on conflict (run_id, stop_id) do nothing;
    end loop;
  end loop;
  return new;
end $$;

drop trigger if exists trg_vehicles_route_run_stops on public.vehicles;
create trigger trg_vehicles_route_run_stops
  after update of last_latitude, last_longitude on public.vehicles
  for each row
  when (new.last_latitude is distinct from old.last_latitude or new.last_longitude is distinct from old.last_longitude)
  execute function public.fn_route_run_track_stops();

-- 11. Grants -------------------------------------------------------------------
revoke execute on function public.my_school_routes_today(uuid) from public, anon;
revoke execute on function public.start_route_run(uuid, uuid) from public, anon;
revoke execute on function public.fn_my_open_run(uuid) from public, anon;
revoke execute on function public.mark_stop_arrived(uuid, uuid) from public, anon;
revoke execute on function public.record_ridership(uuid, uuid, uuid, text, boolean) from public, anon;
revoke execute on function public.complete_route_run(uuid, boolean, double precision, double precision) from public, anon;
revoke execute on function public.fn_route_run_track_stops() from public, anon, authenticated;
grant execute on function public.my_school_routes_today(uuid) to authenticated;
grant execute on function public.start_route_run(uuid, uuid) to authenticated;
grant execute on function public.mark_stop_arrived(uuid, uuid) to authenticated;
grant execute on function public.record_ridership(uuid, uuid, uuid, text, boolean) to authenticated;
grant execute on function public.complete_route_run(uuid, boolean, double precision, double precision) to authenticated;

-- Live dashboard: runs and stop arrivals stream to the admin's map.
alter publication supabase_realtime add table public.route_runs, public.route_stop_events;
