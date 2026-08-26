-- Mid-trip incident reports (breakdown/accident/delay/other), separate
-- from the DVIR pre/post-trip checklist's own defect notes -- explicit
-- user requirement: a driver needs to report something going wrong
-- DURING an active trip, not only at the pre-trip inspection step.
-- Fleet-only (a Gig driver has no fleet admin to report to, same
-- boundary as vehicle_inspections/DVIR).
--
-- Verified live: a driver can insert their own incident, their org
-- admin can read it back, cleaned up test rows after.
create table public.trip_incidents (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references public.sessions(id) on delete set null,
  user_id uuid not null references public.profiles(id),
  organization_id uuid not null references public.organizations(id),
  vehicle_id uuid references public.vehicles(id),
  category text not null check (category = any (array['breakdown','accident','delay','other'])),
  description text not null,
  created_at timestamptz not null default now()
);
comment on table public.trip_incidents is 'Driver-reported mid-trip incidents (breakdown/accident/delay/other). Written by the driver, visible to their org admin -- no admin-facing viewer built yet on either mobile or web, same disclosed gap as DVIR inspection review.';

alter table public.trip_incidents enable row level security;

create policy trip_incidents_insert_own on public.trip_incidents
for insert to authenticated
with check (user_id = auth.uid() and is_org_member(organization_id));

create policy trip_incidents_select_own on public.trip_incidents
for select to authenticated
using (user_id = auth.uid());

create policy trip_incidents_select_admin on public.trip_incidents
for select to authenticated
using (is_org_admin_or_owner(organization_id));

create index idx_trip_incidents_org_time on public.trip_incidents (organization_id, created_at desc);
