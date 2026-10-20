-- Driving school cars: monthly odometer photos (user rule, 2026-10-20).
-- One opening photo with the first trip of the month and one closing photo
-- on the last day of the month (the Fleet app only asks for the close that
-- day), instead of a photo every week. A month whose last day has no trip
-- is closed by the next month's opening photo (roll-forward in
-- submit_vehicle_odometer_checkpoint, unchanged). Hours and miles of each
-- class still come from the class's own GPS trip.

-- Existing driving school cars.
update public.vehicles v
set odometer_cycle = 'monthly'
from public.organizations o
where o.id = v.organization_id
  and o.industry_template = 'driving_school'
  and v.odometer_cycle <> 'monthly';

-- New cars of a driving school.
create or replace function public.fn_vehicles_driving_school_cycle()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.organization_id is not null and exists (
    select 1 from public.organizations o
    where o.id = new.organization_id and o.industry_template = 'driving_school'
  ) then
    new.odometer_cycle := 'monthly';
  end if;
  return new;
end;
$$;
revoke execute on function public.fn_vehicles_driving_school_cycle() from public, anon, authenticated;

drop trigger if exists tr_vehicles_driving_school_cycle on public.vehicles;
create trigger tr_vehicles_driving_school_cycle
  before insert or update of organization_id on public.vehicles
  for each row execute function public.fn_vehicles_driving_school_cycle();

-- An organization that becomes a driving school later.
create or replace function public.fn_org_driving_school_cycle()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.industry_template = 'driving_school'
     and new.industry_template is distinct from old.industry_template then
    update public.vehicles
    set odometer_cycle = 'monthly'
    where organization_id = new.id and odometer_cycle <> 'monthly';
  end if;
  return new;
end;
$$;
revoke execute on function public.fn_org_driving_school_cycle() from public, anon, authenticated;

drop trigger if exists tr_org_driving_school_cycle on public.organizations;
create trigger tr_org_driving_school_cycle
  after update of industry_template on public.organizations
  for each row execute function public.fn_org_driving_school_cycle();
