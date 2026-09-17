-- Fleet driver ID login (explicit user request, 2026-09-17): a
-- fleet_driver account stops logging in with email/password -- they log
-- in with their CM-D#### ID instead. The admin still never sees or sets
-- the driver's password (they confirm their own account and pick their
-- own password through the existing branded invite-email flow,
-- unchanged) -- only the LOGIN identifier changes, not who controls the
-- credential.
--
-- This unifies the two previously-separate driver-onboarding mechanisms
-- onto one shared display_id namespace: fleet_driver_slots already
-- generates CM-D#### ids (fn_assign_driver_slot_display_id) for the
-- in-person claim-code path, but a driver invited by email
-- (driver_invites) never got one at all. Every driver needs a real ID
-- regardless of which path onboarded them, so create_driver_invite now
-- also reserves a fleet_driver_slots row (same trigger, same ID format,
-- no duplicated generation logic) at invite time, and accept_driver_invite
-- marks it claimed when the driver finishes confirming their account --
-- exactly mirroring what claim_driver_slot already does for the
-- in-person path.
alter table public.driver_invites
  add column first_name text not null default '',
  add column last_name text not null default '',
  add column slot_id uuid references public.fleet_driver_slots(id);

DROP FUNCTION IF EXISTS public.create_driver_invite(uuid, text);

CREATE OR REPLACE FUNCTION public.create_driver_invite(
  p_org_id uuid,
  p_email text,
  p_first_name text,
  p_last_name text
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

  if not public.is_org_admin_or_owner(p_org_id) then
    raise exception 'Only an org admin or owner can invite drivers';
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

  -- claim_code_hash is NOT NULL (shared with the in-person claim-code
  -- path) but this slot is never claimed by code -- a random value no
  -- one will ever be given satisfies the column without a schema change,
  -- and claim_driver_slot's own lookup already requires claimed_by is
  -- null AND a hash match, so an unclaimed slot from this path simply
  -- never matches a real typed code.
  insert into public.fleet_driver_slots (organization_id, first_name, last_name, claim_code_hash, created_by)
  values (p_org_id, v_first_name, v_last_name, encode(gen_random_bytes(24), 'hex'), auth.uid())
  returning id into v_slot_id;

  v_token := encode(gen_random_bytes(24), 'hex');
  v_hash := encode(digest(v_token, 'sha256'), 'hex');

  insert into public.driver_invites (organization_id, email, token_hash, created_by, first_name, last_name, slot_id)
  values (p_org_id, v_email, v_hash, auth.uid(), v_first_name, v_last_name, v_slot_id);

  return v_token;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.create_driver_invite(uuid, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_driver_invite(uuid, text, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_driver_invite(uuid, text, text, text) TO authenticated;

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

  SELECT id, organization_id, email, slot_id INTO v_invite
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
  VALUES (v_invite.organization_id, v_caller, 'driver', true, now())
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

  -- Mirrors claim_driver_slot's own claim step -- an invite created before
  -- this migration has no slot_id (nullable, backward compatible), in
  -- which case there's simply no ID to assign, same as if this feature
  -- didn't exist for that one row.
  IF v_invite.slot_id IS NOT NULL THEN
    UPDATE public.fleet_driver_slots
    SET claimed_by = v_caller, claimed_at = now()
    WHERE id = v_invite.slot_id AND claimed_by IS NULL;
  END IF;

  RETURN v_invite.organization_id;
END;
$function$;
