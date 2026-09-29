-- REAL BUG (found live 2026-09-29): generate_report_access_code referenced
-- sessions.effective_duration_seconds, a column that never existed
-- ("effective duration" is an app-side getter,
-- TrackingSession.effectiveDurationSeconds). Every report code -- web
-- /portal/generate, admin roster "Generate report", and the app's
-- GenerateReportCodeScreen -- failed with 42703.
--
-- Same rule as the app: net total_duration_seconds when > 0, else the
-- start->end wall-clock span for legacy rows stuck at 0. Patches only that
-- one select-list item of the live definition and fails loudly if the
-- pattern is not there.
do $mig$
declare
  v_def text := pg_get_functiondef('public.generate_report_access_code(date,date,uuid,jsonb,uuid)'::regprocedure);
  v_new text;
begin
  v_new := replace(v_def,
    's.effective_duration_seconds, s.start_odometer_value',
    'case when s.total_duration_seconds > 0 then s.total_duration_seconds
                when s.start_time is not null and s.end_time is not null
                  then extract(epoch from (s.end_time - s.start_time))::int
           end as effective_duration_seconds, s.start_odometer_value');
  if v_new = v_def then
    raise exception 'pattern not found, function unchanged';
  end if;
  execute v_new;
end
$mig$;
