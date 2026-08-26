-- Fleet Phase 6, piece 1: continuous GPS trail during a fleet trip.
-- Nothing in this codebase has ever stored more than the start/end lat/lng
-- of a section -- not enough resolution to attribute miles to individual
-- states when a route crosses state lines. Fleet-only by design, same
-- boundary as live-location tracking (Phase 5): a Gig driver's personal
-- trips have no IFTA reporting need and no org to report to.
--
-- Direct INSERT (not RPC-gated), unlike most other Fleet writes this
-- session -- this is high-frequency, side-effect-free telemetry (no
-- validation/atomicity need the way submit_vehicle_inspection or
-- update_vehicle_location's geofence check have), so a per-point RPC
-- round-trip would be pure overhead. Matches the existing direct-update
-- pattern tracking_controller.dart already uses for session_sections.
create table public.session_gps_breadcrumbs (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  section_id uuid references public.session_sections(id) on delete cascade,
  organization_id uuid not null references public.organizations(id),
  vehicle_id uuid references public.vehicles(id),
  user_id uuid not null references public.profiles(id),
  latitude double precision not null,
  longitude double precision not null,
  recorded_at timestamptz not null
);

create index session_gps_breadcrumbs_session_idx on public.session_gps_breadcrumbs (session_id, recorded_at);
create index session_gps_breadcrumbs_org_idx on public.session_gps_breadcrumbs (organization_id, recorded_at);

alter table public.session_gps_breadcrumbs enable row level security;

create policy session_gps_breadcrumbs_select
on public.session_gps_breadcrumbs
for select
using (public.is_org_member(organization_id));

create policy session_gps_breadcrumbs_insert
on public.session_gps_breadcrumbs
for insert
with check (user_id = auth.uid() and public.is_org_member(organization_id));
