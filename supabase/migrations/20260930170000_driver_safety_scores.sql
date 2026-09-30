-- Driver safety score (explicit user request, 2026-09-30, after idle
-- time -- from the Control IMS review: "driver behavior", and the
-- scorecard Samsara and Motive both lead with).
--
-- Same shape as theirs: a 0-100 score from WEIGHTED events per distance,
-- so a driver who drives a lot isn't punished for having more raw events
-- than one who barely drives:
--   points  = 3 x harsh braking + 2 x hard acceleration + 5 x speeding
--   score   = 100 - points per 100 miles  (floored at 0)
-- e.g. 400 mi with 2 harsh brakings and 1 speeding = 11 pts = 2.75 per
-- 100 mi -> 97. Under 20 mi in the period there's too little driving to
-- rate: score is null ("not enough driving").
-- The events are the ones the app already logs (driver_safety_monitor.
-- dart): harsh braking / hard acceleration at +-3.5 m/s^2, speeding when
-- over ~75 mph or 10% over a known posted limit.

CREATE OR REPLACE FUNCTION public.fn_safety_score(p_points numeric, p_miles numeric)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $function$
  select case when p_miles is null or p_miles < 20 then null
              else greatest(0, round(100 - p_points * 100 / p_miles)) end;
$function$;

-- One row per driver for the whole range, or per driver per week when
-- p_bucket = 'week' (for the trend). Owners/admins see every driver of
-- the fleet; anyone else only gets their own rows (the driver's own
-- score in the app).
CREATE OR REPLACE FUNCTION public.driver_safety_scores(
  p_organization_id uuid,
  p_start_date date,
  p_end_date date,
  p_bucket text DEFAULT NULL
)
RETURNS TABLE(
  user_id uuid,
  bucket_start date,
  miles numeric,
  trips integer,
  harsh_braking integer,
  hard_acceleration integer,
  speeding integer,
  points integer,
  score numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_admin boolean;
begin
  if not public.is_org_member(p_organization_id) then
    raise exception 'Not authorized for this organization';
  end if;
  if p_bucket is not null and p_bucket <> 'week' then
    raise exception 'Unknown bucket: %', p_bucket;
  end if;
  v_admin := public.is_org_admin_or_owner(p_organization_id);

  return query
  with trips as (
    select s.user_id as uid,
           case when p_bucket = 'week' then date_trunc('week', s.date_key)::date else p_start_date end as b,
           sum(coalesce(s.total_miles, 0))::numeric as mi,
           count(*)::int as n
    from public.sessions s
    where s.organization_id = p_organization_id
      and s.date_key between p_start_date and p_end_date
      and (v_admin or s.user_id = auth.uid())
    group by 1, 2
  ),
  events as (
    select e.user_id as uid,
           case when p_bucket = 'week' then date_trunc('week', e.recorded_at)::date else p_start_date end as b,
           count(*) filter (where e.event_type = 'harsh_braking')::int as hb,
           count(*) filter (where e.event_type = 'hard_acceleration')::int as ha,
           count(*) filter (where e.event_type = 'speeding')::int as sp
    from public.driver_safety_events e
    where e.organization_id = p_organization_id
      and e.recorded_at >= p_start_date::timestamptz
      and e.recorded_at < (p_end_date + 1)::timestamptz
      and (v_admin or e.user_id = auth.uid())
    group by 1, 2
  )
  select
    coalesce(t.uid, ev.uid),
    coalesce(t.b, ev.b),
    round(coalesce(t.mi, 0), 1),
    coalesce(t.n, 0),
    coalesce(ev.hb, 0),
    coalesce(ev.ha, 0),
    coalesce(ev.sp, 0),
    (3 * coalesce(ev.hb, 0) + 2 * coalesce(ev.ha, 0) + 5 * coalesce(ev.sp, 0)),
    public.fn_safety_score(3 * coalesce(ev.hb, 0) + 2 * coalesce(ev.ha, 0) + 5 * coalesce(ev.sp, 0), t.mi)
  from trips t
  full join events ev on ev.uid = t.uid and ev.b = t.b
  order by 1, 2;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.driver_safety_scores(uuid, date, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.driver_safety_scores(uuid, date, date, text) TO authenticated;

-- Speeds up the per-driver event rollup.
create index if not exists driver_safety_events_org_time_idx
  on public.driver_safety_events (organization_id, recorded_at);
