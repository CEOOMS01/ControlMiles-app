-- Bus monitor role (2026-10-09, owner's request; plan section 8). A monitor
-- is a fleet member created ONLY from the web dashboard (Team -> invite by
-- email) and ONLY in School transportation fleets. In the app a monitor sees
-- the school routes they're on today and keeps the student list of the run
-- the driver started; they never start trips, track miles or finish routes
-- (the driver confirms the end-of-route child check). Monitors without the
-- app stay "by name" (routes.monitor_name).

-- 1. Role ----------------------------------------------------------------------
alter table public.organization_members drop constraint if exists organization_members_member_role_check;
alter table public.organization_members add constraint organization_members_member_role_check
  check (member_role in ('owner', 'admin', 'operator', 'driver', 'monitor'));
alter table public.driver_invites drop constraint if exists driver_invites_intended_role_check;
alter table public.driver_invites add constraint driver_invites_intended_role_check
  check (intended_role in ('driver', 'operator', 'admin', 'monitor'));

create or replace function public.create_driver_invite(p_org_id uuid, p_email text, p_first_name text, p_last_name text,
                                                       p_intended_role text default 'driver')
returns text language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare
  v_email text := lower(trim(p_email));
  v_first_name text := trim(p_first_name);
  v_last_name text := trim(p_last_name);
  v_target_id uuid;
  v_target_account_type text;
  v_existing_membership uuid;
  v_token text;
  v_hash text;
  v_allowed boolean;
  v_slot_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_intended_role not in ('driver', 'operator', 'admin', 'monitor') then
    raise exception 'Invalid role: %', p_intended_role;
  end if;

  if p_intended_role = 'monitor' and not exists (
    select 1 from public.organizations where id = p_org_id and industry_template = 'school_transport'
  ) then
    raise exception 'Bus monitors are only available for School transportation fleets';
  end if;

  if p_intended_role = 'admin' and not public.is_org_owner(p_org_id) then
    raise exception 'Only the organization owner can invite someone directly as an admin';
  end if;

  if p_intended_role = 'operator' and not public.is_org_admin_or_owner(p_org_id) then
    raise exception 'Only an org admin or owner can invite someone directly as an operator';
  end if;

  if not public.is_org_operator_or_above(p_org_id) then
    raise exception 'Only an org admin, owner, or operator can invite drivers';
  end if;

  if public.fn_org_effective_tier(p_org_id) = 'none' then
    raise exception 'FLEET_SUBSCRIPTION_REQUIRED';
  end if;

  select public.check_rate_limit('create_driver_invite', auth.uid()::text, 20, 3600) into v_allowed;
  if not v_allowed then
    raise exception 'Too many invites created recently. Try again later.';
  end if;

  if v_email = '' or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'A valid email is required';
  end if;

  if v_first_name = '' or v_last_name = '' then
    raise exception 'First and last name are required';
  end if;

  select id, account_type into v_target_id, v_target_account_type
  from public.profiles
  where lower(email) = v_email
  limit 1;

  if v_target_id is not null then
    if v_target_account_type = 'fleet_admin' then
      raise exception 'This person already owns their own fleet and cannot be invited as a driver';
    end if;

    select id into v_existing_membership
    from public.organization_members
    where organization_id = p_org_id and user_id = v_target_id and is_active = true;

    if v_existing_membership is not null then
      raise exception 'This person is already a member of this organization';
    end if;
  end if;

  update public.driver_invites
  set status = 'expired'
  where organization_id = p_org_id and lower(email) = v_email and status = 'pending';

  insert into public.fleet_driver_slots (organization_id, first_name, last_name, claim_code_hash, created_by)
  values (p_org_id, v_first_name, v_last_name, encode(gen_random_bytes(24), 'hex'), auth.uid())
  returning id into v_slot_id;

  v_token := encode(gen_random_bytes(24), 'hex');
  v_hash := encode(digest(v_token, 'sha256'), 'hex');

  insert into public.driver_invites (organization_id, email, token_hash, created_by, first_name, last_name, slot_id, intended_role)
  values (p_org_id, v_email, v_hash, auth.uid(), v_first_name, v_last_name, v_slot_id, p_intended_role);

  return v_token;
end;
$function$;

-- 2. Monitor on the route (member with the app) ----------------------------------
alter table public.routes
  add column if not exists monitor_id uuid references public.profiles(id) on delete set null;
alter table public.route_crew_overrides
  add column if not exists monitor_id uuid references public.profiles(id) on delete set null;
alter table public.route_runs
  add column if not exists monitor_id uuid references public.profiles(id) on delete set null;

-- A route's monitor must be an active monitor of the same fleet.
create or replace function public.fn_check_route_monitor()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.monitor_id is not null and not exists (
    select 1 from public.organization_members
     where organization_id = new.organization_id and user_id = new.monitor_id
       and member_role = 'monitor' and is_active
  ) then
    raise exception 'The bus monitor must be an active monitor of this fleet';
  end if;
  return new;
end $$;
revoke execute on function public.fn_check_route_monitor() from public, anon, authenticated;
drop trigger if exists trg_routes_check_monitor on public.routes;
create trigger trg_routes_check_monitor before insert or update of monitor_id on public.routes
  for each row execute function public.fn_check_route_monitor();
drop trigger if exists trg_route_crew_overrides_check_monitor on public.route_crew_overrides;
create trigger trg_route_crew_overrides_check_monitor before insert or update of monitor_id on public.route_crew_overrides
  for each row execute function public.fn_check_route_monitor();

-- 3. Effective crew now carries the monitor member ------------------------------
drop function if exists public.fn_route_crew(uuid, date);
create function public.fn_route_crew(p_route_id uuid, p_date date)
returns table (driver_id uuid, vehicle_id uuid, monitor_id uuid, monitor_name text, is_substitute boolean)
language sql stable security definer set search_path = public as $$
  -- A substitute monitor (member or name) replaces the regular one entirely.
  select coalesce(o.driver_id, r.assigned_driver_id),
         coalesce(o.vehicle_id, r.assigned_vehicle_id),
         case when o.monitor_id is not null or o.monitor_name is not null then o.monitor_id else r.monitor_id end,
         case when o.monitor_id is not null or o.monitor_name is not null then o.monitor_name else r.monitor_name end,
         o.id is not null
    from public.routes r
    left join public.route_crew_overrides o on o.route_id = r.id and o.service_date = p_date
   where r.id = p_route_id;
$$;
revoke execute on function public.fn_route_crew(uuid, date) from public, anon, authenticated;

-- 4. Driver payload: also the routes I'm the monitor of, with my_role --------------
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
          'my_role', case when crew.driver_id = auth.uid() then 'driver' else 'monitor' end,
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
                  'departed_at', (select e.departed_at from public.route_stop_events e
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
       and (crew.driver_id = auth.uid() or crew.monitor_id = auth.uid())
       and r.route_type in ('school_am', 'school_pm')
       and r.status = 'active'
       and v_dow = any (r.service_days)
    ) q
  ), '[]'::jsonb);
