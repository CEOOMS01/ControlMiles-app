-- Fleet tier gating (explicit user requirement, 2026-09-18): until now
-- `organizations.subscription_tier`/`subscription_status` (added by
-- 20260917150000_fleet_subscription_columns.sql) were written by
-- stripe-webhook but read NOWHERE -- every Fleet org, subscribed or not,
-- had identical access to every feature the pricing page has ever
-- advertised as Starter-vs-Growth-exclusive. Confirmed live before
-- writing this (zero RLS policies or RPCs referenced either column).
-- This migration is the real floor, decided with the user before a
-- single Stripe Price object exists for Fleet:
--
--   STARTER (or the 5-day trial below): roster (invite/create/assign/
--     remove/promote), GPS tracking, odometer verification, Report
--     Portal, membership revocation.
--   GROWTH: everything Starter has, plus DVIR, geofencing, live map,
--     open/rotating vehicle assignment, fleet-wide CSV/PDF export,
--     the org-wide activity log page.
--   ENTERPRISE: everything Growth has, plus onboarding/custom
--     reporting/priority support -- human service, nothing to gate here.
--
-- No-subscription orgs (explicit user decision): 5-day Starter-level
-- trial from organizations.created_at, then 'none' (blocked from all of
-- the above) until they subscribe. Every Fleet org that already existed
-- before this migration is grandfathered exempt -- there are no real
-- paying Fleet customers yet (Stripe was only just configured), so this
-- is the one-time moment to add real enforcement without locking anyone
-- out mid-use; any org created AFTER this migration starts the real
-- 5-day clock.

alter table public.organizations
  add column if not exists tier_enforcement_exempt boolean not null default false;

update public.organizations set tier_enforcement_exempt = true;

-- Mirrors profiles.tier_enforcement_exempt's own reasoning (owner/QA
-- override) but at org level, since Fleet features are org-scoped, not
-- per-profile. 'growth' > 'starter' > 'none', matching ACTIVE_STATUSES
-- in stripe-webhook/index.ts exactly (active/trialing both count).
create or replace function public.fn_org_effective_tier(p_org_id uuid)
returns text
language sql
stable
security definer
set search_path to 'public'
as $$
  select case
    when o.tier_enforcement_exempt then 'growth'
    when o.subscription_status in ('active', 'trialing') and o.subscription_tier = 'growth' then 'growth'
    when o.subscription_status in ('active', 'trialing') and o.subscription_tier = 'starter' then 'starter'
    when now() - o.created_at <= interval '5 days' then 'starter'
    else 'none'
  end
  from public.organizations o
  where o.id = p_org_id;
$$;

revoke execute on function public.fn_org_effective_tier(uuid) from public;
revoke execute on function public.fn_org_effective_tier(uuid) from anon;
grant execute on function public.fn_org_effective_tier(uuid) to authenticated;

-- ============================================================
-- STARTER+ (blocks only the 'none' tier -- no active sub, trial expired)
-- ============================================================

create or replace function public.assign_vehicle_to_driver(p_vehicle_id uuid, p_driver_user_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_vehicle_org_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT organization_id INTO v_vehicle_org_id
  FROM public.vehicles
  WHERE id = p_vehicle_id;

  IF v_vehicle_org_id IS NULL THEN
    RAISE EXCEPTION 'Vehicle not found or not a fleet vehicle';
  END IF;

  IF NOT public.is_org_operator_or_above(v_vehicle_org_id) THEN
    RAISE EXCEPTION 'Only an org admin, owner, or operator can assign vehicles';
  END IF;

  IF public.fn_org_effective_tier(v_vehicle_org_id) = 'none' THEN
    RAISE EXCEPTION 'FLEET_SUBSCRIPTION_REQUIRED';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE organization_id = v_vehicle_org_id
      AND user_id = p_driver_user_id
      AND is_active = true
  ) THEN
    RAISE EXCEPTION 'That person is not an active member of this organization';
  END IF;

  UPDATE public.vehicles
  SET assigned_driver_id = p_driver_user_id
  WHERE id = p_vehicle_id;
END;
$$;

