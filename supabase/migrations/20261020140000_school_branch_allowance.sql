-- Driving school branches per plan (user decision 2026-10-20; driving schools
-- only, other services get their own pricing later):
--   Starter    1 branch included, up to 1 extra   ($24.99 / month each)
--   Growth     2 branches included, up to 2 extra ($19.99 / month each)
--   Enterprise unlimited
-- Market: ZoomScheduler $49 / extra site; Software for Driving School
-- $399 / month for multi-location. A branch beyond the plan's maximum needs
-- the next plan. Existing branches are never removed on a downgrade; only
-- adding one more is blocked. Other fleets and exempt orgs: no limit (null).

create or replace function public.fn_org_branch_allowance_internal(p_org uuid)
returns table(included int, max_branches int, extra_price_cents int, active int)
language sql stable security definer set search_path to 'public' as $$
  with o as (
    select o.id, o.industry_template, o.tier_enforcement_exempt from public.organizations o where o.id = p_org
  ), t as (
    select case
             when (select tier_enforcement_exempt from o) or public.fn_org_enterprise_internal(p_org) then 'enterprise'
             else public.fn_org_tier_internal(p_org)
           end as tier
  )
  select case when o.industry_template <> 'driving_school' or t.tier = 'enterprise' then null
              when t.tier = 'growth' then 2 else 1 end,
         case when o.industry_template <> 'driving_school' or t.tier = 'enterprise' then null
              when t.tier = 'growth' then 4 when t.tier = 'starter' then 2 else 1 end,
         case when o.industry_template <> 'driving_school' or t.tier = 'enterprise' then null
              when t.tier = 'growth' then 1999 when t.tier = 'starter' then 2499 else null end,
         (select count(*)::int from public.branches b where b.organization_id = p_org and not b.is_archived)
    from o, t;
$$;
revoke execute on function public.fn_org_branch_allowance_internal(uuid) from public, anon, authenticated;

-- What the admin sees (Settings > Branches, Billing).
create or replace function public.fn_org_branch_allowance(p_org uuid)
returns table(included int, max_branches int, extra_price_cents int, active int)
language plpgsql stable security definer set search_path to 'public' as $$
begin
  if not public.is_org_member(p_org) then raise exception 'Not authorized'; end if;
  return query select * from public.fn_org_branch_allowance_internal(p_org);
end $$;
revoke execute on function public.fn_org_branch_allowance(uuid) from public, anon;
grant execute on function public.fn_org_branch_allowance(uuid) to authenticated;

-- Billing (create-checkout-session, stripe-webhook) counts extras for the
-- plan being bought from the active branches, with the same numbers
-- (supabase/functions/_shared/school_pricing.ts).

-- Adding (or restoring) a branch past the plan's maximum is refused.
create or replace function public.fn_branches_plan_limit()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare
  a record;
begin
  if new.is_archived then return new; end if;
  if tg_op = 'UPDATE' and not old.is_archived then return new; end if;
  select * into a from public.fn_org_branch_allowance_internal(new.organization_id);
  if a.max_branches is not null and a.active >= a.max_branches then
    raise exception 'Your plan allows up to % %. Upgrade your plan to add more.',
      a.max_branches, case when a.max_branches = 1 then 'branch' else 'branches' end
      using errcode = 'P0001';
  end if;
  return new;
end $$;

drop trigger if exists tr_branches_plan_limit on public.branches;
create trigger tr_branches_plan_limit
  before insert or update of is_archived on public.branches
  for each row execute function public.fn_branches_plan_limit();
