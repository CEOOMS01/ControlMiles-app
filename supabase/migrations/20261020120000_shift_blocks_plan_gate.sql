-- Editing or removing classes / shift blocks follows the plan, like adding them
-- (2026-10-20). Before, insert checked fn_org_has_classes but update and delete
-- only checked the role, so an org that dropped to a plan without classes or
-- shift schedules could still change its old blocks.

drop policy if exists shift_blocks_update on public.shift_blocks;
create policy shift_blocks_update on public.shift_blocks for update
  using (
    is_org_operator_or_above(organization_id)
    and (fn_org_has_classes(organization_id) or fn_org_has_feature(organization_id, 'shift_schedules'))
  )
  with check (
    is_org_operator_or_above(organization_id)
    and (fn_org_has_classes(organization_id) or fn_org_has_feature(organization_id, 'shift_schedules'))
  );

drop policy if exists shift_blocks_delete on public.shift_blocks;
create policy shift_blocks_delete on public.shift_blocks for delete
  using (
    is_org_operator_or_above(organization_id)
    and status = 'scheduled'
    and (fn_org_has_classes(organization_id) or fn_org_has_feature(organization_id, 'shift_schedules'))
  );
