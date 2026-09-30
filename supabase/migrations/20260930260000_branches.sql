-- Branches (explicit user request, 2026-09-30, for a 3-location driving
-- school in Maryland but built for every fleet: Samsara "Tags", Motive /
-- Verizon Connect "Groups" do the same). A fleet has any number of
-- branches; each vehicle belongs to one; each driver has a home branch or
-- "can work at any branch". Vehicle <-> driver assignment is unchanged.
-- The web panel filters by branch (a per-admin selector, not stored).
-- Also: shift schedules become optional per fleet, and a driving school's
-- pre-trip inspection is optional by default (instructors in a school car
-- don't file a daily DVIR -- user request).

create table public.branches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 80),
  address text,
  phone text,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  unique (organization_id, name)
);

alter table public.branches enable row level security;

create policy branches_select on public.branches
for select using (public.is_org_member(organization_id));
create policy branches_insert on public.branches
for insert with check (public.is_org_admin_or_owner(organization_id));
create policy branches_update on public.branches
for update using (public.is_org_admin_or_owner(organization_id))
with check (public.is_org_admin_or_owner(organization_id));
create policy branches_delete on public.branches
for delete using (public.is_org_admin_or_owner(organization_id));

alter table public.vehicles
  add column branch_id uuid references public.branches(id) on delete set null;
alter table public.organization_members
  add column branch_id uuid references public.branches(id) on delete set null,
  add column any_branch boolean not null default false;

create index vehicles_branch_idx on public.vehicles (branch_id) where branch_id is not null;
create index organization_members_branch_idx on public.organization_members (branch_id) where branch_id is not null;

-- Vehicle -> branch (null = no branch).
CREATE OR REPLACE FUNCTION public.set_vehicle_branch(p_vehicle_id uuid, p_branch_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_org uuid;
begin
  select organization_id into v_org from public.vehicles where id = p_vehicle_id;
  if v_org is null or not public.is_org_admin_or_owner(v_org) then
    raise exception 'Not authorized';
  end if;
  if p_branch_id is not null and not exists (
    select 1 from public.branches where id = p_branch_id and organization_id = v_org
  ) then
    raise exception 'That branch belongs to another fleet';
  end if;
  update public.vehicles set branch_id = p_branch_id where id = p_vehicle_id;
end;
$function$;

-- Driver -> home branch, or any branch.
CREATE OR REPLACE FUNCTION public.set_member_branch(
  p_organization_id uuid, p_user_id uuid, p_branch_id uuid, p_any_branch boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not public.is_org_admin_or_owner(p_organization_id) then
    raise exception 'Not authorized';
  end if;
  if p_branch_id is not null and not exists (
    select 1 from public.branches where id = p_branch_id and organization_id = p_organization_id
  ) then
    raise exception 'That branch belongs to another fleet';
  end if;
  update public.organization_members
  set branch_id = case when coalesce(p_any_branch, false) then null else p_branch_id end,
      any_branch = coalesce(p_any_branch, false)
  where organization_id = p_organization_id and user_id = p_user_id;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.set_vehicle_branch(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_vehicle_branch(uuid, uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.set_member_branch(uuid, uuid, uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_member_branch(uuid, uuid, uuid, boolean) TO authenticated;

-- Shift schedules: optional. On for fleets that already scheduled shifts
-- or classes, off otherwise; the Shifts menu shows only when on.
alter table public.organizations add column use_shift_schedules boolean not null default false;
update public.organizations o set use_shift_schedules = true
where exists (select 1 from public.shifts s where s.organization_id = o.id)
   or exists (select 1 from public.shift_blocks b where b.organization_id = o.id);

-- Driving school: pre-trip inspection optional by default.
CREATE OR REPLACE FUNCTION public.fn_profile_requires_pretrip(p text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $function$
  select p in ('general', 'trucking', 'construction', 'passenger');
$function$;
update public.organizations set require_pretrip_inspection = false where industry_template = 'driving_school';
