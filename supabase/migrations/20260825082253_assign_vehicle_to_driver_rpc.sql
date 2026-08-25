-- Fleet Phase 2: admin/owner assigns an org vehicle to a driver. A plain
-- client-side UPDATE would already pass vehicles_update RLS
-- (is_org_admin_or_owner), but this RPC additionally verifies the vehicle
-- and the driver actually belong to the SAME org and that the target is a
-- real active member -- RLS alone wouldn't catch "admin of org A assigns
-- org A's vehicle to a user_id that happens to be a driver in org B".
CREATE OR REPLACE FUNCTION public.assign_vehicle_to_driver(p_vehicle_id uuid, p_driver_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
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

  IF NOT public.is_org_admin_or_owner(v_vehicle_org_id) THEN
    RAISE EXCEPTION 'Only an org admin or owner can assign vehicles';
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

REVOKE EXECUTE ON FUNCTION public.assign_vehicle_to_driver(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assign_vehicle_to_driver(uuid, uuid) TO authenticated;
