-- Fleet Phase 2: invite an EXISTING ControlMiles user to join an org as a
-- driver. Deliberately does not support inviting someone who has never
-- signed up -- organization_members.user_id has a hard FK to profiles(id),
-- so there is no row to create until that person has an account. A real,
-- disclosed limitation of this phase, not hidden: the caller finds out
-- immediately via a clear error rather than a silent no-op.
--
-- SECURITY DEFINER is required here for the same reason as
-- create_organization: reading another user's profiles row by email is
-- normally blocked by profiles_select_own RLS, and this function is the
-- one legitimate, narrowly-scoped exception (admin/owner of the target org
-- only, verified explicitly below -- not a general profiles bypass).
CREATE OR REPLACE FUNCTION public.invite_member_by_email(p_org_id uuid, p_email text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_target_id uuid;
  v_target_account_type text;
  v_existing_membership uuid;
  v_membership_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT public.is_org_admin_or_owner(p_org_id) THEN
    RAISE EXCEPTION 'Only an org admin or owner can invite members';
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

REVOKE EXECUTE ON FUNCTION public.invite_member_by_email(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.invite_member_by_email(uuid, text) TO authenticated;
