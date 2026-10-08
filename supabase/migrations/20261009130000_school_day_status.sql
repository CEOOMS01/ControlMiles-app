-- School day status (2026-10-09, user rule + 4 approved adjustments). Each
-- student is followed through the whole day, AM and PM together:
--   blue   = on track (picked up / dropped off as planned)
--   red    = alert: rode to school this morning but hasn't come out for the
--            PM bus, OR boarded and the bus passed their stop without
--            dropping them off (could still be on the bus)
--   yellow = didn't ride this morning -> not expected in the afternoon; a
--            stop whose riders are all yellow can be skipped. Not a block:
--            the driver can still board them (a parent may have dropped
--            them at school).
--   gray   = red resolved with a reason (picked up by a parent/guardian,
--            early dismissal for an appointment, after-school activity,
--            other + note); counts as attendance.
-- The route can't be finished with a student still on board or an
-- unresolved red.

-- 1. "released" events with a reason ------------------------------------------
alter table public.ridership_events drop constraint if exists ridership_events_action_check;
alter table public.ridership_events add constraint ridership_events_action_check
  check (action in ('board', 'alight', 'released'));
alter table public.ridership_events
  add column if not exists reason text
    check (reason is null or reason in ('parent_pickup', 'early_dismissal', 'activity', 'other')),
  add column if not exists note text check (note is null or length(note) <= 300);

-- 2. Rider status -------------------------------------------------------------
-- Rode the AM bus today (any school_am run of the fleet).
create or replace function public.fn_rode_am_today(p_org uuid, p_student uuid, p_date date)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.ridership_events e
      join public.route_runs rr on rr.id = e.run_id
      join public.routes r on r.id = rr.route_id
     where rr.organization_id = p_org and rr.run_date = p_date and r.route_type = 'school_am'
       and e.student_id = p_student and e.action = 'board');
$$;

-- Color of one assignment (student + action at a stop) in today's run of a route.
create or replace function public.fn_rider_status(p_route_id uuid, p_run_id uuid, p_stop_id uuid,
                                                  p_student uuid, p_action text)
returns text language plpgsql stable security definer set search_path = public as $$
declare
  v_route public.routes%rowtype;
  v_date date;
  v_reached boolean;
  v_done boolean;
  v_boarded boolean;
  v_released boolean;
  v_completed boolean;
begin
  select * into v_route from public.routes where id = p_route_id;
  v_date := coalesce((select run_date from public.route_runs where id = p_run_id),
                     public.fn_org_today(v_route.organization_id));
  v_reached := p_run_id is not null and exists (
    select 1 from public.route_stop_events where run_id = p_run_id and stop_id = p_stop_id);
  v_completed := coalesce((select status = 'completed' from public.route_runs where id = p_run_id), false);
  v_done := p_run_id is not null and exists (
    select 1 from public.ridership_events where run_id = p_run_id and student_id = p_student and action = p_action);
  v_boarded := p_run_id is not null and exists (
    select 1 from public.ridership_events where run_id = p_run_id and student_id = p_student and action = 'board');
  v_released := p_run_id is not null and exists (
    select 1 from public.ridership_events where run_id = p_run_id and student_id = p_student and action = 'released');

  if v_done then return 'blue'; end if;

  if p_action = 'board' then
    if v_released then return 'gray'; end if;
    if v_route.route_type = 'school_pm' then
      if not public.fn_rode_am_today(v_route.organization_id, p_student, v_date) then
        return 'yellow';
      end if;
      return case when v_reached or v_completed then 'red' else 'expected' end;
    end if;
    -- AM: the bus reached the stop and they didn't get on -> absent today.
    return case when v_reached or v_completed then 'yellow' else 'pending' end;
  end if;

  -- alight
  if v_released then return 'gray'; end if;
  if not v_boarded then
    if v_route.route_type = 'school_pm' then
      return case when not public.fn_rode_am_today(v_route.organization_id, p_student, v_date)
                  then 'yellow' else 'pending' end;
    end if;
    -- AM: absent once the bus has passed their pick-up stop.
    return case when v_completed or exists (
                  select 1 from public.student_stop_assignments a
                    join public.route_stop_events e on e.stop_id = a.stop_id and e.run_id = p_run_id
                   where a.route_id = p_route_id and a.student_id = p_student and a.action = 'board')
                then 'yellow' else 'pending' end;
  end if;
  return case when v_reached or v_completed then 'red' else 'on_board' end;
end $$;

-- 3. Driver payload: status per rider, release reason, stop "skip" ------------
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
          'vehicle_id', r.assigned_vehicle_id,
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
      left join lateral (select rr.id from public.route_runs rr
                          where rr.route_id = r.id and rr.run_date = v_today) run on true
     where r.organization_id = p_organization_id
       and r.assigned_driver_id = auth.uid()
       and r.route_type in ('school_am', 'school_pm')
       and r.status = 'active'
       and v_dow = any (r.service_days)
    ) q
  ), '[]'::jsonb);
end $$;

-- 4. Record a rider: board / alight / released (with a reason) ----------------
drop function if exists public.record_ridership(uuid, uuid, uuid, text, boolean);
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
    insert into public.ridership_events (organization_id, run_id, stop_id, student_id, action, reason, note)
    values (v_run.organization_id, p_run_id, p_stop_id, p_student_id, p_action,
            case when p_action = 'released' then p_reason end,
            case when p_action = 'released' then nullif(trim(p_note), '') end)
    on conflict (run_id, student_id, action) do update set reason = excluded.reason, note = excluded.note, at = now();
    -- Boarding after all (found at school) clears an earlier release, and vice versa.
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
revoke execute on function public.record_ridership(uuid, uuid, uuid, text, boolean, text, text) from public, anon;
grant execute on function public.record_ridership(uuid, uuid, uuid, text, boolean, text, text) to authenticated;

-- 5. Finishing: no one left on board, no unresolved red ------------------------
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
  select count(*) into v_unresolved
    from public.student_stop_assignments a
   where a.route_id = v_run.route_id and a.action = 'board'
     and public.fn_rider_status(v_run.route_id, p_run_id, a.stop_id, a.student_id, 'board') = 'red';
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

revoke execute on function public.fn_rode_am_today(uuid, uuid, date) from public, anon, authenticated;
revoke execute on function public.fn_rider_status(uuid, uuid, uuid, uuid, text) from public, anon, authenticated;
