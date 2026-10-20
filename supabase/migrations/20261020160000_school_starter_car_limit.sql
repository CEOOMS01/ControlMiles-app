-- Driving school pricing, second pass (user decision 2026-10-20): a monthly
-- base with 3 cars and the software, then per extra car (Stripe graduated
-- tiers, see supabase/functions/_shared/school_pricing.ts). Starter allows up
-- to 10 cars; adding (or restoring) an 11th asks for Growth. Trial, Growth,
-- Enterprise, exempt orgs and other services: no limit. Existing cars are
-- never archived on a downgrade; only adding one more is blocked.

create or replace function public.fn_vehicles_school_limit()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare
  v_active int;
begin
  if new.organization_id is null or coalesce(new.is_archived, false) then return new; end if;
  if tg_op = 'UPDATE' and not coalesce(old.is_archived, false) and old.organization_id is not distinct from new.organization_id then
    return new;
  end if;
  if not exists (select 1 from public.organizations o
                  where o.id = new.organization_id and o.industry_template = 'driving_school'
                    and not o.tier_enforcement_exempt) then
    return new;
  end if;
  if public.fn_org_enterprise_internal(new.organization_id) or public.fn_org_tier_internal(new.organization_id) <> 'starter' then
    return new;
  end if;
  select count(*) into v_active from public.vehicles
   where organization_id = new.organization_id and not coalesce(is_archived, false) and id <> new.id;
  if v_active >= 10 then
    raise exception 'Starter allows up to 10 cars. Upgrade to Growth to add more.' using errcode = 'P0001';
  end if;
  return new;
end $$;

drop trigger if exists tr_vehicles_school_limit on public.vehicles;
create trigger tr_vehicles_school_limit
  before insert or update of is_archived, organization_id on public.vehicles
  for each row execute function public.fn_vehicles_school_limit();
