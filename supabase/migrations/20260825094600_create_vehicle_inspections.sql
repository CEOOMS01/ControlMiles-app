-- Fleet Phase 4: DVIR-style pre/post-trip vehicle inspections. v1 scope:
-- checklist submission with pass/fail per category + optional defect
-- photos, immutable once submitted (like audit_events -- no UPDATE/DELETE
-- policy at all, only INSERT via the submit_vehicle_inspection RPC below,
-- which is the only writer so the auto-maintenance-record side effect can
-- never be bypassed by a direct table insert). Does NOT block trip start
-- in v1 -- that integration is a deliberate follow-up, not silently done
-- here.
create table public.vehicle_inspections (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  organization_id uuid references public.organizations(id),
  inspection_type text not null check (inspection_type in ('pre_trip','post_trip')),
  overall_status text not null check (overall_status in ('pass','fail')),
  items jsonb not null default '[]'::jsonb,
  odometer numeric,
  created_at timestamptz not null default now()
);

alter table public.vehicle_inspections enable row level security;

create policy vehicle_inspections_select
on public.vehicle_inspections
for select
using (
  user_id = auth.uid()
  or (organization_id is not null and public.is_org_member(organization_id))
);
