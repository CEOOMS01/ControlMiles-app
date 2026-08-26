-- Explicit user requirement: a fleet driver must never see another
-- driver's inspection history -- only (a) their own past submissions,
-- and (b) the SINGLE most recent inspection for the vehicle they're
-- currently assigned to (so they can check what the last driver
-- reported before their own shift), never that vehicle's older
-- history. Org admin keeps full visibility (already built for
-- controlmiles-web's /admin/reviews).
--
-- Real bug caught live the first time this was applied: a
-- self-referencing subquery inside an RLS USING clause on the SAME
-- table caused infinite recursion (Postgres re-evaluates the policy
-- for the subquery's own access). Fixed with a SECURITY DEFINER
-- function, which bypasses RLS internally and breaks the recursion --
-- this file already reflects the corrected version.
create or replace function public.fn_latest_inspection_id(p_vehicle_id uuid)
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select id from public.vehicle_inspections
  where vehicle_id = p_vehicle_id
  order by created_at desc
  limit 1;
$$;

revoke all on function public.fn_latest_inspection_id(uuid) from public;
revoke all on function public.fn_latest_inspection_id(uuid) from anon;
grant execute on function public.fn_latest_inspection_id(uuid) to authenticated;

drop policy vehicle_inspections_select on public.vehicle_inspections;

create policy vehicle_inspections_select_own on public.vehicle_inspections
for select to authenticated
using (user_id = auth.uid());

create policy vehicle_inspections_select_assigned_vehicle_latest on public.vehicle_inspections
for select to authenticated
using (
  vehicle_id in (select id from public.vehicles where assigned_driver_id = auth.uid())
  and id = public.fn_latest_inspection_id(vehicle_id)
);

create policy vehicle_inspections_select_admin on public.vehicle_inspections
for select to authenticated
using (organization_id is not null and is_org_admin_or_owner(organization_id));
