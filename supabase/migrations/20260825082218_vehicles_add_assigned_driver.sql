-- Fleet Phase 2: a fleet vehicle can be assigned to a specific driver.
-- vehicles_update RLS already allows an org admin/owner to UPDATE any
-- vehicle in their org (is_org_admin_or_owner(organization_id)) -- this
-- column just gives that existing UPDATE right something fleet-specific to
-- write. NULL means unassigned (normal for a newly created fleet vehicle,
-- or a Gig vehicle which never uses this column at all).
ALTER TABLE public.vehicles
  ADD COLUMN assigned_driver_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.vehicles.assigned_driver_id IS
  'Fleet Phase 2: which org member (member_role=driver) this vehicle is currently assigned to. NULL for unassigned fleet vehicles and for all Gig-mode vehicles (owner_user_id is the relevant column there instead).';
