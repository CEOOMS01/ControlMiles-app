-- School transportation crew (2026-10-09, plan section 8):
--   1. Substitute for one day: the manager swaps the driver, the bus and/or
--      the monitor of a route for a single date without touching the regular
--      assignment ("the route must start on time no matter who is late").
--      The substitute driver sees and runs the route in the app with no app
--      update: my_school_routes_today / start_route_run use the effective
--      crew.
--   2. Who marked each student: ridership_events.recorded_by.
--   3. The run keeps the crew it ran with (route_runs.monitor_name), for the
--      district report.

create table if not exists public.route_crew_overrides (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  route_id uuid not null references public.routes(id) on delete cascade,
  service_date date not null,
  driver_id uuid references public.profiles(id) on delete set null,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  monitor_name text check (monitor_name is null or length(monitor_name) <= 80),
  reason text check (reason is null or length(reason) <= 200),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (route_id, service_date)
);
create index if not exists route_crew_overrides_org_date on public.route_crew_overrides (organization_id, service_date);
alter table public.route_crew_overrides enable row level security;
drop policy if exists route_crew_overrides_read on public.route_crew_overrides;
create policy route_crew_overrides_read on public.route_crew_overrides
  for select to authenticated using (public.is_org_operator_or_above(organization_id));
drop policy if exists route_crew_overrides_write_admin on public.route_crew_overrides;
create policy route_crew_overrides_write_admin on public.route_crew_overrides
  for all to authenticated
  using (public.is_org_operator_or_above(organization_id))
  with check (
    public.is_org_operator_or_above(organization_id)
    and exists (select 1 from public.routes r where r.id = route_id and r.organization_id = route_crew_overrides.organization_id)
    and (vehicle_id is null or exists (select 1 from public.vehicles v where v.id = vehicle_id and v.organization_id = route_crew_overrides.organization_id))
    and (driver_id is null or exists (select 1 from public.organization_members m
                                       where m.user_id = driver_id and m.organization_id = route_crew_overrides.organization_id and m.is_active))
  );

alter table public.ridership_events
  add column if not exists recorded_by uuid references public.profiles(id) on delete set null;
alter table public.route_runs
  add column if not exists monitor_name text check (monitor_name is null or length(monitor_name) <= 80);

-- Effective crew of a route on a date: the day's substitute wins.
create or replace function public.fn_route_crew(p_route_id uuid, p_date date)
returns table (driver_id uuid, vehicle_id uuid, monitor_name text, is_substitute boolean)
language sql stable security definer set search_path = public as $$
  select coalesce(o.driver_id, r.assigned_driver_id),
         coalesce(o.vehicle_id, r.assigned_vehicle_id),
         coalesce(o.monitor_name, r.monitor_name),
         o.id is not null
    from public.routes r
    left join public.route_crew_overrides o on o.route_id = r.id and o.service_date = p_date
   where r.id = p_route_id;
$$;
revoke execute on function public.fn_route_crew(uuid, date) from public, anon, authenticated;

