-- Fleet Phase 1: atomically creates an organization, makes the caller its
-- owner member, and promotes their profile to fleet_admin -- in that order,
-- inside one transaction. Order matters: tr_enforce_fleet_org (AFTER INSERT
-- OR UPDATE on profiles) rejects any row where account_type is
-- fleet_admin/fleet_driver but the user has no active organization_members
-- row, so the membership row must exist before the profile UPDATE runs.
-- Doing this as three separate client round-trips would leave a real
-- partial-completion window (e.g. org created, then the app crashes before
-- promoting the profile) -- this function makes the whole sequence atomic:
-- one failure anywhere rolls back all of it.
CREATE OR REPLACE FUNCTION public.create_organization(p_name text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_org_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_name IS NULL OR length(trim(p_name)) = 0 THEN
    RAISE EXCEPTION 'Organization name is required';
  END IF;

  INSERT INTO public.organizations (name, created_by)
  VALUES (trim(p_name), auth.uid())
  RETURNING id INTO v_org_id;

  INSERT INTO public.organization_members (organization_id, user_id, member_role, is_active, joined_at)
  VALUES (v_org_id, auth.uid(), 'owner', true, now());

  UPDATE public.profiles
  SET account_type = 'fleet_admin', default_org_id = v_org_id
  WHERE id = auth.uid();

  RETURN v_org_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_organization(text) TO authenticated;