create or replace function public.create_driver_invite(
  p_org_id uuid, p_email text, p_first_name text, p_last_name text,
  p_intended_role text default 'driver'
)
returns text
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $$
declare
  v_email text := lower(trim(p_email));
  v_first_name text := trim(p_first_name);
  v_last_name text := trim(p_last_name);
  v_target_id uuid;
  v_target_account_type text;
  v_existing_membership uuid;
  v_token text;
  v_hash text;
  v_allowed boolean;
  v_slot_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_intended_role not in ('driver', 'operator', 'admin') then
    raise exception 'Invalid role: %', p_intended_role;
  end if;

  if p_intended_role = 'admin' and not public.is_org_owner(p_org_id) then
    raise exception 'Only the organization owner can invite someone directly as an admin';
  end if;

  if p_intended_role = 'operator' and not public.is_org_admin_or_owner(p_org_id) then
    raise exception 'Only an org admin or owner can invite someone directly as an operator';
  end if;

  if not public.is_org_operator_or_above(p_org_id) then
    raise exception 'Only an org admin, owner, or operator can invite drivers';
  end if;

  if public.fn_org_effective_tier(p_org_id) = 'none' then
    raise exception 'FLEET_SUBSCRIPTION_REQUIRED';
  end if;

  select public.check_rate_limit('create_driver_invite', auth.uid()::text, 20, 3600) into v_allowed;
  if not v_allowed then
    raise exception 'Too many invites created recently. Try again later.';
  end if;

  if v_email = '' or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'A valid email is required';
  end if;

  if v_first_name = '' or v_last_name = '' then
    raise exception 'First and last name are required';
  end if;

  select id, account_type into v_target_id, v_target_account_type
  from public.profiles
  where lower(email) = v_email
  limit 1;

  if v_target_id is not null then
    if v_target_account_type = 'fleet_admin' then
      raise exception 'This person already owns their own fleet and cannot be invited as a driver';
    end if;

    select id into v_existing_membership
    from public.organization_members
    where organization_id = p_org_id and user_id = v_target_id and is_active = true;

    if v_existing_membership is not null then
      raise exception 'This person is already a member of this organization';
    end if;
  end if;

  update public.driver_invites
  set status = 'expired'
  where organization_id = p_org_id and lower(email) = v_email and status = 'pending';

  insert into public.fleet_driver_slots (organization_id, first_name, last_name, claim_code_hash, created_by)
  values (p_org_id, v_first_name, v_last_name, encode(gen_random_bytes(24), 'hex'), auth.uid())
  returning id into v_slot_id;

  v_token := encode(gen_random_bytes(24), 'hex');
  v_hash := encode(digest(v_token, 'sha256'), 'hex');

  insert into public.driver_invites (organization_id, email, token_hash, created_by, first_name, last_name, slot_id, intended_role)
  values (p_org_id, v_email, v_hash, auth.uid(), v_first_name, v_last_name, v_slot_id, p_intended_role);

  return v_token;
end;
$$;

create or replace function public.create_driver_slot(p_org_id uuid, p_first_name text, p_last_name text)
returns table (slot_id uuid, display_id text, claim_code text)
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $$
declare
  v_caller uuid := auth.uid();
  v_code text;
  v_alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_slot_id uuid;
  v_display_id text;
  i int;
begin
  if v_caller is null then
    raise exception 'Authentication required';
  end if;

  if not is_org_operator_or_above(p_org_id) then
    raise exception 'Only an org admin, owner, or operator can add drivers';
  end if;

  if fn_org_effective_tier(p_org_id) = 'none' then
    raise exception 'FLEET_SUBSCRIPTION_REQUIRED';
  end if;

  if btrim(coalesce(p_first_name, '')) = '' or btrim(coalesce(p_last_name, '')) = '' then
    raise exception 'First and last name are required';
  end if;

  v_code := '';
  for i in 1..8 loop
    v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
  end loop;

  insert into public.fleet_driver_slots (
    organization_id, first_name, last_name, claim_code_hash, created_by
  ) values (
    p_org_id, btrim(p_first_name), btrim(p_last_name),
    encode(digest(v_code, 'sha256'), 'hex'), v_caller
  )
  returning id, fleet_driver_slots.display_id into v_slot_id, v_display_id;

  return query select v_slot_id, v_display_id, v_code;
end;
$$;

