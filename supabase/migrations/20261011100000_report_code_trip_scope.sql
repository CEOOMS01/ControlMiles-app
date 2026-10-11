-- Gig / Fleet split, server side of "split gig miles from fleet miles"
-- (2026-10-11): generate_report_access_code summed EVERY trip of the
-- driver, so a person who drives personally and for a fleet got company
-- miles in their personal IRS report (and personal miles in the fleet's).
--
--   * own report (ControlMiles app, web /portal/generate): personal trips
--     only -- v_organization_id stays null.
--   * fleet admin's report for one of their drivers: that fleet's trips
--     only -- v_organization_id is the fleet.
--
-- Body = the live definition (last changed directly in the database, see
-- fix_report_code_effective_duration) plus
-- "and s.organization_id is not distinct from v_organization_id" on each of
-- the 5 trip queries.

CREATE OR REPLACE FUNCTION public.generate_report_access_code(p_start_date date, p_end_date date, p_vehicle_id uuid DEFAULT NULL::uuid, p_weekly_checkpoints jsonb DEFAULT '[]'::jsonb, p_target_user_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(code text, expires_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
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
    and s.organization_id is not distinct from v_organization_id
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
    and s.organization_id is not distinct from v_organization_id
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
    and s.organization_id is not distinct from v_organization_id
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
    and s.organization_id is not distinct from v_organization_id
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
    and s.organization_id is not distinct from v_organization_id
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
        'total_miles', rp.total_miles, 'map_token', rp.map_token,
        'section_ids', (select case when count(*) > 1 then jsonb_agg(ss.id order by ss.start_time) end
                          from public.session_sections ss where ss.session_id = rp.session_id and ss.total_miles >= 0.05)
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
$function$;
