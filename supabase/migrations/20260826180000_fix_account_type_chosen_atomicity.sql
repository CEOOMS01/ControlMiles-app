-- Real bug found live on the user's own real account:
-- create_organization/claim_driver_slot set profiles.account_type +
-- default_org_id atomically (server-side), but
-- user_onboarding.account_type_chosen was only ever set by a SEPARATE
-- client-side call (AppState.completeAccountTypeChoice()) made AFTER
-- the RPC returned. If the app closes/crashes/loses network between
-- those two steps, the account ends up exactly in the state the real
-- user's account was found in: account_type='fleet_admin' with a real
-- organization (in fact two), but account_type_chosen=false -- which
-- routes straight back to the Gig/Fleet choice screen, whose Fleet
-- button has no "you already have an org" check and just offers to
-- create another one.
--
-- Root-caused, not papered over: both RPCs now set account_type_chosen
-- atomically in the SAME transaction as account_type/default_org_id.
-- Verified live: a fresh account (account_type_chosen starting false)
-- correctly flips to true within the same create_organization call
-- (tested in a ROLLBACK'd transaction, nothing persisted). Also
-- directly fixed the real account's stale flags (both
-- account_type_chosen and welcome_seen were false despite genuine,
-- long-standing fleet_admin usage with real trip history).
--
-- See also: app_routes.dart's getInitialRoute() reordered so
-- isFleetAdmin/isFleetDriver are checked BEFORE accountTypeChosen --
-- defense in depth so this class of bug can't misroute a real account
-- even if the flag desyncs again for some other reason in the future.

create or replace function public.create_organization(p_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_owned_count int;
  v_entitled boolean;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'Organization name is required';
  end if;

  select count(*) into v_owned_count
  from public.organization_members
  where user_id = auth.uid() and member_role = 'owner';

  select multi_org_entitled into v_entitled
  from public.profiles where id = auth.uid();

  if v_owned_count >= 1 and not coalesce(v_entitled, false) then
    raise exception 'You already own a fleet organization. Creating more than one requires the multi-fleet add-on.';
  end if;

  insert into public.organizations (name, created_by)
  values (trim(p_name), auth.uid())
  returning id into v_org_id;

  insert into public.organization_members (organization_id, user_id, member_role, is_active, joined_at)
  values (v_org_id, auth.uid(), 'owner', true, now());

  update public.profiles
  set account_type = 'fleet_admin', default_org_id = v_org_id
  where id = auth.uid();

  insert into public.user_onboarding (user_id, account_type_chosen)
  values (auth.uid(), true)
  on conflict (user_id) do update set account_type_chosen = true;

  return v_org_id;
end;
$$;

revoke all on function public.create_organization(text) from public;
revoke all on function public.create_organization(text) from anon;
grant execute on function public.create_organization(text) to authenticated;

create or replace function public.claim_driver_slot(
  p_claim_code text
)
returns table(success boolean, message text, organization_name text, display_id text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_caller uuid := auth.uid();
  v_recent_failures int;
  v_hash text;
  v_slot record;
  v_caller_account_type text;
  v_org_name text;
begin
  if v_caller is null then
    raise exception 'Authentication required';
  end if;

  select count(*) into v_recent_failures
  from public.driver_slot_claim_attempts a
  where a.user_id = v_caller
    and a.success = false
    and a.attempted_at > now() - interval '15 minutes';

  if v_recent_failures >= 5 then
    return query select false, 'Too many attempts. Try again later.', null::text, null::text;
    return;
  end if;

  select account_type into v_caller_account_type from public.profiles where id = v_caller;
  if v_caller_account_type = 'fleet_admin' then
    insert into public.driver_slot_claim_attempts (user_id, success, slot_id) values (v_caller, false, null);
    return query select false, 'You already manage your own fleet and cannot join another as a driver.', null::text, null::text;
    return;
  end if;

  v_hash := encode(digest(coalesce(p_claim_code, ''), 'sha256'), 'hex');

  select * into v_slot
  from public.fleet_driver_slots s
  where s.claim_code_hash = v_hash
    and s.claimed_by is null
  limit 1;

  if not found then
    insert into public.driver_slot_claim_attempts (user_id, success, slot_id) values (v_caller, false, null);
    return query select false, 'Invalid or already-claimed code.', null::text, null::text;
    return;
  end if;

  update public.fleet_driver_slots
  set claimed_by = v_caller, claimed_at = now()
  where id = v_slot.id;

  insert into public.organization_members (organization_id, user_id, member_role, is_active, joined_at)
  values (v_slot.organization_id, v_caller, 'driver', true, now())
  on conflict do nothing;

  update public.profiles
  set account_type = 'fleet_driver', default_org_id = v_slot.organization_id
  where id = v_caller;

  insert into public.user_onboarding (user_id, account_type_chosen)
  values (v_caller, true)
  on conflict (user_id) do update set account_type_chosen = true;

  select name into v_org_name from public.organizations where id = v_slot.organization_id;

  insert into public.driver_slot_claim_attempts (user_id, success, slot_id) values (v_caller, true, v_slot.id);

  return query select true, 'ok', v_org_name, v_slot.display_id;
end;
$$;

revoke all on function public.claim_driver_slot(text) from public;
revoke all on function public.claim_driver_slot(text) from anon;
grant execute on function public.claim_driver_slot(text) to authenticated;
