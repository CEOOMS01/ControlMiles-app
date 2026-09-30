-- Idle time (explicit user request, 2026-09-30: next item after fuel
-- alerts -- idling is wasted fuel, one of the first things fleets ask
-- for; Control IMS/Motive/Samsara all report it).
--
-- Those products read "engine on + speed 0" from the engine computer.
-- ControlMiles has no engine data, so an idle event here is "stopped
-- while a trip is running", read from the GPS trail: the app sends a
-- breadcrumb at most every 60 s and only when the phone moves (10 m
-- distance filter), so a stop shows up as two consecutive breadcrumbs of
-- the same trip section far apart in time but close in space. Calibrated
-- on the real trails before writing this: gaps >= 3 min had a median of
-- ~25 m between the two points; the rare big-distance gaps are GPS loss
-- while moving, excluded by the 200 m cap. A section change means the
-- driver paused the trip -- never counted.
--   idle       3-60 min stopped (a >= 4 min gap minus the 60 s
--              sampling): traffic, waiting, loading, engine likely
--              running -- this is what's costed
--   long_stop  60+ min stopped with the trip still running (likely
--              parked) -- shown apart, not costed, so it can't inflate
--              the idle number
CREATE OR REPLACE FUNCTION public.compute_idle_events(
  p_organization_id uuid,
  p_start_date date,
  p_end_date date
)
RETURNS TABLE(
  session_id uuid,
  vehicle_id uuid,
  user_id uuid,
  started_at timestamptz,
  minutes double precision,
  latitude double precision,
  longitude double precision,
  kind text
)
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
  with o as (
    select
      b.session_id as sid, b.section_id as sec, b.vehicle_id as vid, b.user_id as uid,
      b.recorded_at, b.latitude as lat, b.longitude as lng,
      lag(b.recorded_at) over w as prev_at,
      lag(b.latitude) over w as prev_lat,
      lag(b.longitude) over w as prev_lng,
      lag(b.section_id) over w as prev_sec
    from public.session_gps_breadcrumbs b
    where b.organization_id = p_organization_id
      and b.recorded_at >= p_start_date::timestamptz
      and b.recorded_at < (p_end_date + 1)::timestamptz
    window w as (partition by b.session_id order by b.recorded_at)
  ),
  stops as (
    select
      o.sid, o.vid, o.uid, o.prev_at, o.prev_lat, o.prev_lng,
      -- The sampling interval itself (60 s) isn't stopped time.
      (extract(epoch from o.recorded_at - o.prev_at) - 60) / 60.0 as mins
    from o
    where o.prev_at is not null
      and o.sec is not distinct from o.prev_sec
      and o.recorded_at - o.prev_at >= interval '4 minutes'
      and ST_DistanceSphere(ST_MakePoint(o.lng, o.lat), ST_MakePoint(o.prev_lng, o.prev_lat)) <= 200
  )
  select s.sid, s.vid, s.uid, s.prev_at, s.mins::double precision, s.prev_lat, s.prev_lng,
         case when s.mins >= 60 then 'long_stop' else 'idle' end
  from stops s
  where s.mins >= 3
  order by s.prev_at;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.compute_idle_events(uuid, date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.compute_idle_events(uuid, date, date) TO authenticated;
