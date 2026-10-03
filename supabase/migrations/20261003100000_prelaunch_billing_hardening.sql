-- Pre-launch billing + security hardening (2026-10-03 audit).
--
-- 1. organizations had no column guard: the organizations_update_admin /
--    organizations_insert_auth policies let any org admin write
--    tier_enforcement_exempt, subscription_* or created_at straight through
--    PostgREST -> free Growth forever, or an endless 5-day trial. Billing
--    columns are now writable only by SECURITY DEFINER functions and the
--    service role (stripe-webhook), same pattern as
--    fn_guard_profile_protected_columns on profiles.
-- 2. reports_insert_own let a user insert a report row with any metadata and
--    their own qr_token hash, which the Report Portal then shows as a
--    verified report. Reports are created only by generate_report_access_code.
-- 3. get_fleet_export_data (fleet-wide export, a Growth feature) was gated
--    only in the web route; calling the RPC directly skipped the tier check.
-- 4. Stripe dunning: past_due keeps the paid tier while Stripe retries the
--    card, instead of cutting the fleet off on the first failed charge.
-- 5. organizations.stripe_subscription_id so stripe-webhook can update the
--    seat quantity (vehicle count) before each renewal.
-- 6. anon never writes tables directly (RLS already blocked it; this removes
--    the grants as defense in depth).

alter table public.organizations
  add column if not exists stripe_subscription_id text;

create or replace function public.fn_guard_org_billing_columns()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
    new.created_at := now();
    new.tier_enforcement_exempt := false;
    new.stripe_customer_id := null;
    new.stripe_subscription_id := null;
    new.subscription_tier := null;
    new.subscription_status := null;
    new.subscription_vehicle_count := null;
    new.subscription_updated_at := null;
    return new;
  end if;

  if new.id is distinct from old.id
     or new.created_by is distinct from old.created_by
     or new.created_at is distinct from old.created_at
     or new.tier_enforcement_exempt is distinct from old.tier_enforcement_exempt
     or new.stripe_customer_id is distinct from old.stripe_customer_id
     or new.stripe_subscription_id is distinct from old.stripe_subscription_id
     or new.subscription_tier is distinct from old.subscription_tier
     or new.subscription_status is distinct from old.subscription_status
     or new.subscription_vehicle_count is distinct from old.subscription_vehicle_count
     or new.subscription_updated_at is distinct from old.subscription_updated_at
  then
    raise exception 'PROTECTED_ORG_COLUMN: billing fields cannot be changed directly';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_org_billing_columns on public.organizations;
create trigger trg_guard_org_billing_columns
  before insert or update on public.organizations
  for each row execute function public.fn_guard_org_billing_columns();

drop policy if exists reports_insert_own on public.reports;
revoke insert, update, delete on public.reports from anon, authenticated;

create or replace function public.fn_org_effective_tier(p_org_id uuid)
returns text
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_tier text;
begin
  if not public.is_org_member(p_org_id) then
    return 'none';
  end if;

  select case
    when o.tier_enforcement_exempt then 'growth'
    when o.subscription_status in ('active', 'trialing', 'past_due') and o.subscription_tier = 'growth' then 'growth'
    when o.subscription_status in ('active', 'trialing', 'past_due') and o.subscription_tier = 'starter' then 'starter'
    when now() - o.created_at <= interval '5 days' then 'starter'
    else 'none'
  end
  into v_tier
  from public.organizations o
  where o.id = p_org_id;

  return v_tier;
end;
$$;

create or replace function public.get_fleet_export_data(p_org_id uuid, p_start_date date, p_end_date date)
returns table(user_id uuid, driver_name text, driver_display_id text, total_miles double precision, total_sessions bigint, vehicles jsonb)
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not is_org_admin_or_owner(p_org_id) then
    raise exception 'Only an org admin or owner can export fleet-wide data';
  end if;

  if public.fn_org_effective_tier(p_org_id) <> 'growth' then
    raise exception 'FLEET_GROWTH_REQUIRED';
  end if;

  return query
  select
    s.user_id,
    p.full_name as driver_name,
    p.display_id as driver_display_id,
    coalesce(sum(s.total_miles), 0) as total_miles,
    count(distinct s.id) as total_sessions,
    coalesce(
      (select jsonb_agg(distinct jsonb_build_object(
        'display_id', v.display_id, 'make', v.make, 'model', v.model, 'nickname', v.nickname
      ))
      from public.vehicles v
      where v.id in (
        select s2.vehicle_id from public.sessions s2
        where s2.user_id = s.user_id
          and s2.organization_id = p_org_id
          and s2.date_key between p_start_date and p_end_date
          and s2.vehicle_id is not null
      )),
      '[]'::jsonb
    ) as vehicles
  from public.sessions s
  join public.profiles p on p.id = s.user_id
  where s.organization_id = p_org_id
    and s.date_key between p_start_date and p_end_date
  group by s.user_id, p.full_name, p.display_id
  order by total_miles desc;
end;
$$;

-- Seat count for a fleet subscription: the org's non-archived vehicles (the
-- same count the web Billing section shows), at least 1. Called by
-- stripe-webhook (service role) before each renewal.
create or replace function public.fn_org_billable_vehicles(p_org_id uuid)
returns integer
language sql
stable
security definer
set search_path to 'public'
as $$
  select greatest(count(*)::int, 1)
    from public.vehicles
   where organization_id = p_org_id and not coalesce(is_archived, false);
$$;
revoke execute on function public.fn_org_billable_vehicles(uuid) from public, anon, authenticated;

do $$
declare
  r record;
begin
  for r in
    select c.relname
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'p')
  loop
    begin
      execute format('revoke insert, update, delete, truncate on public.%I from anon', r.relname);
    exception when insufficient_privilege then
      raise notice 'skipped %', r.relname;
    end;
  end loop;
end $$;
