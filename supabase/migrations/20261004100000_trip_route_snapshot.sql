-- Trip route snapshot (2026-10-04, user request): a light "photo" of each
-- trip's route instead of shipping raw GPS points around.
--
-- Research: Strava stores an encoded polyline per activity (a low-res
-- summary_polyline for lists, the full one only for detail); Everlance puts
-- a static map image of each trip in its PDF exports; Douglas-Peucker
-- simplification is the usual way to store fleet traces for display (never
-- for measuring -- miles stay what the app measured).
--
-- Here:
-- * session_sections.route_polyline: the app uploads each gig-app
--   segment's route, simplified (Douglas-Peucker) and encoded (Google
--   polyline, 1e-5), once, when the segment closes -- ~0.5-2 KB per trip
--   instead of one breadcrumb row per minute. Writable once on a closed
--   section (the app may upload after the close, e.g. offline).
-- * sessions.map_token: random capability token. The web renders
--   /api/trip-map/<session>/<token> (streets from our own basemap + the
--   route, one color per gig app) and caches it forever once the trip is
--   closed. Whoever can read the session (driver, fleet admins) or holds a
--   report that includes it can build the URL; nobody can guess it.
-- * get_trip_map(): the only way the image endpoint reads a route (anon,
--   token-checked). Trips without a polyline (older ones, or the app died
--   before uploading) fall back to their breadcrumbs.
-- * generate_report_access_code: route_points no longer copies every
--   breadcrumb into each report's metadata -- it lists the trips with their
--   map_token, and the portal shows one image per trip.

alter table public.session_sections add column if not exists route_polyline text;
alter table public.session_sections drop constraint if exists session_sections_route_polyline_len;
alter table public.session_sections add constraint session_sections_route_polyline_len
  check (route_polyline is null or length(route_polyline) <= 20000);

alter table public.sessions add column if not exists map_token uuid not null default gen_random_uuid();

create or replace function public.fn_freeze_closed_session_section()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  if OLD.section_status = 'closed' then
    if NEW.total_miles is distinct from OLD.total_miles
      or NEW.total_duration_seconds is distinct from OLD.total_duration_seconds
      or NEW.start_time is distinct from OLD.start_time
      or NEW.end_time is distinct from OLD.end_time
      or NEW.gig_app is distinct from OLD.gig_app
      or NEW.irs_purpose is distinct from OLD.irs_purpose
      or NEW.start_latitude is distinct from OLD.start_latitude
      or NEW.start_longitude is distinct from OLD.start_longitude
      or NEW.end_latitude is distinct from OLD.end_latitude
      or NEW.end_longitude is distinct from OLD.end_longitude
      or NEW.session_id is distinct from OLD.session_id
      or NEW.user_id is distinct from OLD.user_id
      or NEW.organization_id is distinct from OLD.organization_id
      -- the route drawing can be filled once after the close, never replaced
      or (OLD.route_polyline is not null and NEW.route_polyline is distinct from OLD.route_polyline)
    then
      raise exception 'Cannot modify a closed trip section''s recorded data';
    end if;
  end if;
  return NEW;
end;
$$;

create or replace function public.get_trip_map(p_session_id uuid, p_token uuid)
returns jsonb
language sql
stable
security definer
set search_path to 'public'
as $$
  select jsonb_build_object(
    -- 'final' = the image can be cached forever: the trip is closed and
    -- every segment's route arrived (or the app had an hour to send it).
    'closed', coalesce(s.is_closed, false)
      and (not exists (select 1 from public.session_sections x
                        where x.session_id = s.id and x.route_polyline is null)
           or coalesce(s.end_time, s.updated_at) < now() - interval '1 hour'),
    'sections', coalesce((
      select jsonb_agg(jsonb_build_object(
        'gig_app', ss.gig_app,
        'polyline', ss.route_polyline,
        'points', case when ss.route_polyline is null then (
            select jsonb_agg(jsonb_build_array(round(b.latitude::numeric, 5), round(b.longitude::numeric, 5))
                             order by b.recorded_at)
              from public.session_gps_breadcrumbs b
             where b.section_id = ss.id
          ) end,
        'start', case when ss.start_latitude is not null
          then jsonb_build_array(ss.start_latitude, ss.start_longitude) end,
        'end', case when ss.end_latitude is not null
          then jsonb_build_array(ss.end_latitude, ss.end_longitude) end
      ) order by ss.start_time)
      from public.session_sections ss
      where ss.session_id = s.id
    ), '[]'::jsonb)
  )
  from public.sessions s
  where s.id = p_session_id and s.map_token = p_token;
