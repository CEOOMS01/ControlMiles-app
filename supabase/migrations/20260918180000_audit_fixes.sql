-- Fixes from the post-session security/workflow audit (2026-09-18):
--
-- 1. fn_vehicles_set_cycle_anchor was missing SET search_path -- its own
--    sibling in the same migration (fn_odometer_cycle_start) got the
--    hardening, this trigger function didn't. Flagged live by
--    get_advisors(security): function_search_path_mutable. Low blast
--    radius (only calls extract(), a builtin) but should match every
--    other SECURITY DEFINER-adjacent function in this schema.
--
-- 2. fn_odometer_cycle_start had no membership/ownership check of its
--    own -- same shape as the fn_org_effective_tier gap fixed earlier
--    this session (20260918170000). It's only ever called from inside
--    submit_vehicle_odometer_checkpoint, which already authorizes the
--    caller first, but GRANT EXECUTE TO authenticated means PostgREST
--    exposes it directly too. The only thing it leaks is a boundary
--    DATE for a vehicle_id (not itself sensitive), but closing it is
--    free and keeps the pattern consistent.
create or replace function public.fn_vehicles_set_cycle_anchor()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  if new.odometer_cycle_anchor is null then
    new.odometer_cycle_anchor := (new.created_at::date) - (extract(isodow from new.created_at::date)::int - 1);
  end if;
  return new;
end;
$$;

create or replace function public.fn_odometer_cycle_start(p_vehicle_id uuid, p_date date)
returns date
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_vehicle record;
  v_cycle text;
  v_anchor date;
  v_anchor_monday date;
  v_monday date;
  v_days_since_anchor int;
begin
  select * into v_vehicle from public.vehicles where id = p_vehicle_id;
  if v_vehicle is null then
    return null;
  end if;

  -- NULL-safety note (real bug caught live while verifying this exact
  -- fix): a plain `column = auth.uid()` against a nullable column
  -- (assigned_driver_id is null for most vehicles) yields SQL NULL, not
  -- false, when the column is null -- and `false OR NULL OR false`
  -- itself evaluates to NULL. That's harmless inside an RLS USING
  -- clause (NULL is treated as "exclude this row", the safe direction),
  -- which is why the near-identical expression in
  -- vehicle_odometer_checkpoints_select's own USING clause is fine as
  -- written. But `IF NOT (NULL) THEN ...` in PL/pgSQL treats a NULL
  -- condition as false and SKIPS the branch -- the dangerous direction
  -- for an auth check, since it silently let an unauthorized caller
  -- fall through to a real answer instead of being rejected. Using IS
  -- DISTINCT FROM (never NULL) closes it, matching the pattern
  -- submit_vehicle_inspection already uses correctly.
  if v_vehicle.owner_user_id is distinct from auth.uid()
     and v_vehicle.assigned_driver_id is distinct from auth.uid()
     and not (v_vehicle.organization_id is not null and public.is_org_member(v_vehicle.organization_id))
  then
    return null;
  end if;

  v_cycle := coalesce(v_vehicle.odometer_cycle, 'weekly');
  v_anchor := coalesce(
    v_vehicle.odometer_cycle_anchor,
    (v_vehicle.created_at::date) - (extract(isodow from v_vehicle.created_at::date)::int - 1)
  );

  v_monday := p_date - (extract(isodow from p_date)::int - 1);

  if v_cycle = 'weekly' then
    return v_monday;
  elsif v_cycle = 'monthly' then
    return date_trunc('month', p_date)::date;
  else
    v_anchor_monday := v_anchor - (extract(isodow from v_anchor)::int - 1);
    v_days_since_anchor := v_monday - v_anchor_monday;
    return v_anchor_monday + (floor(v_days_since_anchor / 14.0)::int * 14);
  end if;
end;
$$;
