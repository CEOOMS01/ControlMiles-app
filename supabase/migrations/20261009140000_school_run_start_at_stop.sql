-- Found by the 5-stop test (2026-10-09): the PM run starts with the bus
-- already parked at the school. Arrival was only marked when the bus's
-- location CHANGED, so the school stop stayed "not reached", the students
-- who didn't come out stayed "expected" instead of red, and the route could
-- be finished without resolving them.
--   1. start_route_run marks arrival at any stop the bus is already at
--      (location reported in the last 10 minutes).
--   2. complete_route_run treats a PM rider still "expected" as unresolved
--      (finishing would turn them red anyway).

create or replace function public.fn_route_run_mark_current_stops(p_run_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_run public.route_runs%rowtype;
  v_lat double precision;
  v_lng double precision;
begin
  select * into v_run from public.route_runs where id = p_run_id;
  select last_latitude, last_longitude into v_lat, v_lng from public.vehicles
   where id = v_run.vehicle_id and last_location_at > now() - interval '10 minutes';
  if v_lat is null or v_lng is null then return; end if;
  insert into public.route_stop_events (organization_id, run_id, stop_id, method)
  select v_run.organization_id, p_run_id, s.id, 'auto'
    from public.route_stops s
   where s.route_id = v_run.route_id
     and public.fn_meters_between(s.latitude, s.longitude, v_lat, v_lng) <= s.radius_meters
  on conflict (run_id, stop_id) do nothing;
end $$;
revoke execute on function public.fn_route_run_mark_current_stops(uuid) from public, anon, authenticated;

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
    perform public.fn_route_run_mark_current_stops(v_run_id);
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
  -- The bus may already be at the first stop (PM: parked at the school).
  perform public.fn_route_run_mark_current_stops(v_run_id);
  return v_run_id;
end $$;

create or replace function public.complete_route_run(p_run_id uuid, p_child_check boolean,
                                                     p_latitude double precision, p_longitude double precision)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_run public.route_runs%rowtype := public.fn_my_open_run(p_run_id);
  v_on_board int;
  v_unresolved int;
begin
  if not coalesce(p_child_check, false) then
    raise exception 'CHILD_CHECK_REQUIRED';
  end if;
  select count(*) into v_on_board
    from public.ridership_events b
   where b.run_id = p_run_id and b.action = 'board'
     and not exists (select 1 from public.ridership_events x
                      where x.run_id = p_run_id and x.student_id = b.student_id and x.action = 'alight');
  if v_on_board > 0 then
    raise exception 'STUDENTS_STILL_ON_BOARD';
  end if;
  -- red now, or "expected" (rode this morning, never boarded or resolved):
  -- finishing would leave them red.
  select count(*) into v_unresolved
    from public.student_stop_assignments a
   where a.route_id = v_run.route_id and a.action = 'board'
     and public.fn_rider_status(v_run.route_id, p_run_id, a.stop_id, a.student_id, 'board') in ('red', 'expected');
  if v_unresolved > 0 then
    raise exception 'UNRESOLVED_STUDENTS';
  end if;
  update public.route_stop_events set departed_at = coalesce(departed_at, now())
   where run_id = p_run_id;
  update public.route_runs
     set status = 'completed', completed_at = now(), child_check_at = now(),
         child_check_latitude = p_latitude, child_check_longitude = p_longitude
   where id = p_run_id;
end $$;
