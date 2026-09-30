-- Shift schedule drives the trip, and owner-operators (explicit user
-- request, 2026-09-30: "que vaya en coordinación shift schedule con los
-- inicios del viaje, y que haya otra opción cuando el driver maneja su
-- propio truck").
--
-- Found live: an admin scheduled driver + vehicle Mon-Fri 8-17 on the
-- Shifts page, but the app only looked at vehicles.assigned_driver_id, so
-- the driver had "no vehicle" and couldn't start. Now the vehicle for a
-- trip is resolved as: fixed assignment -> today's scheduled shift (in
-- the fleet's timezone, from 60 min before its start until its end) ->
-- 'open' mode pick -> the driver's own vehicle when the fleet allows it.
--
-- Also found while checking this: update_vehicle_location only accepted
-- the ASSIGNED driver, so a driver on a scheduled or 'open'-mode vehicle
-- never appeared on the live map (the app swallowed the error).

-- ── 1. Today's shift for the calling driver ──────────────────────────
CREATE OR REPLACE FUNCTION public.my_shift_today(p_organization_id uuid)
RETURNS TABLE(
  shift_id uuid,
  vehicle_id uuid,
  start_time time,
  end_time time,
  status text          -- 'open' (can start now) | 'upcoming' | 'ended'
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_tz text;
  v_now timestamp;
begin
  if not public.is_org_member(p_organization_id) then
    raise exception 'Not authorized for this organization';
  end if;
  select coalesce(timezone, 'America/New_York') into v_tz from public.organizations where id = p_organization_id;
  v_now := now() at time zone v_tz;

  return query
  select s.id, s.vehicle_id, s.start_time, s.end_time,
    case
      when v_now::time >= s.start_time - interval '60 minutes'
       and (v_now::time <= s.end_time or s.end_time <= s.start_time) then 'open'
      when v_now::time < s.start_time - interval '60 minutes' then 'upcoming'
      else 'ended'
    end
  from public.shifts s
  where s.organization_id = p_organization_id
    and s.driver_id = auth.uid()
    and s.is_active
    and s.day_of_week = extract(dow from v_now)::int
  order by
    case
      when v_now::time >= s.start_time - interval '60 minutes'
       and (v_now::time <= s.end_time or s.end_time <= s.start_time) then 0
      when v_now::time < s.start_time then 1
      else 2
    end,
    s.start_time;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.my_shift_today(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.my_shift_today(uuid) TO authenticated;

-- ── 2. Live map: the driver actually driving the vehicle ─────────────
CREATE OR REPLACE FUNCTION public.update_vehicle_location(p_vehicle_id uuid, p_latitude double precision, p_longitude double precision, p_speed double precision DEFAULT NULL::double precision)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_org uuid;
  v_assigned_driver uuid;
  v_authorized boolean;
  v_geofence record;
  v_distance double precision;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select organization_id, assigned_driver_id into v_org, v_assigned_driver
  from public.vehicles
  where id = p_vehicle_id;

  if not found or v_org is null then
    return;
  end if;

  -- Assigned driver, OR whoever has an open trip on this vehicle
  -- (scheduled shift / open mode), OR an admin.
  v_authorized := (v_assigned_driver = auth.uid())
    or exists (
      select 1 from public.sessions s
      where s.vehicle_id = p_vehicle_id and s.user_id = auth.uid() and not coalesce(s.is_closed, false)
    )
    or public.is_org_admin_or_owner(v_org);
  if not v_authorized then
    raise exception 'Not authorized to update this vehicle location';
  end if;

  update public.vehicles
  set last_latitude = p_latitude,
      last_longitude = p_longitude,
      last_speed = p_speed,
      last_location_at = now()
  where id = p_vehicle_id;

  for v_geofence in
    select id, center_latitude, center_longitude, radius_meters
    from public.vehicle_geofences
    where vehicle_id = p_vehicle_id and is_active = true
  loop
    v_distance := 6371000 * acos(
      least(1.0, greatest(-1.0,
        cos(radians(v_geofence.center_latitude)) * cos(radians(p_latitude)) *
          cos(radians(p_longitude) - radians(v_geofence.center_longitude)) +
        sin(radians(v_geofence.center_latitude)) * sin(radians(p_latitude))
      ))
    );

    if v_distance > v_geofence.radius_meters then
      if not exists (
        select 1 from public.vehicle_geofence_alerts
        where vehicle_id = p_vehicle_id
          and geofence_id = v_geofence.id
          and created_at > now() - interval '15 minutes'
      ) then
        insert into public.vehicle_geofence_alerts (
          vehicle_id, geofence_id, organization_id, latitude, longitude, distance_meters
        ) values (
          p_vehicle_id, v_geofence.id, v_org, p_latitude, p_longitude, v_distance
        );
      end if;
    end if;
  end loop;
end;
$function$;

-- ── 3. Owner-operators: the driver's own truck ───────────────────────
-- The fleet turns it on in Settings; then a driver with no company
-- vehicle can register their own in the app. It joins the fleet (same
-- plan vehicle limit), marked driver-owned, assigned to that driver.
alter table public.organizations
  add column allow_driver_owned_vehicles boolean not null default false;
alter table public.vehicles
  add column ownership text not null default 'company' check (ownership in ('company', 'driver_owned'));

CREATE OR REPLACE FUNCTION public.register_my_own_vehicle(
  p_organization_id uuid,
  p_make text,
  p_model text,
  p_year integer DEFAULT NULL,
  p_plate text DEFAULT NULL,
  p_vin text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_id uuid;
  v_allowed boolean;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if not exists (
    select 1 from public.organization_members
    where organization_id = p_organization_id and user_id = auth.uid() and is_active
  ) then
    raise exception 'Not authorized for this organization';
  end if;
  select allow_driver_owned_vehicles into v_allowed from public.organizations where id = p_organization_id;
  if not coalesce(v_allowed, false) then
    raise exception 'Your fleet doesn''t allow drivers to use their own vehicle. Ask your fleet admin.';
  end if;
  if nullif(btrim(p_make), '') is null or nullif(btrim(p_model), '') is null then
    raise exception 'Enter the make and model of your vehicle.';
  end if;
  if p_year is not null and (p_year < 1980 or p_year > extract(year from now())::int + 1) then
    raise exception 'Enter a valid year.';
  end if;
  if exists (
    select 1 from public.vehicles
    where organization_id = p_organization_id and owner_user_id = auth.uid()
      and ownership = 'driver_owned' and not is_archived
  ) then
    raise exception 'You already registered your own vehicle with this fleet.';
  end if;

  insert into public.vehicles (organization_id, owner_user_id, assigned_driver_id, ownership, make, model, year, plate, vin)
  values (p_organization_id, auth.uid(), auth.uid(), 'driver_owned',
          btrim(p_make), btrim(p_model), p_year, nullif(btrim(p_plate), ''), nullif(upper(btrim(p_vin)), ''))
  returning id into v_id;
  return v_id;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.register_my_own_vehicle(uuid, text, text, integer, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_my_own_vehicle(uuid, text, text, integer, text, text) TO authenticated;
