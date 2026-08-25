-- Fleet Phase 4: vehicle_maintenance_records was purely user_id-scoped, no
-- org visibility at all (unlike vehicles/sessions/session_sections). DVIR
-- failures auto-create a maintenance record that a fleet admin needs to be
-- able to see -- same gap Phase 3 found and fixed on session_sections.
alter table public.vehicle_maintenance_records
  add column organization_id uuid references public.organizations(id);

create policy vehicle_maintenance_records_select_org_admin
on public.vehicle_maintenance_records
for select
using (organization_id is not null and public.is_org_admin_or_owner(organization_id));
