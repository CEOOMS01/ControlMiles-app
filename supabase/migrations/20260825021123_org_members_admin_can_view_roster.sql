-- Fleet Phase 1: org_members_select_own (existing) only ever let a member
-- see their OWN row -- an org admin/owner had no way to list their own
-- roster, a hard blocker for the Fleet Dashboard. This is an ADDITIONAL
-- permissive SELECT policy (Postgres OR's multiple permissive policies for
-- the same command together), so it only ever widens access for
-- admins/owners -- org_members_select_own keeps working unchanged for
-- everyone else.
CREATE POLICY org_members_select_admin ON public.organization_members
  FOR SELECT TO authenticated
  USING (is_org_admin_or_owner(organization_id));