create or replace function public.remove_driver_from_org(p_org_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_org_operator_or_above(p_org_id) then
    raise exception 'Only an org admin, owner, or operator can remove a driver';
  end if;

  -- Deliberately NOT tier-gated: revoking access must always work even
  -- if a subscription lapses -- an org that can't pay should still be
  -- able to remove people, that's not a feature to hold hostage.

  update public.organization_members
  set is_active = false
  where organization_id = p_org_id and user_id = p_user_id and member_role = 'driver';

  if not found then
    raise exception 'No active driver membership found for that user in this organization';
  end if;
end;
$$;

create or replace function public.invite_member_by_email(p_org_id uuid, p_email text)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_target_id uuid;
  v_target_account_type text;
  v_existing_membership uuid;
  v_membership_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT public.is_org_operator_or_above(p_org_id) THEN
    RAISE EXCEPTION 'Only an org admin, owner, or operator can invite members';
  END IF;

  IF public.fn_org_effective_tier(p_org_id) = 'none' THEN
    RAISE EXCEPTION 'FLEET_SUBSCRIPTION_REQUIRED';
  END IF;

  SELECT id, account_type INTO v_target_id, v_target_account_type
  FROM public.profiles
  WHERE lower(email) = lower(trim(p_email))
  LIMIT 1;

  IF v_target_id IS NULL THEN
    RAISE EXCEPTION 'No ControlMiles account found for that email';
  END IF;

  IF v_target_account_type = 'fleet_admin' THEN
    RAISE EXCEPTION 'This person already owns their own fleet and cannot be invited as a driver';
  END IF;

  SELECT id INTO v_existing_membership
  FROM public.organization_members
  WHERE organization_id = p_org_id AND user_id = v_target_id;

  IF v_existing_membership IS NOT NULL THEN
    RAISE EXCEPTION 'This person is already a member or has a pending invite for this organization';
  END IF;

  INSERT INTO public.organization_members
    (organization_id, user_id, member_role, is_active, invited_at)
  VALUES
    (p_org_id, v_target_id, 'driver', false, now())
  RETURNING id INTO v_membership_id;

  RETURN v_membership_id;
END;
$$;

create or replace function public.set_member_operator(p_org_id uuid, p_user_id uuid, p_make_operator boolean)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_org_admin_or_owner(p_org_id) then
    raise exception 'Only an org admin or owner can assign operators';
  end if;

  if public.fn_org_effective_tier(p_org_id) = 'none' then
    raise exception 'FLEET_SUBSCRIPTION_REQUIRED';
  end if;

  update public.organization_members
  set member_role = case when p_make_operator then 'operator' else 'driver' end
  where organization_id = p_org_id
    and user_id = p_user_id
    and member_role in ('driver', 'operator');

  if not found then
    raise exception 'No active driver or operator membership found for that user in this organization';
  end if;
end;
$$;

create or replace function public.set_member_admin(p_org_id uuid, p_user_id uuid, p_make_admin boolean)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_org_owner(p_org_id) then
    raise exception 'Only the organization owner can assign admins';
  end if;

  if public.fn_org_effective_tier(p_org_id) = 'none' then
    raise exception 'FLEET_SUBSCRIPTION_REQUIRED';
  end if;

  update public.organization_members
  set member_role = case when p_make_admin then 'admin' else 'driver' end
  where organization_id = p_org_id
    and user_id = p_user_id
    and member_role in ('driver', 'operator', 'admin');

  if not found then
    raise exception 'No active driver, operator, or admin membership found for that user in this organization';
  end if;
end;
$$;

-- generate_report_access_code is shared by Gig (self-report,
-- v_organization_id stays null) and Fleet (admin generating for a
-- driver, v_organization_id gets set) -- only the Fleet branch is
-- tier-gated, a Gig self-report is never touched by this.
create or replace function public.generate_report_access_code(
  p_start_date date, p_end_date date, p_vehicle_id uuid default null,
  p_weekly_checkpoints jsonb default '[]'::jsonb, p_target_user_id uuid default null
)
returns table (code text, expires_at timestamptz)
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $$
declare
  v_caller uuid := auth.uid();
  v_user_id uuid;
  v_organization_id uuid;
  v_recent_count int;
  v_plain_code text;
  v_alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_expires timestamptz := now() + interval '15 minutes';
  v_metadata jsonb;
  v_deduction numeric;
  i int;
begin
  if v_caller is null then
    raise exception 'Authentication required';
  end if;

  if p_target_user_id is null or p_target_user_id = v_caller then
    v_user_id := v_caller;
  else
    select caller_m.organization_id into v_organization_id
    from public.organization_members caller_m
    join public.organization_members target_m
      on target_m.organization_id = caller_m.organization_id
    where caller_m.user_id = v_caller
      and caller_m.member_role in ('owner', 'admin')
      and caller_m.is_active = true
      and target_m.user_id = p_target_user_id
      and target_m.is_active = true
    limit 1;

    if v_organization_id is null then
      raise exception 'Not authorized to generate a report for that driver';
    end if;

    if public.fn_org_effective_tier(v_organization_id) = 'none' then
      raise exception 'FLEET_SUBSCRIPTION_REQUIRED';
    end if;

    v_user_id := p_target_user_id;
  end if;

  if p_end_date < p_start_date then
    raise exception 'Invalid date range';
  end if;

  select count(*) into v_recent_count
  from public.reports
  where generated_by = v_caller
    and generated_at > now() - interval '1 hour';

  if v_recent_count >= 5 then
    raise exception 'Too many report codes generated recently. Try again later.';
  end if;

  select coalesce(sum(
    case when s.date_key < date '2026-07-01'
      then s.total_miles * 72.5 / 100.0
      else s.total_miles * 76.0 / 100.0
    end
  ), 0) into v_deduction
  from public.sessions s
  where s.user_id = v_user_id
    and s.date_key between p_start_date and p_end_date
    and (p_vehicle_id is null or s.vehicle_id = p_vehicle_id);

  with vehicles_in_range as (
    select distinct v.id, v.nickname, v.make, v.model, v.year, v.plate
    from public.sessions s
    join public.vehicles v on v.id = s.vehicle_id
    where s.user_id = v_user_id
      and s.date_key between p_start_date and p_end_date
      and (p_vehicle_id is null or s.vehicle_id = p_vehicle_id)
  ),
  purpose_breakdown as (
    select
      ss.gig_app,
      ss.irs_purpose,
      sum(ss.total_miles) as miles
    from public.session_sections ss
    join public.sessions s on s.id = ss.session_id
    where s.user_id = v_user_id
      and s.date_key between p_start_date and p_end_date
      and (p_vehicle_id is null or s.vehicle_id = p_vehicle_id)
    group by ss.gig_app, ss.irs_purpose
  ),
  totals as (
    select
      coalesce(sum(s.total_miles), 0) as total_miles,
      count(distinct s.id) as total_sessions
    from public.sessions s
    where s.user_id = v_user_id
      and s.date_key between p_start_date and p_end_date
      and (p_vehicle_id is null or s.vehicle_id = p_vehicle_id)
  )
  select jsonb_build_object(
    'driver_display_name', p.full_name,
    'driver_display_id', p.display_id,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'generated_at', now(),
    'total_miles', t.total_miles,
    'total_sessions', t.total_sessions,
    'total_deduction_estimate', v_deduction,
    'vehicles', coalesce((select jsonb_agg(jsonb_build_object(
        'nickname', vr.nickname, 'make', vr.make, 'model', vr.model,
        'year', vr.year, 'plate', vr.plate
      )) from vehicles_in_range vr), '[]'::jsonb),
    'gig_app_breakdown', coalesce((select jsonb_agg(jsonb_build_object(
        'gig_app', pb.gig_app, 'irs_purpose', pb.irs_purpose, 'miles', pb.miles
      )) from purpose_breakdown pb), '[]'::jsonb),
    'weekly_checkpoints', coalesce(p_weekly_checkpoints, '[]'::jsonb)
  )
  into v_metadata
  from public.profiles p, totals t
  where p.id = v_user_id;

  v_plain_code := '';
  for i in 1..8 loop
    v_plain_code := v_plain_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
  end loop;

  insert into public.reports (
    report_type, user_id, organization_id, vehicle_id, start_date, end_date,
    total_miles, total_sessions, generated_by, metadata,
    qr_token, qr_expires_at, qr_uses, qr_max_uses
  ) values (
    'custom', v_user_id, v_organization_id, p_vehicle_id, p_start_date, p_end_date,
    coalesce((v_metadata->>'total_miles')::float8, 0),
    coalesce((v_metadata->>'total_sessions')::int, 0),
    v_caller, v_metadata,
    encode(digest(v_plain_code, 'sha256'), 'hex'), v_expires, 0, 2
  );

  return query select v_plain_code, v_expires;
end;
$$;

-- ============================================================
-- GROWTH-only
-- ============================================================

-- DVIR (submit_vehicle_inspection): only gated when the vehicle belongs
-- to an org (v_org is not null) -- an individual Gig owner's personal
-- inspection (no org) is untouched, it was never part of Fleet billing.
create or replace function public.submit_vehicle_inspection(
  p_vehicle_id uuid,
  p_inspection_type text,
  p_items jsonb,
  p_odometer numeric DEFAULT NULL
)
RETURNS public.vehicle_inspections
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_owner uuid;
  v_org uuid;
  v_defect_count int;
  v_overall text;
  v_inspection public.vehicle_inspections;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_inspection_type not in ('pre_trip', 'post_trip') then
    raise exception 'Invalid inspection_type: %', p_inspection_type;
  end if;

  select owner_user_id, organization_id into v_owner, v_org
  from public.vehicles
  where id = p_vehicle_id;

  if not found then
    raise exception 'Vehicle not found';
  end if;

  if v_owner is distinct from auth.uid()
     and not (v_org is not null and public.is_org_member(v_org)) then
    raise exception 'Not authorized to inspect this vehicle';
  end if;

  if v_org is not null and public.fn_org_effective_tier(v_org) <> 'growth' then
    raise exception 'FLEET_GROWTH_REQUIRED';
  end if;

  select count(*) into v_defect_count
  from jsonb_array_elements(p_items) elem
  where elem->>'status' = 'defect';

  v_overall := case when v_defect_count > 0 then 'fail' else 'pass' end;

  insert into public.vehicle_inspections (
    vehicle_id, user_id, organization_id, inspection_type, overall_status, items, odometer
  )
  values (
    p_vehicle_id, auth.uid(), v_org, p_inspection_type, v_overall, p_items, p_odometer
  )
  returning * into v_inspection;

  if v_overall = 'fail' then
    insert into public.vehicle_maintenance_records (
      vehicle_id, user_id, organization_id, type, performed_at, odometer_at_service, notes
    )
    values (
      p_vehicle_id, auth.uid(), v_org, 'other', current_date, p_odometer,
      'Auto-created from failed ' || p_inspection_type || ' inspection: ' ||
      coalesce(
        (select string_agg(elem->>'category', ', ')
         from jsonb_array_elements(p_items) elem
         where elem->>'status' = 'defect'),
        ''
      )
    );
  end if;

  return v_inspection;
end;
$$;

REVOKE EXECUTE ON FUNCTION public.submit_vehicle_inspection(uuid, text, jsonb, numeric) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.submit_vehicle_inspection(uuid, text, jsonb, numeric) FROM anon;
GRANT EXECUTE ON FUNCTION public.submit_vehicle_inspection(uuid, text, jsonb, numeric) TO authenticated;

-- Geofencing: was admin/owner-only regardless of tier -- now also
-- requires Growth. SELECT gated too (not just writes), since geofencing
-- is meant to be a real Growth differentiator, not just write-restricted
-- while any Starter org can still see zones an example Growth org made.
drop policy if exists vehicle_geofences_select on public.vehicle_geofences;
create policy vehicle_geofences_select
on public.vehicle_geofences
for select
using (public.is_org_member(organization_id) and public.fn_org_effective_tier(organization_id) = 'growth');

drop policy if exists vehicle_geofences_insert on public.vehicle_geofences;
create policy vehicle_geofences_insert
on public.vehicle_geofences
for insert
with check (public.is_org_admin_or_owner(organization_id) and public.fn_org_effective_tier(organization_id) = 'growth');

drop policy if exists vehicle_geofences_update on public.vehicle_geofences;
create policy vehicle_geofences_update
on public.vehicle_geofences
for update
using (public.is_org_admin_or_owner(organization_id) and public.fn_org_effective_tier(organization_id) = 'growth')
with check (public.is_org_admin_or_owner(organization_id) and public.fn_org_effective_tier(organization_id) = 'growth');

drop policy if exists vehicle_geofences_delete on public.vehicle_geofences;
create policy vehicle_geofences_delete
on public.vehicle_geofences
for delete
using (public.is_org_admin_or_owner(organization_id) and public.fn_org_effective_tier(organization_id) = 'growth');

-- Open/rotating vehicle assignment is a Growth feature (marketing:
-- "Fixed or open vehicle assignment" under Growth) -- 'fixed' (the
-- default) stays available to everyone, only switching TO 'open' is
-- gated. A trigger, not folded into organizations_update_admin's own
-- WITH CHECK, so every other column that policy already allows
-- (name/compliance_mode/etc.) is completely unaffected.
create or replace function public.fn_enforce_vehicle_assignment_mode_tier()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.vehicle_assignment_mode = 'open'
     and public.fn_org_effective_tier(new.id) <> 'growth' then
    raise exception 'FLEET_GROWTH_REQUIRED';
  end if;
  return new;
end;
$$;

drop trigger if exists tr_organizations_enforce_assignment_mode_tier on public.organizations;
create trigger tr_organizations_enforce_assignment_mode_tier
  before update of vehicle_assignment_mode on public.organizations
  for each row execute function public.fn_enforce_vehicle_assignment_mode_tier();
