-- Invite directly as Operator/Admin (explicit user request, 2026-09-18:
-- "este operador y el admin que crea el owner tambien deberan ser
-- creados mediante el mismo menu que se crea un driver"). Before this,
-- the only way to get an Operator/Admin was a two-step dance: invite as
-- a driver, wait for them to confirm their account, THEN promote via
-- set_member_operator/set_member_admin. Same invite form now, one more
-- field -- the intended role is captured and validated at invite time,
-- carried through to when the driver actually confirms their account.
alter table public.driver_invites
  add column intended_role text not null default 'driver'
    check (intended_role in ('driver', 'operator', 'admin'));

DROP FUNCTION IF EXISTS public.create_driver_invite(uuid, text, text, text);

CREATE OR REPLACE FUNCTION public.create_driver_invite(
  p_org_id uuid,
  p_email text,
  p_first_name text,
  p_last_name text,
  p_intended_role text DEFAULT 'driver'
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
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

  -- Same authority hierarchy as set_member_operator/set_member_admin,
  -- just checked up front instead of after the person already exists as
  -- a driver: inviting someone straight to 'admin' is owner-only,
  -- straight to 'operator' needs admin-or-owner, straight to 'driver'
  -- (the existing behavior, unchanged) needs operator-or-above.
  if p_intended_role = 'admin' and not public.is_org_owner(p_org_id) then
    raise exception 'Only the organization owner can invite someone directly as an admin';
  end if;

  if p_intended_role = 'operator' and not public.is_org_admin_or_owner(p_org_id) then
    raise exception 'Only an org admin or owner can invite someone directly as an operator';
  end if;

  if not public.is_org_operator_or_above(p_org_id) then
    raise exception 'Only an org admin, owner, or operator can invite drivers';
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
$function$;

REVOKE EXECUTE ON FUNCTION public.create_driver_invite(uuid, text, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_driver_invite(uuid, text, text, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_driver_invite(uuid, text, text, text, text) TO authenticated;

-- accept_driver_invite now grants whatever role was actually validated
-- and locked in at invite time (v_invite.intended_role) instead of
-- hardcoding 'driver' -- the authorization already happened above in
-- create_driver_invite, this just honors it.
CREATE OR REPLACE FUNCTION public.accept_driver_invite(p_token text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_caller_email text;
  v_caller_account_type text;
  v_hash text := encode(digest(coalesce(p_token, ''), 'sha256'), 'hex');
  v_invite record;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT email, account_type INTO v_caller_email, v_caller_account_type
  FROM public.profiles WHERE id = v_caller;

  IF v_caller_account_type = 'fleet_admin' THEN
    RAISE EXCEPTION 'You already manage your own fleet and cannot join another as a driver';
  END IF;

  SELECT id, organization_id, email, slot_id, intended_role INTO v_invite
  FROM public.driver_invites
  WHERE token_hash = v_hash AND status = 'pending' AND expires_at > now()
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid or expired invite';
  END IF;

  IF lower(v_caller_email) != lower(v_invite.email) THEN
    RAISE EXCEPTION 'This invite was sent to a different email address';
  END IF;

  INSERT INTO public.organization_members (organization_id, user_id, member_role, is_active, joined_at)
  VALUES (v_invite.organization_id, v_caller, coalesce(v_invite.intended_role, 'driver'), true, now())
  ON CONFLICT (organization_id, user_id) DO UPDATE
    SET is_active = true, joined_at = now();

  UPDATE public.profiles
  SET account_type = 'fleet_driver', default_org_id = v_invite.organization_id
  WHERE id = v_caller;

  INSERT INTO public.user_onboarding (user_id, account_type_chosen)
  VALUES (v_caller, true)
  ON CONFLICT (user_id) DO UPDATE SET account_type_chosen = true;

  UPDATE public.driver_invites
  SET status = 'accepted', accepted_by = v_caller
  WHERE id = v_invite.id;

  IF v_invite.slot_id IS NOT NULL THEN
    UPDATE public.fleet_driver_slots
    SET claimed_by = v_caller, claimed_at = now()
    WHERE id = v_invite.slot_id AND claimed_by IS NULL;
  END IF;

  RETURN v_invite.organization_id;
END;
$function$;
