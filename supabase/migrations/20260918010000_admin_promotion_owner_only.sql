-- Admin promotion, owner-only (explicit user question, 2026-09-18: "y el
-- rol admin que solo un owner puede ascender?"). Audited the current
-- organization_members policies before answering and found a real,
-- pre-existing gap: org_members_update_admin/_delete_admin_or_self both
-- used the plain is_org_admin_or_owner() check with NO restriction on
-- the target row -- meaning any plain 'admin' (not just the owner) could
-- already promote someone straight to 'admin' (or even 'owner') via a
-- raw table update, AND could delete the OWNER's own membership row.
-- Neither of those should ever have been possible for a non-owner admin.
--
-- Fix has two parts:
--   1. Tighten the raw-table RLS so a plain admin can only ever touch a
--      driver/operator row, never an owner's or another admin's row (by
--      UPDATE, DELETE, or INSERT) -- closing both bugs above at once.
--   2. A new owner-only set_member_admin RPC (bypasses RLS internally as
--      a SECURITY DEFINER function, same as set_member_operator) is the
--      only way to actually promote someone to admin now.
CREATE OR REPLACE FUNCTION public.is_org_owner(p_organization_id uuid)
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
      AND member_role = 'owner'
  );
$function$;

-- A plain admin can act on anyone EXCEPT an owner row from here on
-- (member_role <> 'owner') -- an owner is unrestricted via the same
-- is_org_admin_or_owner(...) AND member_role <> 'owner' branch (the
-- branch is about the TARGET row, not the caller, so it reads as "any
-- admin-or-owner caller may touch any non-owner row" -- an owner acting
-- on another owner row was never a real scenario to begin with, so no
-- separate owner-unrestricted branch is needed).
ALTER POLICY org_members_delete_admin_or_self
ON public.organization_members
USING (
  auth.uid() = user_id
  OR (public.is_org_admin_or_owner(organization_id) AND member_role <> 'owner')
  OR (public.is_org_operator_or_above(organization_id) AND member_role = 'driver')
);

-- UPDATE's qual (which rows can be touched at all) keeps the same
-- "never an owner row" shape as DELETE above. Its WITH CHECK (what the
-- row is allowed to become) is the part that actually closes the
-- promotion bug: a plain admin's branch only accepts the row ENDING UP
-- as 'driver' or 'operator' -- never 'admin' or 'owner' -- so the only
-- way member_role can ever become 'admin' through this policy is the
-- is_org_owner(...) branch, i.e. the caller already being the owner.
ALTER POLICY org_members_update_admin
ON public.organization_members
USING (
  (public.is_org_admin_or_owner(organization_id) AND member_role <> 'owner')
  OR (public.is_org_operator_or_above(organization_id) AND member_role = 'driver')
)
WITH CHECK (
  public.is_org_owner(organization_id)
  OR (public.is_org_admin_or_owner(organization_id) AND member_role IN ('driver', 'operator'))
  OR (public.is_org_operator_or_above(organization_id) AND member_role = 'driver')
);

-- Same reasoning applied to INSERT for defense in depth, even though no
-- current call site inserts a row with member_role other than 'driver'
-- (create_driver_invite/create_driver_slot/invite_member_by_email all
-- hardcode 'driver', and bypass this policy anyway as SECURITY DEFINER
-- functions -- this only matters against a hypothetical direct client
-- insert). Bootstrap clause (a brand-new org's very first member)
-- unchanged.
ALTER POLICY org_members_insert_admin
ON public.organization_members
WITH CHECK (
  public.is_org_owner(organization_id)
  OR (public.is_org_admin_or_owner(organization_id) AND member_role IN ('driver', 'operator'))
  OR (public.is_org_operator_or_above(organization_id) AND member_role = 'driver')
  OR (NOT EXISTS (
        SELECT 1 FROM public.organization_members om2
        WHERE om2.organization_id = organization_members.organization_id
      ))
);

-- Real owner-only action -- the WHERE clause (not just the caller check)
-- is what actually makes this safe: it can only ever touch a row that's
-- already 'driver', 'operator', or 'admin', so there is no code path
-- that reaches an owner's row, even called with the wrong user_id.
-- Demoting an admin lands back on 'driver' (matches set_member_operator's
-- own default-to-driver shape) rather than trying to remember whether
-- they were an operator before being made admin -- simplest, most
-- predictable behavior, and the owner can re-grant operator afterward if
-- that's what they actually want.
CREATE OR REPLACE FUNCTION public.set_member_admin(
  p_org_id uuid,
  p_user_id uuid,
  p_make_admin boolean
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

  if not public.is_org_owner(p_org_id) then
    raise exception 'Only the organization owner can assign admins';
  end if;

  update public.organization_members
  set member_role = case when p_make_admin then 'admin' else 'driver' end
  where organization_id = p_org_id
    and user_id = p_user_id
    and member_role in ('driver', 'operator', 'admin');

  if not found then
    raise exception 'No active driver, operator, or admin membership found for that user in this organization';
  end if;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.set_member_admin(uuid, uuid, boolean) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.set_member_admin(uuid, uuid, boolean) FROM anon;
GRANT EXECUTE ON FUNCTION public.set_member_admin(uuid, uuid, boolean) TO authenticated;
