-- Live trip-route drawing (explicit user request, 2026-09-20): "que se
-- vea en vivo el dibujo del viaje... esta imagen vivirá solo en el
-- reporte web". session_gps_breadcrumbs (20260826000400) was built
-- Fleet-only for IFTA state-mileage attribution -- organization_id is
-- `not null`, and both RLS policies gate on `is_org_member(organization_id)`.
-- A Gig driver's personal trip has no organization at all, so the table
-- was structurally unusable for them: tracking_controller.dart's own
-- breadcrumb-write block skipped the insert entirely whenever
-- activeOrganizationId was null (i.e. every Gig trip). Extending the
-- feature to Gig (per explicit request, "esto se va a extender a Gig
-- también") requires organization_id to actually be nullable and the RLS
-- policies to allow a null-org row scoped to its own user_id instead.
--
-- Inserts move to a new Edge Function (ingest-gps-breadcrumb) that writes
-- with the service-role key -- RLS is bypassed there by design, same as
-- every other service-role write in this project. The insert policy
-- below is kept correct anyway (defense in depth / any future direct
-- client insert), not because the new function depends on it.

alter table public.session_gps_breadcrumbs
  alter column organization_id drop not null;

drop policy if exists session_gps_breadcrumbs_select on public.session_gps_breadcrumbs;
create policy session_gps_breadcrumbs_select
on public.session_gps_breadcrumbs
for select
using (
  user_id = auth.uid()
  or (organization_id is not null and public.is_org_member(organization_id))
);

drop policy if exists session_gps_breadcrumbs_insert on public.session_gps_breadcrumbs;
create policy session_gps_breadcrumbs_insert
on public.session_gps_breadcrumbs
for insert
with check (
  user_id = auth.uid()
  and (organization_id is null or public.is_org_member(organization_id))
);
