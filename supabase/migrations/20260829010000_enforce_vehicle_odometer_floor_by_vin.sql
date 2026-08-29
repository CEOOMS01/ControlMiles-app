-- Fraud-prevention: vehicles.vin already existed on this table but was never
-- wired into the Flutter app (confirmed via grep -- zero references). VIN is
-- optional (not every driver will enter one), so this check ONLY applies
-- when a VIN is provided AND it matches a VIN this same user already used on
-- another (possibly archived/deleted) vehicle row -- without a VIN there is
-- no reliable way to know two vehicle rows are "the same car", and a global
-- per-account floor would false-positive on a driver who legitimately owns
-- two real vehicles with different mileage (explicitly rejected by the
-- user). When a VIN match exists, the new odometer can never be entered
-- below the highest "expected current odometer" ControlMiles has on record
-- for that VIN: the matching vehicle's own recorded odometer PLUS whatever
-- real mileage the app already tracked for it (sessions.total_miles by
-- vehicle_id) -- covers both re-adding a deleted vehicle with a rolled-back
-- odometer, and re-adding it without accounting for miles already tracked
-- before it was deleted.
create or replace function public.fn_enforce_vehicle_odometer_floor()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_floor numeric;
begin
  if new.owner_user_id is null then
    return new;
  end if;

  if new.vin is null or btrim(new.vin) = '' then
    return new;
  end if;

  if tg_op = 'UPDATE' and new.odometer is not distinct from old.odometer then
    return new;
  end if;

  if new.odometer is null then
    return new;
  end if;

  select max(v.odometer + coalesce(s.tracked, 0))
  into v_floor
  from public.vehicles v
  left join (
    select vehicle_id, sum(total_miles) as tracked
    from public.sessions
    where vehicle_id is not null
    group by vehicle_id
  ) s on s.vehicle_id = v.id
  where v.owner_user_id = new.owner_user_id
    and v.vin = new.vin
    and v.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
    and v.odometer is not null;

  if v_floor is not null and new.odometer < v_floor then
    raise exception 'ODOMETER_BELOW_FLOOR:%', v_floor;
  end if;

  return new;
end;
$$;

drop trigger if exists tr_vehicles_enforce_odometer_floor on public.vehicles;
create trigger tr_vehicles_enforce_odometer_floor
before insert or update on public.vehicles
for each row execute function public.fn_enforce_vehicle_odometer_floor();
