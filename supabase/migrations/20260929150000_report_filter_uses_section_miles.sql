-- The zero-mile report filter (discard_zero_mile_trips) looked only at
-- sessions.total_miles; three early trips (2026-09-09..16, from before the
-- app saved the session total) have 0 there but real miles in their
-- sections, and were hidden. Same test as the discard trigger now:
-- a trip is shown if the session OR any of its sections has miles.
do $mig$
declare
  v_def text := pg_get_functiondef('public.generate_report_access_code(date,date,uuid,jsonb,uuid)'::regprocedure);
  v_new text;
begin
  v_new := replace(v_def,
    'and coalesce(s.total_miles, 0) >= 0.05',
    'and (coalesce(s.total_miles, 0) >= 0.05
           or exists (select 1 from public.session_sections x
                      where x.session_id = s.id and x.total_miles >= 0.05))');
  if v_new = v_def then
    raise exception 'pattern not found, function unchanged';
  end if;
  execute v_new;
end
$mig$;
