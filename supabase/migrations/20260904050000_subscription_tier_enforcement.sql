-- Real subscription-tier enforcement (explicit user requirement,
-- 2026-09-04). Today only Automatic Detection is Premium-gated -- a Free
-- (no subscription) user sees the identical app to Premium for
-- everything else. Rules: FREE = 30-day trial then tracking blocked, 1
-- vehicle max; BASIC = 2 PDF exports/month, 2 vehicles max; PREMIUM =
-- unlimited both. Fleet accounts (fleet_admin/fleet_driver) are
-- explicitly out of scope -- checked via profiles.account_type = 'gig'
-- everywhere below, same exclusion pattern already used elsewhere in this
-- schema (e.g. the Gig/Fleet branch in getActiveOrAssignedVehicle).
--
-- Two-layer enforcement, matching this project's own established pattern
-- (fn_enforce_vehicle_odometer_floor_by_vin, tr_vehicles_block_switch_
-- during_session): server-side triggers/RPC here are the real floor a
-- modified client can't bypass; the Flutter app adds instant client-side
-- checks on top for UX, not as the only defense.
--
-- profiles.tier_enforcement_exempt (added below) lets specific accounts
-- (owner/QA) skip all of this -- a dedicated flag rather than hardcoding
-- a UUID inline in 3 different functions, so future exempt accounts are
-- a one-row UPDATE, not a code change.

alter table public.profiles
  add column if not exists tier_enforcement_exempt boolean not null default false;

-- ============================================================
-- 1. Free-trial trip block
-- ============================================================
create or replace function public.fn_enforce_trial_or_subscription()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_created_at timestamptz;
  v_base boolean;
  v_premium boolean;
  v_account_type text;
  v_exempt boolean;
begin
  select created_at, base_entitled, premium_entitled, account_type, tier_enforcement_exempt
    into v_created_at, v_base, v_premium, v_account_type, v_exempt
    from public.profiles
    where id = new.user_id;

  if v_exempt is true then
    return new;
  end if;

  -- Fleet accounts are out of scope entirely -- separate pricing model,
  -- not built yet.
  if v_account_type is distinct from 'gig' then
    return new;
  end if;

  if v_base is true or v_premium is true then
    return new;
  end if;

  if v_created_at is not null and now() - v_created_at > interval '30 days' then
    raise exception 'FREE_TRIAL_EXPIRED';
  end if;

  return new;
end;
$$;

drop trigger if exists tr_sessions_enforce_trial on public.sessions;
create trigger tr_sessions_enforce_trial
  before insert on public.sessions
  for each row execute function public.fn_enforce_trial_or_subscription();

-- ============================================================
-- 2. Vehicle count limit (1 free / 2 basic / unlimited premium)
-- ============================================================
create or replace function public.fn_enforce_vehicle_count_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_base boolean;
  v_premium boolean;
  v_account_type text;
  v_exempt boolean;
  v_max int;
  v_current_count int;
begin
  select base_entitled, premium_entitled, account_type, tier_enforcement_exempt
    into v_base, v_premium, v_account_type, v_exempt
    from public.profiles
    where id = new.owner_user_id;

  if v_exempt is true then
    return new;
  end if;

  -- Fleet vehicles (organization_id set, owner_user_id null on the fleet
  -- path) and non-gig accounts are out of scope entirely.
  if new.owner_user_id is null or v_account_type is distinct from 'gig' then
    return new;
  end if;

  if v_premium is true then
    return new; -- unlimited
  end if;

  v_max := case when v_base is true then 2 else 1 end;

  select count(*) into v_current_count
  from public.vehicles
  where owner_user_id = new.owner_user_id
    and is_archived = false;

  if v_current_count >= v_max then
    raise exception 'VEHICLE_LIMIT_REACHED:%', v_max;
  end if;

  return new;
end;
$$;

drop trigger if exists tr_vehicles_enforce_count_limit on public.vehicles;
create trigger tr_vehicles_enforce_count_limit
  before insert on public.vehicles
  for each row execute function public.fn_enforce_vehicle_count_limit();

-- ============================================================
-- 3. PDF export monthly limit (2/month for Free+Basic, unlimited Premium)
-- ============================================================
create table if not exists public.pdf_export_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  exported_at timestamptz not null default now()
);

create index if not exists idx_pdf_export_log_user_month
  on public.pdf_export_log (user_id, exported_at);

alter table public.pdf_export_log enable row level security;

create policy pdf_export_log_select_own
  on public.pdf_export_log for select
  using (user_id = auth.uid());
-- Deliberately no insert policy for the client -- only the SECURITY
-- DEFINER RPC below writes here, same "no direct write path" pattern
-- already used for vehicle_odometer_checkpoints/vehicle_inspections.

revoke all on public.pdf_export_log from public, anon;
grant select on public.pdf_export_log to authenticated;

create or replace function public.check_and_log_pdf_export()
returns table(allowed boolean, exports_this_month int, monthly_limit int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_base boolean;
  v_premium boolean;
  v_exempt boolean;
  v_month_start timestamptz;
  v_count int;
begin
  if v_caller is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select base_entitled, premium_entitled, tier_enforcement_exempt
    into v_base, v_premium, v_exempt
    from public.profiles where id = v_caller;

  if v_premium is true or v_exempt is true then
    insert into public.pdf_export_log (user_id) values (v_caller);
    return query select true, null::int, null::int;
    return;
  end if;

  v_month_start := date_trunc('month', now());

  select count(*) into v_count
  from public.pdf_export_log
  where user_id = v_caller and exported_at >= v_month_start;

  if v_count >= 2 then
    return query select false, v_count, 2;
    return;
  end if;

  insert into public.pdf_export_log (user_id) values (v_caller);
  return query select true, v_count + 1, 2;
end;
$$;

revoke execute on function public.check_and_log_pdf_export() from public, anon;
grant execute on function public.check_and_log_pdf_export() to authenticated;

-- Owner/QA exemption -- kept as its own statement so it's obvious in the
-- migration history which account was exempted and when, per explicit
-- user request the same session this whole migration shipped in.
update public.profiles
  set tier_enforcement_exempt = true
  where email = 'alsoler26@gmail.com';
