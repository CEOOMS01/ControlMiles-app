-- Operator role (explicit user request, 2026-09-18): a THIRD membership
-- tier below owner/admin -- an admin the owner can delegate day-to-day
-- fleet operations to, without handing over full admin power. Explicit
-- scope from the user, enforced here at the RLS/RPC level, not just
-- hidden in the UI:
--   CAN:    add/edit/delete/assign a driver, assign a driver to a
--           vehicle/truck, manage routes.
--   CANNOT: remove the owner, promote anyone to admin/operator, delete
--           the organization.
--
-- Audited every current is_org_admin_or_owner() usage before writing
-- this (27 RLS policies + 5 RPCs) rather than guessing -- only the
-- policies/RPCs covering the explicit scope above are widened to
-- operator; everything else (org settings/billing, safety events,
-- inspections, activity log, IFTA, reports, geofences, deleting the
-- org) stays admin+owner only, unchanged. delete_organization() already
-- checked member_role = 'owner' directly (not via the helper), so it
-- was already correctly owner-only before this migration.
alter table public.organization_members
  drop constraint organization_members_member_role_check;

alter table public.organization_members
  add constraint organization_members_member_role_check
  check (member_role = ANY (ARRAY['owner', 'admin', 'operator', 'driver']));

-- Mirrors is_org_admin_or_owner's own shape exactly (STABLE SECURITY
-- DEFINER SQL function, same is_active/organization scoping) -- adds
-- 'operator' to the set, used only where the explicit scope above
-- applies. is_org_admin_or_owner itself is UNCHANGED (still owner+admin
-- only) so every action not touched by this migration keeps its exact
-- current behavior.
CREATE OR REPLACE FUNCTION public.is_org_operator_or_above(p_organization_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE organization_id = p_organization_id
      AND user_id = auth.uid()
      AND is_active = true
      AND member_role IN ('owner', 'admin', 'operator')
  );
$function$;

-- ============================================================
-- organization_members: the sensitive one -- an operator manages the
-- roster, but the row-level restriction below (member_role = 'driver'
-- on both the existing row and, for UPDATE, the row being written) is
-- what actually enforces "cannot remove the owner, cannot promote to
-- admin/operator" -- not UI hiding. is_org_admin_or_owner's own branch
-- stays first and unrestricted so admin/owner behavior is byte-for-byte
-- unchanged.
-- ============================================================

ALTER POLICY org_members_select_admin
ON public.organization_members
USING (public.is_org_operator_or_above(organization_id));

ALTER POLICY org_members_insert_admin
ON public.organization_members
WITH CHECK (
  public.is_org_admin_or_owner(organization_id)
  OR (public.is_org_operator_or_above(organization_id) AND member_role = 'driver')
  OR (NOT EXISTS (
        SELECT 1 FROM public.organization_members om2
        WHERE om2.organization_id = organization_members.organization_id
      ))
);

ALTER POLICY org_members_delete_admin_or_self
ON public.organization_members
USING (
  auth.uid() = user_id
  OR public.is_org_admin_or_owner(organization_id)
  OR (public.is_org_operator_or_above(organization_id) AND member_role = 'driver')
);

ALTER POLICY org_members_update_admin
ON public.organization_members
USING (
  public.is_org_admin_or_owner(organization_id)
  OR (public.is_org_operator_or_above(organization_id) AND member_role = 'driver')
)
WITH CHECK (
  public.is_org_admin_or_owner(organization_id)
  OR (public.is_org_operator_or_above(organization_id) AND member_role = 'driver')
);

-- ============================================================
-- vehicles: assign/edit/add/remove a truck, explicitly in scope.
-- ============================================================

ALTER POLICY vehicles_insert
ON public.vehicles
WITH CHECK (
  owner_user_id = auth.uid()
  OR (organization_id IS NOT NULL AND public.is_org_operator_or_above(organization_id))
);

ALTER POLICY vehicles_update
ON public.vehicles
USING (
  owner_user_id = auth.uid()
  OR (organization_id IS NOT NULL AND public.is_org_operator_or_above(organization_id))
)
WITH CHECK (
  owner_user_id = auth.uid()
  OR (organization_id IS NOT NULL AND public.is_org_operator_or_above(organization_id))
);

ALTER POLICY vehicles_delete
ON public.vehicles
USING (
  owner_user_id = auth.uid()
  OR (organization_id IS NOT NULL AND public.is_org_operator_or_above(organization_id))
);

