-- Fleet Phase 2: accept or decline a pending organization_members row.
-- Accept must activate the membership BEFORE promoting the profile to
-- fleet_driver, same ordering requirement as create_organization
-- (tr_enforce_fleet_org's AFTER trigger needs an active membership row to
-- already exist when account_type changes) -- doing this in two client
-- round-trips would leave the same partial-completion window.
CREATE OR REPLACE FUNCTION public.respond_to_invite(p_membership_id uuid, p_accept boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_org_id uuid;
  v_user_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT organization_id, user_id INTO v_org_id, v_user_id
  FROM public.organization_members
  WHERE id = p_membership_id AND is_active = false;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'No pending invite found';
  END IF;

  IF v_user_id != auth.uid() THEN
    RAISE EXCEPTION 'This invite does not belong to you';
  END IF;

  IF p_accept THEN
    UPDATE public.organization_members
    SET is_active = true, joined_at = now()
    WHERE id = p_membership_id;

    UPDATE public.profiles
    SET account_type = 'fleet_driver', default_org_id = v_org_id
    WHERE id = auth.uid();
  ELSE
    DELETE FROM public.organization_members WHERE id = p_membership_id;
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.respond_to_invite(uuid, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.respond_to_invite(uuid, boolean) TO authenticated;
