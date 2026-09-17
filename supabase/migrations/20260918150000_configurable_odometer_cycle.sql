-- Configurable odometer checkpoint cycle (explicit user requirement,
-- 2026-09-18, Gig only -- Fleet stays out of scope for this pass): the
-- weekly checkpoint model (20260903120000) was hardcoded to a fixed
-- Mon-Sun calendar week with no other option. This adds weekly/
-- biweekly/monthly per vehicle, defaulting every existing and new
-- vehicle to 'weekly' -- zero behavior change for anyone who doesn't
-- touch the new setting.
--
-- odometer_cycle_anchor only matters for 'biweekly' (weekly and monthly
-- are self-anchoring off the real calendar) -- it's the Monday that
-- starts this vehicle's very first 14-day block. Backfilled from each
-- vehicle's own created_at so an existing vehicle that later switches
-- to biweekly gets a stable, deterministic block boundary instead of
-- one that depends on whenever the switch happened to occur.
alter table public.vehicles
  add column odometer_cycle text not null default 'weekly'
    check (odometer_cycle in ('weekly', 'biweekly', 'monthly')),
  add column odometer_cycle_anchor date;

update public.vehicles
set odometer_cycle_anchor = (created_at::date) - (extract(isodow from created_at::date)::int - 1)
where odometer_cycle_anchor is null;

create or replace function public.fn_vehicles_set_cycle_anchor()
returns trigger
language plpgsql
as $$
begin
  if new.odometer_cycle_anchor is null then
    new.odometer_cycle_anchor := (new.created_at::date) - (extract(isodow from new.created_at::date)::int - 1);
  end if;
  return new;
end;
$$;

drop trigger if exists tr_vehicles_set_cycle_anchor on public.vehicles;
create trigger tr_vehicles_set_cycle_anchor
  before insert on public.vehicles
  for each row execute function public.fn_vehicles_set_cycle_anchor();

-- Single source of truth for "what checkpoint period does this date fall
-- into, for this vehicle" -- used by submit_vehicle_odometer_checkpoint
-- so weekly/biweekly/monthly all funnel through one boundary rule
-- instead of three copy-pasted ones. lib/services/odometer_capture_service.dart's
-- own boundary computation mirrors this exactly (see its header comment)
-- since the client needs to ask "do I need a photo" without a round trip
-- for every check.
create or replace function public.fn_odometer_cycle_start(p_vehicle_id uuid, p_date date)
returns date
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_cycle text;
  v_anchor date;
  v_anchor_monday date;
  v_monday date;
  v_days_since_anchor int;
begin
  select odometer_cycle,
         coalesce(odometer_cycle_anchor, (created_at::date) - (extract(isodow from created_at::date)::int - 1))
    into v_cycle, v_anchor
    from public.vehicles
    where id = p_vehicle_id;

  if v_cycle is null then
    v_cycle := 'weekly';
  end if;

  v_monday := p_date - (extract(isodow from p_date)::int - 1);

  if v_cycle = 'weekly' then
    return v_monday;
  elsif v_cycle = 'monthly' then
    return date_trunc('month', p_date)::date;
  else -- biweekly
    v_anchor_monday := v_anchor - (extract(isodow from v_anchor)::int - 1);
    v_days_since_anchor := v_monday - v_anchor_monday;
    return v_anchor_monday + (floor(v_days_since_anchor / 14.0)::int * 14);
  end if;
end;
$$;

revoke execute on function public.fn_odometer_cycle_start(uuid, date) from public;
revoke execute on function public.fn_odometer_cycle_start(uuid, date) from anon;
grant execute on function public.fn_odometer_cycle_start(uuid, date) to authenticated;

