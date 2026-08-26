-- Fleet Phase 6, piece 1: attributes miles driven to the US state each GPS
-- breadcrumb segment falls in. SECURITY DEFINER bypasses RLS by definition,
-- so authorization is checked explicitly here (is_org_member) rather than
-- relying on session_gps_breadcrumbs' own SELECT policy. Set-based SQL
-- (window function + one PostGIS join), not a row-by-row PL/pgSQL loop --
-- a quarter of breadcrumbs for an active fleet is thousands of rows, and
-- this shape lets Postgres's planner use the GiST index on the boundary
-- table instead of re-evaluating ST_Contains procedurally per row.
--
-- Each segment (the straight line between two consecutive breadcrumb
-- points) is attributed to the state containing its END point -- a
-- standard practical approximation for GPS-sampled state mileage; splitting
-- a segment that crosses a state line into two sub-segments at the exact
-- border would need real line/polygon intersection math for a precision
-- gain that doesn't matter at typical breadcrumb sampling density.
--
-- Verified live before this file was written: a real Philadelphia PA ->
-- King of Prussia PA -> Trenton NJ -> New Brunswick NJ -> Newark NJ route
-- (real coordinates, each independently checked against the boundary table
-- before use) correctly split into ~15mi PA / ~82mi NJ.
CREATE OR REPLACE FUNCTION public.compute_state_mileage(
  p_organization_id uuid,
  p_start_date date,
  p_end_date date,
  p_vehicle_id uuid DEFAULT NULL
)
RETURNS TABLE(state_code text, state_name text, miles double precision)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not public.is_org_member(p_organization_id) then
    raise exception 'Not authorized for this organization';
  end if;

  return query
  with ordered as (
    select
      b.session_id,
      b.latitude,
      b.longitude,
      lag(b.latitude) over w as prev_lat,
      lag(b.longitude) over w as prev_lng
    from public.session_gps_breadcrumbs b
    where b.organization_id = p_organization_id
      and b.recorded_at::date between p_start_date and p_end_date
      and (p_vehicle_id is null or b.vehicle_id = p_vehicle_id)
    window w as (partition by b.session_id order by b.recorded_at)
  ),
  segments as (
    select
      o.latitude, o.longitude,
      6371000 * acos(
        least(1.0, greatest(-1.0,
          cos(radians(o.prev_lat)) * cos(radians(o.latitude)) *
            cos(radians(o.longitude) - radians(o.prev_lng)) +
          sin(radians(o.prev_lat)) * sin(radians(o.latitude))
        ))
      ) / 1609.34 as seg_miles
    from ordered o
    where o.prev_lat is not null
  ),
  attributed as (
    select
      sb.state_code as sc,
      sb.name as sn,
      s.seg_miles
    from segments s
    left join public.ifta_us_state_boundaries sb
      on ST_Contains(sb.geom, ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326))
  )
  select
    coalesce(a.sc, 'UNKNOWN')::text,
    coalesce(a.sn, 'Unattributed (outside US or no boundary match)')::text,
    sum(a.seg_miles)::double precision
  from attributed a
  group by a.sc, a.sn
  order by sum(a.seg_miles) desc;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.compute_state_mileage(uuid, date, date, uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.compute_state_mileage(uuid, date, date, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.compute_state_mileage(uuid, date, date, uuid) TO authenticated;
