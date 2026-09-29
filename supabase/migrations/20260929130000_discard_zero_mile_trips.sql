-- NEW RULE (user, 2026-09-29): a trip with no tracked miles is not kept --
-- neither the trip nor its map. Reports stay clean, no 0.00 mi noise.
--
-- Enforced in the DB, not just the app, so it holds for every client
-- version already installed: the moment a trip is closed with < 0.05 mi
-- (what the app and the report show as "0.0"), it is deleted. ON DELETE
-- CASCADE removes its sections, GPS breadcrumbs (the map) and its own
-- per-trip audit chain (audit_events are chained per session, see
-- AuditService._getLastHash, so no other trip's chain is affected).
-- trip_incidents keep existing (session_id -> null). Late breadcrumbs for
-- a discarded trip get a 404 from ingest-gps-breadcrumb, already swallowed.

create or replace function public.fn_discard_zero_mile_trip()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.total_miles, 0) < 0.05
     and coalesce((select sum(ss.total_miles) from public.session_sections ss
                   where ss.session_id = new.id), 0) < 0.05 then
    delete from public.sessions where id = new.id;
  end if;
  return null;
end;
$$;

revoke execute on function public.fn_discard_zero_mile_trip() from public, anon, authenticated;

drop trigger if exists trg_discard_zero_mile_trip on public.sessions;
create trigger trg_discard_zero_mile_trip
  after update of is_closed on public.sessions
  for each row
  when (new.is_closed and not coalesce(old.is_closed, false))
  execute function public.fn_discard_zero_mile_trip();

-- Report portal: trips from before this rule with no miles are left in
-- the DB (nothing is deleted retroactively) but no longer shown -- every
-- sessions query in the report already carries the same vehicle filter,
-- so the miles filter is appended right after it.
do $mig$
declare
  v_def text := pg_get_functiondef('public.generate_report_access_code(date,date,uuid,jsonb,uuid)'::regprocedure);
  v_new text;
begin
  v_new := replace(v_def,
    'and (p_vehicle_id is null or s.vehicle_id = p_vehicle_id)',
    'and (p_vehicle_id is null or s.vehicle_id = p_vehicle_id)
      and coalesce(s.total_miles, 0) >= 0.05');
  if v_new = v_def then
    raise exception 'pattern not found, function unchanged';
  end if;
  execute v_new;
end
$mig$;
