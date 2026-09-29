-- REAL BUG (found live 2026-09-29): trips left open when the app died or
-- was reinstalled mid-trip stay "open" forever. Four such orphans (Sienna,
-- Sep 16-26, 0 mi) made tr_vehicles_block_switch_during_session refuse
-- every vehicle change ("can't change vehicle while a trip is in
-- progress") with nothing being tracked, and after a fresh install the app
-- recovered the newest orphan from the DB as if it were a live trip.
--
-- A trip with no activity (no GPS breadcrumb, no section/session update)
-- for 12 hours is abandoned: close it the same way the app would, with the
-- miles its sections already hold. Long real shifts keep producing
-- breadcrumbs, so they are never touched. A closed trip with no miles is
-- then discarded by trg_discard_zero_mile_trip (the zero-mile rule).

create or replace function public.close_abandoned_trips(p_idle interval default interval '12 hours')
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_closed integer := 0;
begin
  for r in
    select s.id,
           greatest(
             s.start_time,
             s.updated_at,
             (select max(b.recorded_at) from public.session_gps_breadcrumbs b where b.session_id = s.id),
             (select max(x.updated_at) from public.session_sections x where x.session_id = s.id)
           ) as last_activity
    from public.sessions s
    where not coalesce(s.is_closed, false)
  loop
    continue when r.last_activity is null or r.last_activity > now() - p_idle;

    update public.session_sections
       set section_status = 'closed',
           end_time = coalesce(end_time, r.last_activity)
     where session_id = r.id
       and section_status in ('active', 'paused');

    update public.sessions s
       set is_closed = true,
           session_status = 'closed',
           end_time = coalesce(s.end_time, r.last_activity),
           total_miles = greatest(
             coalesce(s.total_miles, 0),
             coalesce((select sum(x.total_miles) from public.session_sections x where x.session_id = s.id), 0)
           )
     where s.id = r.id;

    v_closed := v_closed + 1;
  end loop;
  return v_closed;
end;
$$;

revoke execute on function public.close_abandoned_trips(interval) from public, anon, authenticated;

select cron.schedule(
  'close-abandoned-trips',
  '17 * * * *',
  $$select public.close_abandoned_trips()$$
);

-- The four orphans that exist today.
select public.close_abandoned_trips();
