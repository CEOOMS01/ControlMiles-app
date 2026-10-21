-- Cross-tenant write guards (audit 2026-10-21, findings 1-6).
-- A signed-in user could write into another company's data because the
-- insert/update policies only checked user_id = auth.uid():
--   1. start a trip on another company's vehicle (and mark it busy);
--   2. move their own open trip into another company;
--   3. add trip sections to another company;
--   4. add activity-log events to another company;
--   5. add maintenance records to another company's vehicle;
--   6. join a company that has no members yet without having created it.
-- Rules below hold for every caller (app, web, service role): the company
-- of a row always comes from the trip or vehicle it belongs to, never from
-- what the client sends. Existing rows already follow them (checked before).
-- Undo: drop the four triggers and their functions, and restore the old
-- org_members_insert_admin policy (script at the end).

-- 1 + 2. Trips: the vehicle must be the driver's own (personal trip) or a
-- vehicle of the trip's company; driver and company never change.
create or replace function public.fn_guard_session_tenant()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare
  v record;
begin
  if tg_op = 'UPDATE' then
    if new.user_id is distinct from old.user_id or new.organization_id is distinct from old.organization_id then
      raise exception 'TRIP_OWNER_LOCKED' using errcode = 'P0001';
    end if;
    if new.vehicle_id is not distinct from old.vehicle_id then
      return new;
    end if;
  end if;

  if new.vehicle_id is not null then
    select owner_user_id, organization_id into v from public.vehicles where id = new.vehicle_id;
    -- coalesce: a company vehicle has no owner_user_id, and a null here
    -- would let the check pass.
    if not found
       or not coalesce((new.organization_id is null and v.owner_user_id = new.user_id)
                       or (new.organization_id is not null and v.organization_id = new.organization_id), false) then
      raise exception 'VEHICLE_NOT_YOURS' using errcode = 'P0001';
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.fn_guard_session_tenant() from public, anon, authenticated;

drop trigger if exists tr_sessions_guard_tenant on public.sessions;
create trigger tr_sessions_guard_tenant
  before insert or update of user_id, organization_id, vehicle_id on public.sessions
  for each row execute function public.fn_guard_session_tenant();

-- 3 + 4. Trip sections and activity-log events take their company from
-- their trip, and the trip must be the same driver's.
create or replace function public.fn_inherit_session_tenant()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare
  s record;
begin
  select user_id, organization_id into s from public.sessions where id = new.session_id;
  if not found or s.user_id is distinct from new.user_id then
    raise exception 'TRIP_NOT_YOURS' using errcode = 'P0001';
  end if;
  new.organization_id := s.organization_id;
  return new;
end $$;
revoke execute on function public.fn_inherit_session_tenant() from public, anon, authenticated;

drop trigger if exists tr_session_sections_inherit_tenant on public.session_sections;
create trigger tr_session_sections_inherit_tenant
  before insert or update of session_id, user_id, organization_id on public.session_sections
  for each row execute function public.fn_inherit_session_tenant();

drop trigger if exists tr_audit_events_inherit_tenant on public.audit_events;
create trigger tr_audit_events_inherit_tenant
  before insert on public.audit_events
  for each row execute function public.fn_inherit_session_tenant();

-- 5. Maintenance: on the user's own vehicle, or on a vehicle of a company
-- where the user is an active member; the company comes from the vehicle.
create or replace function public.fn_guard_maintenance_tenant()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare
  v record;
begin
  select owner_user_id, organization_id into v from public.vehicles where id = new.vehicle_id;
  if not found
     or not (coalesce(v.owner_user_id = new.user_id, false)
             or exists (select 1 from public.organization_members m
                         where m.organization_id = v.organization_id and m.user_id = new.user_id and m.is_active)) then
    raise exception 'VEHICLE_NOT_YOURS' using errcode = 'P0001';
  end if;
  new.organization_id := v.organization_id;
  return new;
end $$;
revoke execute on function public.fn_guard_maintenance_tenant() from public, anon, authenticated;

drop trigger if exists tr_maintenance_guard_tenant on public.vehicle_maintenance_records;
create trigger tr_maintenance_guard_tenant
  before insert or update of vehicle_id, user_id, organization_id on public.vehicle_maintenance_records
  for each row execute function public.fn_guard_maintenance_tenant();

-- 6. The "company has no members yet" branch is only for its creator.
-- The creator can't read the company yet (not a member), so the check
-- goes through a definer helper.
create or replace function public.fn_is_org_creator(p_organization_id uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from public.organizations where id = p_organization_id and created_by = auth.uid());
$$;
revoke execute on function public.fn_is_org_creator(uuid) from public, anon;
grant execute on function public.fn_is_org_creator(uuid) to authenticated;

drop policy if exists org_members_insert_admin on public.organization_members;
create policy org_members_insert_admin on public.organization_members for insert to authenticated
  with check (
    is_org_owner(organization_id)
    or (is_org_admin_or_owner(organization_id) and member_role = any (array['driver', 'operator']))
    or (is_org_operator_or_above(organization_id) and member_role = 'driver')
    or (
      user_id = auth.uid()
      and fn_is_org_creator(organization_id)
      and not exists (select 1 from public.organization_members om2 where om2.organization_id = organization_members.organization_id)
    )
  );

-- Undo (kept for reference):
-- drop trigger tr_sessions_guard_tenant on public.sessions;
-- drop trigger tr_session_sections_inherit_tenant on public.session_sections;
-- drop trigger tr_audit_events_inherit_tenant on public.audit_events;
-- drop trigger tr_maintenance_guard_tenant on public.vehicle_maintenance_records;
-- drop function public.fn_guard_session_tenant(), public.fn_inherit_session_tenant(), public.fn_guard_maintenance_tenant();
-- (drop public.fn_is_org_creator(uuid) after restoring the policy below)
-- drop policy org_members_insert_admin on public.organization_members;
-- create policy org_members_insert_admin on public.organization_members for insert to authenticated
--   with check (is_org_owner(organization_id)
--     or (is_org_admin_or_owner(organization_id) and member_role = any (array['driver', 'operator']))
--     or (is_org_operator_or_above(organization_id) and member_role = 'driver')
--     or (not exists (select 1 from public.organization_members om2 where om2.organization_id = organization_members.organization_id)));
