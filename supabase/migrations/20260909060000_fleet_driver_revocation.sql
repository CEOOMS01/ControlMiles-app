-- Fleet Sprint 3 (revocation, explicit user requirement, 2026-09-09): if an
-- admin removes/pauses a driver from the web dashboard, that driver's Fleet
-- access must be cut off, not just cosmetically hidden. Two layers, same
-- convention as every other gate in this project (fn_enforce_trial_or_
-- subscription, fn_enforce_vehicle_count_limit):
--   1. DB trigger -- the real floor. A revoked driver's client, even if
--      modified, cannot insert a new org-scoped session once
--      organization_members.is_active is false.
--   2. Client-side re-check (DriverOperationsScreen, on screen resume/app
--      foreground) -- confirmed with the user as "check-on-next-action",
--      not a persistent Realtime subscription. This is what makes it feel
--      immediate in practice, since foreground is the most common
--      re-entry point.

create or replace function public.remove_driver_from_org(p_org_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_org_admin_or_owner(p_org_id) then
    raise exception 'Only an org admin or owner can remove a driver';
  end if;

  update public.organization_members
  set is_active = false
  where organization_id = p_org_id and user_id = p_user_id and member_role = 'driver';

  if not found then
    raise exception 'No active driver membership found for that user in this organization';
  end if;
end;
$$;

revoke all on function public.remove_driver_from_org(uuid, uuid) from public, anon;
grant execute on function public.remove_driver_from_org(uuid, uuid) to authenticated;

-- The real floor: a client (modified or not) cannot start a new org-scoped
-- trip once membership is revoked, regardless of whether it ever calls
-- the check_active_membership RPC below first.
create or replace function public.fn_enforce_active_org_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_active boolean;
begin
  if new.organization_id is null then
    return new;
  end if;

  select is_active into v_is_active
  from public.organization_members
  where organization_id = new.organization_id and user_id = new.user_id;

  if v_is_active is not true then
    raise exception 'ORG_MEMBERSHIP_REVOKED';
  end if;

  return new;
end;
$$;

drop trigger if exists tr_sessions_enforce_active_org_membership on public.sessions;
create trigger tr_sessions_enforce_active_org_membership
  before insert on public.sessions
  for each row execute function public.fn_enforce_active_org_membership();

-- Lightweight check the client calls on screen resume/app foreground --
-- deliberately a plain boolean read, not a write, so it's cheap enough to
-- call on every resume without a debounce.
create or replace function public.check_active_org_membership(p_org_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (select is_active from public.organization_members
     where organization_id = p_org_id and user_id = auth.uid()),
    false
  );
$$;

revoke all on function public.check_active_org_membership(uuid) from public, anon;
grant execute on function public.check_active_org_membership(uuid) to authenticated;