$$;

revoke execute on function public.get_trip_map(uuid, uuid) from public;
grant execute on function public.get_trip_map(uuid, uuid) to anon, authenticated;

-- Report Portal: route_points lists each trip's map (session + map_token)
-- instead of copying its breadcrumbs. Everything else is unchanged from
-- the live definition (20260929150000_report_filter_uses_section_miles).
create or replace function public.generate_report_access_code(
  p_start_date date, p_end_date date, p_vehicle_id uuid default null,
  p_weekly_checkpoints jsonb default '[]'::jsonb, p_target_user_id uuid default null
)
returns table(code text, expires_at timestamp with time zone)
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $$
declare
  v_caller uuid := auth.uid();
  v_user_id uuid;
  v_organization_id uuid;
  v_recent_count int;
  v_plain_code text;
  v_alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_expires timestamptz := now() + interval '15 minutes';
  v_metadata jsonb;
  v_deduction numeric;
  i int;
begin
  if v_caller is null then
    raise exception 'Authentication required';
  end if;

  if p_target_user_id is null or p_target_user_id = v_caller then
    v_user_id := v_caller;
  else
    select caller_m.organization_id into v_organization_id
    from public.organization_members caller_m
    join public.organization_members target_m
      on target_m.organization_id = caller_m.organization_id
    where caller_m.user_id = v_caller
      and caller_m.member_role in ('owner', 'admin')
      and caller_m.is_active = true
      and target_m.user_id = p_target_user_id
      and target_m.is_active = true
    limit 1;

    if v_organization_id is null then
      raise exception 'Not authorized to generate a report for that driver';
    end if;

    if public.fn_org_effective_tier(v_organization_id) = 'none' then
      raise exception 'FLEET_SUBSCRIPTION_REQUIRED';
    end if;

    v_user_id := p_target_user_id;
  end if;

  if p_end_date < p_start_date then
    raise exception 'Invalid date range';
  end if;

  select count(*) into v_recent_count
  from public.reports
  where generated_by = v_caller
    and generated_at > now() - interval '1 hour';

  if v_recent_count >= 5 then
    raise exception 'Too many report codes generated recently. Try again later.';
  end if;

  select coalesce(sum(
    case when s.date_key < date '2026-07-01'
      then s.total_miles * 72.5 / 100.0
      else s.total_miles * 76.0 / 100.0
    end
  ), 0) into v_deduction
  from public.sessions s
  where s.user_id = v_user_id
    and s.date_key between p_start_date and p_end_date
    and (p_vehicle_id is null or s.vehicle_id = p_vehicle_id)
      and (coalesce(s.total_miles, 0) >= 0.05
           or exists (select 1 from public.session_sections x
                      where x.session_id = s.id and x.total_miles >= 0.05));

  with vehicles_in_range as (
    select distinct v.id, v.nickname, v.make, v.model, v.year, v.plate
    from public.sessions s
    join public.vehicles v on v.id = s.vehicle_id
    where s.user_id = v_user_id
      and s.date_key between p_start_date and p_end_date
      and (p_vehicle_id is null or s.vehicle_id = p_vehicle_id)
      and (coalesce(s.total_miles, 0) >= 0.05
           or exists (select 1 from public.session_sections x
                      where x.session_id = s.id and x.total_miles >= 0.05))
  ),
  purpose_breakdown as (
    select
      ss.gig_app,
      ss.irs_purpose,
      sum(ss.total_miles) as miles
    from public.session_sections ss
    join public.sessions s on s.id = ss.session_id
    where s.user_id = v_user_id
      and s.date_key between p_start_date and p_end_date
      and (p_vehicle_id is null or s.vehicle_id = p_vehicle_id)
      and (coalesce(s.total_miles, 0) >= 0.05
           or exists (select 1 from public.session_sections x
                      where x.session_id = s.id and x.total_miles >= 0.05))
    group by ss.gig_app, ss.irs_purpose
  ),
  totals as (
    select
      coalesce(sum(s.total_miles), 0) as total_miles,
      count(distinct s.id) as total_sessions
    from public.sessions s
    where s.user_id = v_user_id
      and s.date_key between p_start_date and p_end_date
      and (p_vehicle_id is null or s.vehicle_id = p_vehicle_id)
      and (coalesce(s.total_miles, 0) >= 0.05
           or exists (select 1 from public.session_sections x
                      where x.session_id = s.id and x.total_miles >= 0.05))
  ),
  sessions_in_range as (
    select s.id, s.date_key, s.total_miles, s.start_time, s.end_time, s.map_token,
           case when s.total_duration_seconds > 0 then s.total_duration_seconds
                when s.start_time is not null and s.end_time is not null
                  then extract(epoch from (s.end_time - s.start_time))::int
           end as effective_duration_seconds, s.start_odometer_value, s.end_odometer_value
    from public.sessions s
    where s.user_id = v_user_id
      and s.date_key between p_start_date and p_end_date
      and (p_vehicle_id is null or s.vehicle_id = p_vehicle_id)
      and (coalesce(s.total_miles, 0) >= 0.05
           or exists (select 1 from public.session_sections x
                      where x.session_id = s.id and x.total_miles >= 0.05))
  ),
  trip_apps as (
    select
      ss.session_id,
      string_agg(
        upper(ss.gig_app) ||
          case when ss.irs_purpose is not null and ss.irs_purpose <> ''
               then ' (' || ss.irs_purpose || ')'
               else '' end,
        ' / ' order by ss.start_time
      ) as apps_label
    from public.session_sections ss
    join sessions_in_range sir on sir.id = ss.session_id
    group by ss.session_id
  ),
  route_points as (
    select sir.id as session_id, sir.date_key, sir.start_time, sir.total_miles, sir.map_token
    from sessions_in_range sir
    where exists (
            select 1 from public.session_sections ss
             where ss.session_id = sir.id
               and (ss.route_polyline is not null
                    or (ss.start_latitude is not null and ss.end_latitude is not null))
          )
       or (select count(*) from public.session_gps_breadcrumbs b where b.session_id = sir.id) >= 2
  )
  select jsonb_build_object(
    'driver_display_name', p.full_name,
    'driver_display_id', p.display_id,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'generated_at', now(),
    'total_miles', t.total_miles,
    'total_sessions', t.total_sessions,
    'total_deduction_estimate', v_deduction,
    'vehicles', coalesce((select jsonb_agg(jsonb_build_object(
        'nickname', vr.nickname, 'make', vr.make, 'model', vr.model,
        'year', vr.year, 'plate', vr.plate
      )) from vehicles_in_range vr), '[]'::jsonb),
    'gig_app_breakdown', coalesce((select jsonb_agg(jsonb_build_object(
        'gig_app', pb.gig_app, 'irs_purpose', pb.irs_purpose, 'miles', pb.miles
      )) from purpose_breakdown pb), '[]'::jsonb),
    'trips', coalesce((select jsonb_agg(jsonb_build_object(
        'date_key', sir.date_key,
        'apps_label', coalesce(ta.apps_label, ''),
        'total_miles', sir.total_miles,
        'duration_seconds', coalesce(sir.effective_duration_seconds, 0),
        'start_odometer_value', sir.start_odometer_value,
        'end_odometer_value', sir.end_odometer_value
      ) order by sir.start_time)
      from sessions_in_range sir
      left join trip_apps ta on ta.session_id = sir.id), '[]'::jsonb),
    'weekly_checkpoints', coalesce(p_weekly_checkpoints, '[]'::jsonb),
    'route_points', coalesce((select jsonb_agg(jsonb_build_object(
        'session_id', rp.session_id, 'date_key', rp.date_key,
        'total_miles', rp.total_miles, 'map_token', rp.map_token
      ) order by rp.start_time)
      from route_points rp), '[]'::jsonb)
  )
  into v_metadata
  from public.profiles p, totals t
  where p.id = v_user_id;

  v_plain_code := '';
  for i in 1..8 loop
    v_plain_code := v_plain_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
  end loop;

  insert into public.reports (
    report_type, user_id, organization_id, vehicle_id, start_date, end_date,
    total_miles, total_sessions, generated_by, metadata,
    qr_token, qr_expires_at, qr_uses, qr_max_uses
  ) values (
    'custom', v_user_id, v_organization_id, p_vehicle_id, p_start_date, p_end_date,
    coalesce((v_metadata->>'total_miles')::float8, 0),
    coalesce((v_metadata->>'total_sessions')::int, 0),
    v_caller, v_metadata,
    encode(digest(v_plain_code, 'sha256'), 'hex'), v_expires, 0, 2
  );

  return query select v_plain_code, v_expires;
end;
$$;
