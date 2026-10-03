-- Fleet type locked after onboarding + 15-day fleet trial (user decision
-- 2026-10-03).
--
-- The fleet type (organizations.industry_template) decides the data model a
-- fleet runs on -- driving schools get classes (shift_blocks), trucking gets
-- IFTA, the type sets the pre-trip default -- so it is chosen once, by the
-- OWNER, during onboarding (web /onboarding/fleet-type, app Create company)
-- and then locked. Same pattern as Square's business category or Motive's
-- carrier/compliance setup: self-service at sign-up, later changes through
-- support. Operational switches (show all modules, pre-trip, shift
-- schedules) stay editable in Settings.
--
-- Before: set_fleet_type let any owner/admin switch it anytime (one click
-- in Settings, no confirmation), and organizations_update_admin even let
-- them write industry_template directly over PostgREST.

-- Who set / changed the fleet type and why (audit_events is per-trip, so
-- this has its own table). Owners/admins read their fleet's rows; nobody
-- writes them except the two functions below.
create table if not exists public.fleet_type_changes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  from_type text,
  to_type text not null,
  changed_by uuid,
  source text not null check (source in ('onboarding', 'support')),
  reason text,
  created_at timestamptz not null default now()
);
create index if not exists fleet_type_changes_org_idx on public.fleet_type_changes (organization_id, created_at desc);
alter table public.fleet_type_changes enable row level security;
drop policy if exists fleet_type_changes_select_admin on public.fleet_type_changes;
create policy fleet_type_changes_select_admin on public.fleet_type_changes
  for select to authenticated using (public.is_org_admin_or_owner(organization_id));
revoke insert, update, delete, truncate on public.fleet_type_changes from anon, authenticated;

create or replace function public.set_fleet_type(p_organization_id uuid, p_industry_template text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not public.is_org_owner(p_organization_id) then
    raise exception 'FLEET_TYPE_OWNER_ONLY';
  end if;
  if not coalesce(public.fn_valid_fleet_profile(p_industry_template), false) then
    raise exception 'Unknown fleet type: %', p_industry_template;
  end if;
  if exists (
    select 1 from public.organizations
     where id = p_organization_id and fleet_type_confirmed_at is not null
  ) then
    raise exception 'FLEET_TYPE_LOCKED';
  end if;

  update public.organizations
     set industry_template = p_industry_template,
         require_pretrip_inspection = public.fn_profile_requires_pretrip(p_industry_template),
         fleet_type_confirmed_at = now()
   where id = p_organization_id;

  insert into public.fleet_type_changes (organization_id, from_type, to_type, changed_by, source)
  values (p_organization_id, null, p_industry_template, auth.uid(), 'onboarding');
end;
$$;

revoke execute on function public.set_fleet_type(uuid, text) from public, anon;
grant execute on function public.set_fleet_type(uuid, text) to authenticated;

-- Support-only change (run with the service role / SQL editor after the
-- owner asks): records who asked and why.
create or replace function public.support_change_fleet_type(
  p_organization_id uuid, p_industry_template text, p_reason text
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_old text;
begin
  if not coalesce(public.fn_valid_fleet_profile(p_industry_template), false) then
    raise exception 'Unknown fleet type: %', p_industry_template;
  end if;
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'A reason is required';
  end if;

  select industry_template into v_old from public.organizations where id = p_organization_id for update;
  if not found then
    raise exception 'Organization not found';
  end if;

  update public.organizations
     set industry_template = p_industry_template,
         require_pretrip_inspection = public.fn_profile_requires_pretrip(p_industry_template),
         fleet_type_confirmed_at = now()
   where id = p_organization_id;

  insert into public.fleet_type_changes (organization_id, from_type, to_type, source, reason)
  values (p_organization_id, v_old, p_industry_template, 'support', p_reason);
end;
$$;

revoke execute on function public.support_change_fleet_type(uuid, text, text) from public, anon, authenticated;

-- Column guard: fleet type joins the billing columns that only definer
-- functions / the service role may write.
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
    new.fleet_type_confirmed_at := null;
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
     or new.industry_template is distinct from old.industry_template
     or new.fleet_type_confirmed_at is distinct from old.fleet_type_confirmed_at
  then
    raise exception 'PROTECTED_ORG_COLUMN: this field cannot be changed directly';
  end if;
  return new;
end;
$$;

-- Fleet free trial: 15 days (was 5).
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
    when now() - o.created_at <= interval '15 days' then 'starter'
    else 'none'
  end
  into v_tier
  from public.organizations o
  where o.id = p_org_id;

  return v_tier;
end;
$$;

-- create_organization (app "Create company", web dashboard create-org):
-- unchanged except that a type picked at creation is recorded in
-- fleet_type_changes like the onboarding step.
create or replace function public.create_organization(p_name text, p_industry_template text default null)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_org_id uuid;
  v_owned_count int;
  v_entitled boolean;
  v_explicit boolean := public.fn_valid_fleet_profile(p_industry_template);
  v_template text := case when public.fn_valid_fleet_profile(p_industry_template) then p_industry_template else 'general' end;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'Organization name is required';
  end if;
  perform pg_advisory_xact_lock(hashtext('create_organization:' || auth.uid()::text));
  select count(*) into v_owned_count
  from public.organization_members
  where user_id = auth.uid() and member_role = 'owner';
  select multi_org_entitled into v_entitled
  from public.profiles where id = auth.uid();
  if v_owned_count >= 1 and not coalesce(v_entitled, false) then
    raise exception 'You already own a fleet organization. Creating more than one requires the multi-fleet add-on.';
  end if;
  insert into public.organizations (name, created_by, industry_template, fleet_type_confirmed_at, require_pretrip_inspection)
  values (trim(p_name), auth.uid(), v_template,
          case when coalesce(v_explicit, false) then now() end,
          public.fn_profile_requires_pretrip(v_template))
  returning id into v_org_id;
  insert into public.organization_members (organization_id, user_id, member_role, is_active, joined_at)
  values (v_org_id, auth.uid(), 'owner', true, now());
  update public.profiles
  set account_type = 'fleet_admin', default_org_id = v_org_id
  where id = auth.uid();
  insert into public.user_onboarding (user_id, account_type_chosen)
  values (auth.uid(), true)
  on conflict (user_id) do update set account_type_chosen = true;
  if coalesce(v_explicit, false) then
    insert into public.fleet_type_changes (organization_id, from_type, to_type, changed_by, source)
    values (v_org_id, null, v_template, auth.uid(), 'onboarding');
  end if;
  return v_org_id;
end;
$$;
