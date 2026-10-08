-- School transportation (2026-10-09, owner's request):
--   1. Grace period: when the bus reaches a stop, students aren't decided
--      (red / yellow) right away -- they have 5 minutes to come out, or
--      until the bus leaves the stop. Boarding during that time just turns
--      them blue. Same for "not dropped off" at a drop-off stop.
--   2. Bus monitor (aide) per route, by name (monitors usually don't use the
--      app); shown on the web dashboard only.

alter table public.routes
  add column if not exists monitor_name text check (monitor_name is null or length(monitor_name) <= 80);

-- A stop is "due" (decisions can be made) once the bus left it, 5 minutes
-- after arriving, or when the run is completed.
create or replace function public.fn_stop_due(p_run_id uuid, p_stop_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_run_id is not null and (
    exists (select 1 from public.route_runs where id = p_run_id and status = 'completed')
    or exists (select 1 from public.route_stop_events
                where run_id = p_run_id and stop_id = p_stop_id
                  and (departed_at is not null or arrived_at <= now() - interval '5 minutes')));
$$;
revoke execute on function public.fn_stop_due(uuid, uuid) from public, anon, authenticated;

create or replace function public.fn_rider_status(p_route_id uuid, p_run_id uuid, p_stop_id uuid,
                                                  p_student uuid, p_action text)
returns text language plpgsql stable security definer set search_path = public as $$
declare
  v_route public.routes%rowtype;
  v_date date;
  v_due boolean;
  v_done boolean;
  v_boarded boolean;
  v_released boolean;
begin
  select * into v_route from public.routes where id = p_route_id;
  v_date := coalesce((select run_date from public.route_runs where id = p_run_id),
                     public.fn_org_today(v_route.organization_id));
  v_due := public.fn_stop_due(p_run_id, p_stop_id);
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
      return case when v_due then 'red' else 'expected' end;
    end if;
    return case when v_due then 'yellow' else 'pending' end;
  end if;

  if v_released then return 'gray'; end if;
  if not v_boarded then
    if v_route.route_type = 'school_pm' then
      return case when not public.fn_rode_am_today(v_route.organization_id, p_student, v_date)
                  then 'yellow' else 'pending' end;
    end if;
    return case when exists (
                  select 1 from public.student_stop_assignments a
                   where a.route_id = p_route_id and a.student_id = p_student and a.action = 'board'
                     and public.fn_stop_due(p_run_id, a.stop_id))
                then 'yellow' else 'pending' end;
  end if;
  return case when v_due then 'red' else 'on_board' end;
end $$;
revoke execute on function public.fn_rider_status(uuid, uuid, uuid, uuid, text) from public, anon, authenticated;