end $$;

-- 5. Run access for the list: the run's driver OR today's monitor of the route ---
create or replace function public.fn_my_crew_run(p_run_id uuid)
returns public.route_runs language plpgsql stable security definer set search_path = public as $$
declare v_run public.route_runs%rowtype;
begin
  select * into v_run from public.route_runs where id = p_run_id;
  if not found or (
    v_run.driver_id is distinct from auth.uid()
    and not exists (select 1 from public.fn_route_crew(v_run.route_id, v_run.run_date) c where c.monitor_id = auth.uid())
  ) then
    raise exception 'ROUTE_NOT_ASSIGNED';
  end if;
  if v_run.status <> 'in_progress' then
    raise exception 'ROUTE_ALREADY_COMPLETED';
  end if;
  return v_run;
end $$;
revoke execute on function public.fn_my_crew_run(uuid) from public, anon, authenticated;

create or replace function public.record_ridership(p_run_id uuid, p_stop_id uuid, p_student_id uuid,
                                                   p_action text, p_done boolean,
                                                   p_reason text default null, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_run public.route_runs%rowtype := public.fn_my_crew_run(p_run_id);
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

-- 6. The run keeps the monitor it ran with ----------------------------------------
create or replace function public.fn_route_run_set_monitor()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  select c.monitor_id, c.monitor_name into new.monitor_id, new.monitor_name
    from public.fn_route_crew(new.route_id, new.run_date) c;
  return new;
end $$;
revoke execute on function public.fn_route_run_set_monitor() from public, anon, authenticated;
drop trigger if exists trg_route_runs_set_monitor on public.route_runs;
create trigger trg_route_runs_set_monitor before insert on public.route_runs
  for each row execute function public.fn_route_run_set_monitor();
