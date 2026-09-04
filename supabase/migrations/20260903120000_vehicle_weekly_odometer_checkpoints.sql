-- Weekly odometer checkpoint model (explicit user request): odometer photo
-- evidence moves from "every session" to a fixed Mon-Sun calendar week per
-- vehicle. Whatever day the driver actually starts capturing in a given
-- week becomes that week's "start" reading; if the week closes (Sunday)
-- without a closing photo, the NEXT capture -- whenever it happens, e.g.
-- the following Monday -- both closes the still-open previous week AND
-- opens the new one, in the same photo/value. This is exactly the roll-
-- forward rule the user described.
--
-- Same "no INSERT/UPDATE policy, SECURITY DEFINER RPC is the only writer"
-- pattern already established for vehicle_inspections (Fleet Phase 4) --
-- makes the roll-forward + floor-check side effects impossible to bypass
-- via a direct table write.
create table public.vehicle_odometer_checkpoints (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  organization_id uuid references public.organizations(id),
  week_start_date date not null, -- Monday (ISO) of the calendar week this checkpoint covers

  start_odometer_value numeric,
  start_odometer_image_url text,
  start_file_hash text,
  start_captured_by uuid references auth.users(id),
  start_captured_at timestamptz,
  start_ocr_source boolean,
  start_ocr_confidence numeric,

  end_odometer_value numeric,
  end_odometer_image_url text,
  end_file_hash text,
  end_captured_by uuid references auth.users(id),
  end_captured_at timestamptz,
  end_ocr_source boolean,
  end_ocr_confidence numeric,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (vehicle_id, week_start_date),
  check (
    start_odometer_value is null or end_odometer_value is null
    or end_odometer_value >= start_odometer_value
  )
);

alter table public.vehicle_odometer_checkpoints enable row level security;

create policy vehicle_odometer_checkpoints_select
on public.vehicle_odometer_checkpoints
for select
using (
  exists (
    select 1 from public.vehicles v
    where v.id = vehicle_odometer_checkpoints.vehicle_id
      and (
        v.owner_user_id = auth.uid()
        or v.assigned_driver_id = auth.uid()
        or (v.organization_id is not null and public.is_org_member(v.organization_id))
      )
  )
);
-- Deliberately no insert/update/delete policy -- see header comment.

revoke all on public.vehicle_odometer_checkpoints from public, anon;
grant select on public.vehicle_odometer_checkpoints to authenticated;

-- ============================================================
-- submit_vehicle_odometer_checkpoint
-- ============================================================
-- Single write path for a weekly odometer capture (photo already uploaded
-- to Storage by the client; this call records the reading). Enforces two
-- things server-side, not just in the Flutter UI, per explicit user
-- request ("nunca pase un odometro con menos millas que lo registrado"):
--   1. p_odometer_value can never be lower than vehicles.odometer already
--      on file for this vehicle -- covers the manual-entry fallback path
--      (OCR failure) just as much as a real OCR read, since both funnel
--      through this same RPC.
--   2. The DB check constraint above additionally guarantees a week's own
--      end reading is never lower than that same week's start reading.
-- Also fixes the separate, real "vehicles.odometer never updates" bug:
-- every accepted checkpoint propagates forward onto vehicles.odometer.
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

  -- The floor: never below what ControlMiles already has on record for
  -- this vehicle, regardless of OCR vs manual entry.
  if v_vehicle.odometer is not null and p_odometer_value < v_vehicle.odometer then
    raise exception 'ODOMETER_BELOW_REGISTERED:%', v_vehicle.odometer;
  end if;

  -- Monday (isodow=1) of the ISO week containing p_capture_date.
  v_week_start := p_capture_date - (extract(isodow from p_capture_date)::int - 1);

  -- Roll-forward: close the most recent earlier week that was started but
  -- never closed, using this same reading/photo as its end.
  select * into v_prev_open
  from public.vehicle_odometer_checkpoints
  where vehicle_id = p_vehicle_id
    and week_start_date < v_week_start
    and start_odometer_value is not null
    and end_odometer_value is null
  order by week_start_date desc
  limit 1;
  -- BUG FIX (caught live, before this ever reached the client): a RECORD
  -- variable's "IS NOT NULL" in plpgsql requires EVERY field to be
  -- non-null, not just "a row was found" -- an open week's own
  -- end_odometer_value is null BY DEFINITION, so "v_prev_open IS NOT NULL"
  -- silently evaluated false even when a real open week was found, and the
  -- roll-forward close never happened. FOUND (set immediately after the
  -- SELECT INTO, before anything else can overwrite it) is the correct
  -- "did a row come back" check for a composite-type record.
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

  -- Fix: vehicles.odometer used to be written once at vehicle creation and
  -- never touched again. GREATEST is defense-in-depth (the floor check
  -- above already guarantees p_odometer_value >= v_vehicle.odometer).
  update public.vehicles
  set odometer = greatest(coalesce(odometer, 0), p_odometer_value),
      updated_at = now()
  where id = p_vehicle_id;

  return v_result;
end;
$$;

revoke execute on function public.submit_vehicle_odometer_checkpoint(uuid, numeric, text, text, boolean, numeric, date) from public;
revoke execute on function public.submit_vehicle_odometer_checkpoint(uuid, numeric, text, text, boolean, numeric, date) from anon;
grant execute on function public.submit_vehicle_odometer_checkpoint(uuid, numeric, text, text, boolean, numeric, date) to authenticated;
