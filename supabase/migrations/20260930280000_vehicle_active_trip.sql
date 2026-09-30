-- Live map status (explicit user question, 2026-09-30: "the last point of
-- driver test still shows on the map -- is that normal? does tracking
-- continue after the shift ended?"). Keeping the last known position is
-- normal (Samsara/Motive show parked vehicles where they were left), and
-- tracking does stop at trip end -- but the map couldn't tell "on a trip"
-- from "parked", only "updated in the last 15 min". vehicles.active_session_id
-- is kept by triggers on sessions, so it rides the existing Realtime
-- channel on vehicles and the map shows On trip / Parked / No signal.

alter table public.vehicles
  add column active_session_id uuid references public.sessions(id) on delete set null;

CREATE OR REPLACE FUNCTION public.fn_vehicle_active_trip()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if tg_op = 'INSERT' then
    if new.vehicle_id is not null and not coalesce(new.is_closed, false) then
      update public.vehicles set active_session_id = new.id where id = new.vehicle_id;
    end if;
  elsif tg_op = 'UPDATE' then
    if coalesce(new.is_closed, false) and not coalesce(old.is_closed, false) then
      update public.vehicles set active_session_id = null
      where id = new.vehicle_id and active_session_id = new.id;
    end if;
  elsif tg_op = 'DELETE' then
    update public.vehicles set active_session_id = null
    where id = old.vehicle_id and active_session_id = old.id;
  end if;
  return null;
exception when others then
  -- Never block a trip over the map status.
  raise warning 'vehicle active trip update failed: %', sqlerrm;
  return null;
end;
$function$;

create trigger sessions_vehicle_active_trip
after insert or update of is_closed or delete on public.sessions
for each row execute function public.fn_vehicle_active_trip();

-- Backfill: vehicles with a trip open right now.
update public.vehicles v set active_session_id = s.id
from (
  select distinct on (vehicle_id) id, vehicle_id
  from public.sessions
  where vehicle_id is not null and not coalesce(is_closed, false)
  order by vehicle_id, start_time desc
) s
where v.id = s.vehicle_id;