-- Rewritten to compute the boundary via fn_odometer_cycle_start instead
-- of the old hardcoded "always Monday of the ISO week" line -- every
-- other line (floor check, roll-forward, vehicles.odometer propagation)
-- is untouched, since none of that logic was ever week-specific to
-- begin with; it only ever cared about "the boundary date", whatever
-- that resolves to.
create or replace function public.submit_vehicle_odometer_checkpoint(
  p_vehicle_id uuid,
  p_odometer_value numeric,
  p_odometer_image_url text,
  p_file_hash text default null,
  p_ocr_source boolean default false,
  p_ocr_confidence numeric default null,
  p_capture_date date default (timezone('utc', now()))::date
)
returns public.vehicle_odometer_checkpoints
language plpgsql
security definer
set search_path = public
as $$
declare
  v_vehicle record;
  v_caller uuid := auth.uid();
  v_week_start date;
  v_prev_open record;
  v_prev_open_found boolean;
  v_current record;
  v_result public.vehicle_odometer_checkpoints;
begin
  if v_caller is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_odometer_value is null or p_odometer_value < 0 then
    raise exception 'INVALID_ODOMETER_VALUE';
  end if;

  select * into v_vehicle from public.vehicles where id = p_vehicle_id;
  if v_vehicle is null then
    raise exception 'VEHICLE_NOT_FOUND';
  end if;

  if not (
    v_vehicle.owner_user_id = v_caller
    or v_vehicle.assigned_driver_id = v_caller
    or (v_vehicle.organization_id is not null and public.is_org_member(v_vehicle.organization_id))
  ) then
    raise exception 'NOT_AUTHORIZED';
  end if;

  if v_vehicle.odometer is not null and p_odometer_value < v_vehicle.odometer then
    raise exception 'ODOMETER_BELOW_REGISTERED:%', v_vehicle.odometer;
  end if;

  v_week_start := public.fn_odometer_cycle_start(p_vehicle_id, p_capture_date);

  select * into v_prev_open
  from public.vehicle_odometer_checkpoints
  where vehicle_id = p_vehicle_id
    and week_start_date < v_week_start
    and start_odometer_value is not null
    and end_odometer_value is null
  order by week_start_date desc
  limit 1;
  v_prev_open_found := found;

  if v_prev_open_found then
    update public.vehicle_odometer_checkpoints
    set end_odometer_value = p_odometer_value,
        end_odometer_image_url = p_odometer_image_url,
        end_file_hash = p_file_hash,
        end_captured_by = v_caller,
        end_captured_at = now(),
        end_ocr_source = p_ocr_source,
        end_ocr_confidence = p_ocr_confidence,
        updated_at = now()
    where id = v_prev_open.id;
  end if;

  select * into v_current
  from public.vehicle_odometer_checkpoints
  where vehicle_id = p_vehicle_id and week_start_date = v_week_start;

  if v_current is null then
    insert into public.vehicle_odometer_checkpoints (
      vehicle_id, organization_id, week_start_date,
      start_odometer_value, start_odometer_image_url, start_file_hash,
      start_captured_by, start_captured_at, start_ocr_source, start_ocr_confidence
    ) values (
      p_vehicle_id, v_vehicle.organization_id, v_week_start,
      p_odometer_value, p_odometer_image_url, p_file_hash,
      v_caller, now(), p_ocr_source, p_ocr_confidence
    )
    returning * into v_result;
  elsif v_current.start_odometer_value is null then
    update public.vehicle_odometer_checkpoints
    set start_odometer_value = p_odometer_value,
        start_odometer_image_url = p_odometer_image_url,
        start_file_hash = p_file_hash,
        start_captured_by = v_caller,
        start_captured_at = now(),
        start_ocr_source = p_ocr_source,
        start_ocr_confidence = p_ocr_confidence,
        updated_at = now()
    where id = v_current.id
    returning * into v_result;
  elsif v_current.end_odometer_value is null then
    update public.vehicle_odometer_checkpoints
    set end_odometer_value = p_odometer_value,
        end_odometer_image_url = p_odometer_image_url,
        end_file_hash = p_file_hash,
        end_captured_by = v_caller,
        end_captured_at = now(),
        end_ocr_source = p_ocr_source,
        end_ocr_confidence = p_ocr_confidence,
        updated_at = now()
    where id = v_current.id
    returning * into v_result;
  else
    raise exception 'WEEK_ALREADY_CLOSED';
  end if;

  update public.vehicles
  set odometer = greatest(coalesce(odometer, 0), p_odometer_value),
      updated_at = now()
  where id = p_vehicle_id;

  return v_result;
end;
$$;
