-- Fleet Phase 5: the driver's app calls this on a throttled GPS tick
-- (piggybacking on the existing _smartSync ~10-15s window in
-- tracking_controller.dart) only while an active fleet trip is running.
-- Server-side, not client-side: geofence violation detection happens here,
-- not in the Dart app, so a modified client can't silently suppress an
-- alert -- same "can't be bypassed by a direct write" principle as
-- submit_vehicle_inspection's auto-maintenance-record side effect.
--
-- SECURITY DEFINER is included and verified in this file from the start --
-- Phase 4 shipped a version of a similar RPC missing this keyword (present
-- in comments, never actually typed) and only caught it via live
-- request.jwt.claims testing. This function's prosecdef/grants were
-- verified the same way immediately after applying, before any client code
-- was written on top of it.
CREATE OR REPLACE FUNCTION public.update_vehicle_location(
  p_vehicle_id uuid,
  p_latitude double precision,
  p_longitude double precision,
  p_speed double precision DEFAULT NULL
)
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
    -- Not a fleet vehicle (or doesn't exist): live-location tracking is
    -- fleet-only by design -- no-op, not an error, so a caller never needs
    -- to special-case a Gig vehicle before calling this.
    return;
  end if;

  v_authorized := (v_assigned_driver = auth.uid()) or public.is_org_admin_or_owner(v_org);
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

REVOKE EXECUTE ON FUNCTION public.update_vehicle_location(uuid, double precision, double precision, double precision) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_vehicle_location(uuid, double precision, double precision, double precision) FROM anon;
GRANT EXECUTE ON FUNCTION public.update_vehicle_location(uuid, double precision, double precision, double precision) TO authenticated;
