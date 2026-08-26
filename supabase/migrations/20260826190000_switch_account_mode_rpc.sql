-- Explicit user requirement: switch between Gig/Fleet Admin/Fleet
-- Driver mode on the same account, persisting, for testing -- also a
-- genuinely useful capability for a real hybrid user (a fleet owner
-- who also drives personally sometimes). Validates real underlying
-- membership before allowing the switch -- you can't fake your way
-- into fleet_admin without actually owning an org, or into
-- fleet_driver without an active membership row.
--
-- Real bug caught on the first live test, this file already reflects
-- the corrected version: the first attempt picked the account's
-- FIRST-owned org (by join date) when switching into fleet_admin,
-- which meant an account owning multiple orgs would land on the wrong
-- one after a gig -> fleet_admin round trip. Fixed to prefer the
-- account's CURRENT default_org_id if it's still valid for the target
-- role, only falling back to "first eligible org" if it isn't.
create or replace function public.switch_account_mode(p_mode text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_current_org_id uuid;
  v_org_id uuid;
begin
  if v_caller is null then
    raise exception 'Not authenticated';
  end if;

  if p_mode not in ('gig', 'fleet_admin', 'fleet_driver') then
    raise exception 'Invalid mode';
  end if;

  if p_mode = 'gig' then
    update public.profiles set account_type = 'gig' where id = v_caller;
    return;
  end if;

  select default_org_id into v_current_org_id from public.profiles where id = v_caller;

  if p_mode = 'fleet_admin' then
    select organization_id into v_org_id
    from public.organization_members
    where user_id = v_caller and organization_id = v_current_org_id
      and member_role = 'owner' and is_active = true;

    if v_org_id is null then
      select organization_id into v_org_id
      from public.organization_members
      where user_id = v_caller and member_role = 'owner' and is_active = true
      order by joined_at asc
      limit 1;
    end if;

    if v_org_id is null then
      raise exception 'You do not own a fleet organization yet.';
    end if;

    update public.profiles
    set account_type = 'fleet_admin', default_org_id = v_org_id
    where id = v_caller;
    return;
  end if;

  if p_mode = 'fleet_driver' then
    select organization_id into v_org_id
    from public.organization_members
    where user_id = v_caller and organization_id = v_current_org_id
      and member_role = 'driver' and is_active = true;

    if v_org_id is null then
      select organization_id into v_org_id
      from public.organization_members
      where user_id = v_caller and member_role = 'driver' and is_active = true
      order by joined_at desc
      limit 1;
    end if;

    if v_org_id is null then
      raise exception 'You are not an active driver in any fleet.';
    end if;

    update public.profiles
    set account_type = 'fleet_driver', default_org_id = v_org_id
    where id = v_caller;
    return;
  end if;
end;
$$;

revoke all on function public.switch_account_mode(text) from public;
revoke all on function public.switch_account_mode(text) from anon;
grant execute on function public.switch_account_mode(text) to authenticated;