-- ============================================================
-- routes: explicitly in scope. routes_delete_admin's own status='draft'
-- guard is preserved unchanged.
-- ============================================================

ALTER POLICY routes_select_admin
ON public.routes
USING (public.is_org_operator_or_above(organization_id));

ALTER POLICY routes_insert_admin
ON public.routes
WITH CHECK (public.is_org_operator_or_above(organization_id) AND created_by = auth.uid());

ALTER POLICY routes_update_admin
ON public.routes
USING (public.is_org_operator_or_above(organization_id))
WITH CHECK (public.is_org_operator_or_above(organization_id));

ALTER POLICY routes_delete_admin
ON public.routes
USING (public.is_org_operator_or_above(organization_id) AND status = 'draft');

-- ============================================================
-- fleet_driver_slots / driver_invites: an operator needs to see the
-- roster (pending invites, unclaimed slots) and remove a driver slot --
-- creation already goes through create_driver_slot/create_driver_invite
-- below, not a direct INSERT policy.
-- ============================================================

ALTER POLICY fleet_driver_slots_select_admin
ON public.fleet_driver_slots
USING (public.is_org_operator_or_above(organization_id));

ALTER POLICY fleet_driver_slots_delete_admin
ON public.fleet_driver_slots
USING (public.is_org_operator_or_above(organization_id));

ALTER POLICY driver_invites_select_admin
ON public.driver_invites
USING (public.is_org_operator_or_above(organization_id));

-- ============================================================
-- RPCs: same authorization-check-swap pattern as the roster/vehicle
-- policies above, no other logic changed.
-- ============================================================

CREATE OR REPLACE FUNCTION public.assign_vehicle_to_driver(p_vehicle_id uuid, p_driver_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
$function$;

-- REAL BUG FOUND LIVE while testing the operator role above (unrelated to
-- the role change itself -- this function's search_path was wrong before
-- this migration too): SET search_path TO 'public' alone, but digest()
-- (pgcrypto) lives in the 'extensions' schema on this project -- every
-- call to create_driver_slot has always thrown 42883 "function digest
-- does not exist", meaning the in-person claim-code driver-creation path
-- has been silently broken since pgcrypto moved to that schema.
-- create_driver_invite (this same migration series, written earlier
-- today) already got this right; this brings create_driver_slot in line
-- with it. Verified live: failed with exactly that error before this
-- fix, succeeded (real CM-D#### returned) after.
CREATE OR REPLACE FUNCTION public.create_driver_slot(p_org_id uuid, p_first_name text, p_last_name text)
RETURNS TABLE(slot_id uuid, display_id text, claim_code text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.remove_driver_from_org(p_org_id uuid, p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_org_operator_or_above(p_org_id) then
    raise exception 'Only an org admin, owner, or operator can remove a driver';
  end if;

  update public.organization_members
  set is_active = false
  where organization_id = p_org_id and user_id = p_user_id and member_role = 'driver';

  if not found then
    raise exception 'No active driver membership found for that user in this organization';
  end if;
end;
$function$;

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

  insert into public.driver_invites (organization_id, email, token_hash, created_by, first_name, last_name, slot_id)
  values (p_org_id, v_email, v_hash, auth.uid(), v_first_name, v_last_name, v_slot_id);

  return v_token;
end;
$function$;

-- Real owner/admin-only action, explicitly NOT delegable to an operator
-- (the user's own stated boundary: an operator "no podrá asignar admin")
-- -- interpreted to cover promoting to operator too, not just to admin,
-- since both are a grant of elevated power an operator shouldn't be able
-- to hand to someone else. The WHERE clause is the real safety boundary,
-- not just the is_org_admin_or_owner check above it: it can only ever
-- touch a row that is ALREADY 'driver' or 'operator', so this function
-- has no code path that can reach an owner's or an existing admin's row,
-- even if called with their user_id by mistake or malice.
CREATE OR REPLACE FUNCTION public.set_member_operator(
  p_org_id uuid,
  p_user_id uuid,
  p_make_operator boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_org_admin_or_owner(p_org_id) then
    raise exception 'Only an org admin or owner can assign operators';
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
$function$;

REVOKE EXECUTE ON FUNCTION public.set_member_operator(uuid, uuid, boolean) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.set_member_operator(uuid, uuid, boolean) FROM anon;
GRANT EXECUTE ON FUNCTION public.set_member_operator(uuid, uuid, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.invite_member_by_email(p_org_id uuid, p_email text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
$function$;