create or replace function public.my_school_routes_today(p_organization_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_today date := public.fn_org_today(p_organization_id);
  v_dow smallint := extract(isodow from v_today)::smallint;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  return coalesce((
    select jsonb_agg(route_json order by start_time nulls last, route_name)
    from (
      select r.scheduled_start_time as start_time, r.name as route_name,
        (select jsonb_build_object(
          'id', r.id, 'name', r.name, 'route_type', r.route_type,
          'scheduled_start_time', r.scheduled_start_time,
          'vehicle_id', crew.vehicle_id,
          'school', (select ss.name from public.school_sites ss where ss.id = r.school_site_id),
          'run', (select jsonb_build_object('id', rr.id, 'status', rr.status, 'started_at', rr.started_at,
                                            'completed_at', rr.completed_at)
                    from public.route_runs rr where rr.id = run.id),
          'stops', coalesce((
            select jsonb_agg(stop_json order by seq)
            from (
              select s.seq,
                jsonb_build_object(
                  'id', s.id, 'seq', s.seq, 'name', s.name, 'address', s.address,
                  'latitude', s.latitude, 'longitude', s.longitude, 'radius_meters', s.radius_meters,
                  'scheduled_time', s.scheduled_time, 'stop_kind', s.stop_kind,
                  'arrived_at', (select e.arrived_at from public.route_stop_events e
                                  where e.stop_id = s.id and e.run_id = run.id),
                  'students', coalesce((
                    select jsonb_agg(jsonb_build_object(
                      'id', st.id, 'name', st.first_name || coalesce(' ' || st.last_initial || '.', ''),
                      'grade', st.grade, 'action', a.action,
                      'done', exists (select 1 from public.ridership_events re
                                       where re.run_id = run.id and re.student_id = st.id and re.action = a.action),
                      'status', public.fn_rider_status(r.id, run.id, s.id, st.id, a.action),
                      'release_reason', (select re.reason from public.ridership_events re
                                          where re.run_id = run.id and re.student_id = st.id and re.action = 'released'),
                      'release_note', (select re.note from public.ridership_events re
                                        where re.run_id = run.id and re.student_id = st.id and re.action = 'released'))
                      order by st.first_name)
                      from public.student_stop_assignments a
                      join public.students st on st.id = a.student_id and st.is_active
                     where a.stop_id = s.id), '[]'::jsonb)) as stop_json
              from public.route_stops s where s.route_id = r.id
            ) stops_q), '[]'::jsonb))) as route_json
      from public.routes r
      cross join lateral public.fn_route_crew(r.id, v_today) crew
      left join lateral (select rr.id from public.route_runs rr
                          where rr.route_id = r.id and rr.run_date = v_today) run on true
     where r.organization_id = p_organization_id
       and crew.driver_id = auth.uid()
       and r.route_type in ('school_am', 'school_pm')
       and r.status = 'active'
       and v_dow = any (r.service_days)
    ) q
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
  v_crew record;
begin
  select * into v_route from public.routes where id = p_route_id;
  if not found then
    raise exception 'ROUTE_NOT_ASSIGNED';
  end if;
  v_today := public.fn_org_today(v_route.organization_id);
  select * into v_crew from public.fn_route_crew(p_route_id, v_today);
  if v_crew.driver_id is distinct from auth.uid() then
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

  select id, status into v_run_id, v_status from public.route_runs
   where route_id = p_route_id and run_date = v_today;
  if v_status = 'completed' then
    raise exception 'ROUTE_ALREADY_COMPLETED';
  end if;
  if v_run_id is not null then
    -- Resumed (app restarted, new trip, or a substitute took over).
    update public.route_runs
       set session_id = p_session_id, vehicle_id = coalesce(v_session.vehicle_id, vehicle_id), driver_id = auth.uid(),
           monitor_name = v_crew.monitor_name
     where id = v_run_id;
    perform public.fn_route_run_mark_current_stops(v_run_id);
    return v_run_id;
  end if;

  if exists (
    select 1 from public.route_runs
     where driver_id = auth.uid() and status = 'in_progress' and run_date = v_today
  ) then
    raise exception 'ANOTHER_ROUTE_IN_PROGRESS';
  end if;

  insert into public.route_runs (organization_id, route_id, run_date, driver_id, vehicle_id, session_id, monitor_name)
  values (v_route.organization_id, p_route_id, v_today, auth.uid(),
          coalesce(v_session.vehicle_id, v_crew.vehicle_id), p_session_id, v_crew.monitor_name)
  returning id into v_run_id;
  perform public.fn_route_run_mark_current_stops(v_run_id);
  return v_run_id;
end $$;

create or replace function public.record_ridership(p_run_id uuid, p_stop_id uuid, p_student_id uuid,
                                                   p_action text, p_done boolean,
                                                   p_reason text default null, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_run public.route_runs%rowtype := public.fn_my_open_run(p_run_id);
  v_assign_action text := case when p_action = 'released' then 'board' else p_action end;
begin
  if p_action not in ('board', 'alight', 'released') then raise exception 'Invalid action'; end if;
  if not exists (
    select 1 from public.student_stop_assignments
     where student_id = p_student_id and route_id = v_run.route_id and stop_id = p_stop_id and action = v_assign_action
  ) then
    raise exception 'Student is not assigned to this stop';
  end if;
  if p_done then
    if p_action = 'released' and p_reason is null then
      raise exception 'RELEASE_REASON_REQUIRED';
    end if;
    insert into public.ridership_events (organization_id, run_id, stop_id, student_id, action, reason, note, recorded_by)
    values (v_run.organization_id, p_run_id, p_stop_id, p_student_id, p_action,
            case when p_action = 'released' then p_reason end,
            case when p_action = 'released' then nullif(trim(p_note), '') end,
            auth.uid())
    on conflict (run_id, student_id, action)
      do update set reason = excluded.reason, note = excluded.note, at = now(), recorded_by = excluded.recorded_by;
    if p_action = 'board' then
      delete from public.ridership_events where run_id = p_run_id and student_id = p_student_id and action = 'released';
    elsif p_action = 'released' then
      delete from public.ridership_events where run_id = p_run_id and student_id = p_student_id and action = 'board';
    end if;
  else
    delete from public.ridership_events
     where run_id = p_run_id and student_id = p_student_id and action = p_action;
  end if;
end $$;
