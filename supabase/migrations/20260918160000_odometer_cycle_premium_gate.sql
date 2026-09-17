-- Odometer cycle choice is a Premium feature (explicit user requirement,
-- 2026-09-18): Basic (and Started/free trial) stay fixed on weekly --
-- the only thing that was ever possible before this feature existed --
-- only Premium can pick biweekly/monthly. Client-side check already
-- added in vehicle_screen.dart (VehicleScreen._changeOdometerCycle,
-- same premium_feature_locked dialog AutoDetectAppsButton uses) is UX
-- only; this trigger is the real floor a modified client can't bypass,
-- same two-layer pattern already established project-wide
-- (fn_enforce_vehicle_count_limit, fn_enforce_trial_or_subscription).
--
-- Gig only, matching the feature's own scope decision: Fleet vehicles
-- (organization_id is not null) are never touched by this check.
create or replace function public.fn_enforce_odometer_cycle_tier()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_premium boolean;
  v_exempt boolean;
begin
  if new.odometer_cycle = 'weekly' or new.organization_id is not null then
    return new;
  end if;

  select premium_entitled, tier_enforcement_exempt
    into v_premium, v_exempt
    from public.profiles
    where id = new.owner_user_id;

  if coalesce(v_exempt, false) or coalesce(v_premium, false) then
    return new;
  end if;

  raise exception 'PREMIUM_REQUIRED_FOR_ODOMETER_CYCLE';
end;
$$;

drop trigger if exists tr_vehicles_enforce_odometer_cycle_tier on public.vehicles;
create trigger tr_vehicles_enforce_odometer_cycle_tier
  before insert or update of odometer_cycle on public.vehicles
  for each row execute function public.fn_enforce_odometer_cycle_tier();
