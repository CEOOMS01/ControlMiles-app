-- Fleet Phase 5: v1 geofence = a circle (center + radius), not a polygon --
-- no PostGIS needed, same plain Haversine math this codebase already uses
-- client-side in tracking_controller.dart's _calculateHaversine. Direct
-- table RLS for CRUD (admin/owner only), same pattern as `vehicles` and
-- `organizations` themselves -- no RPC needed here since only admins write
-- these, unlike vehicle_geofence_alerts below which drivers' location
-- updates trigger indirectly.
create table public.vehicle_geofences (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  organization_id uuid not null references public.organizations(id),
  name text not null,
  center_latitude double precision not null,
  center_longitude double precision not null,
  radius_meters double precision not null check (radius_meters > 0),
  is_active boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.vehicle_geofences enable row level security;

create policy vehicle_geofences_select
on public.vehicle_geofences
for select
using (public.is_org_member(organization_id));

create policy vehicle_geofences_insert
on public.vehicle_geofences
for insert
with check (public.is_org_admin_or_owner(organization_id));

create policy vehicle_geofences_update
on public.vehicle_geofences
for update
using (public.is_org_admin_or_owner(organization_id))
with check (public.is_org_admin_or_owner(organization_id));

create policy vehicle_geofences_delete
on public.vehicle_geofences
for delete
using (public.is_org_admin_or_owner(organization_id));

-- Immutable, like vehicle_inspections/audit_events -- only the location-
-- update RPC below can insert an alert, so a violation can never be
-- silently created or forged by a direct client write. Select is
-- admin-only (fleet-wide alert history is a management concern, same
-- precedent as org_members_select_admin), not every driver.
create table public.vehicle_geofence_alerts (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  geofence_id uuid not null references public.vehicle_geofences(id) on delete cascade,
  organization_id uuid not null references public.organizations(id),
  latitude double precision not null,
  longitude double precision not null,
  distance_meters double precision not null,
  created_at timestamptz not null default now()
);

alter table public.vehicle_geofence_alerts enable row level security;

create policy vehicle_geofence_alerts_select
on public.vehicle_geofence_alerts
for select
using (public.is_org_admin_or_owner(organization_id));
