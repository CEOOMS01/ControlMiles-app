-- Demo data for School transportation (2026-10-09). NOT a migration: run by
-- hand to get a demo fleet. All students are invented. Owner: alsoler26.
-- Baltimore, MD. Idempotent on the org name.
do $$
declare
  v_owner uuid := '4594289a-9b7e-4b2b-a177-b9eab3c3525c';
  v_org uuid;
  v_bus uuid;
  v_school uuid;
  v_am uuid;
  v_pm uuid;
  v_stop uuid;
  v_names text[][] := array[
    array['Mia','R','2'], array['Liam','T','3'], array['Sofia','G','1'], array['Noah','P','4'],
    array['Emma','L','2'], array['Lucas','M','5'], array['Ava','C','3'], array['Ethan','W','1']];
  v_students uuid[] := '{}';
  v_id uuid;
  i int;
  v_am_stops uuid[] := '{}';
  v_pm_stops uuid[] := '{}';
begin
  select id into v_org from public.organizations where name = 'Demo School Bus Co';
  if v_org is not null then
    raise notice 'Demo already exists: %', v_org;
    return;
  end if;

  insert into public.organizations (name, created_by, industry_template, fleet_type_confirmed_at,
                                    require_pretrip_inspection, timezone, tier_enforcement_exempt)
  values ('Demo School Bus Co', v_owner, 'school_transport', now(), true, 'America/New_York', true)
  returning id into v_org;
  insert into public.organization_members (organization_id, user_id, member_role, is_active, joined_at)
  values (v_org, v_owner, 'owner', true, now());

  insert into public.vehicles (organization_id, nickname, make, model, year, plate, is_active)
  values (v_org, 'Bus 12', 'Blue Bird', 'Vision', 2022, 'DEMO12', true)
  returning id into v_bus;

  insert into public.school_sites (organization_id, name, address, latitude, longitude)
  values (v_org, 'Lincoln Elementary (demo)', '200 E Pratt St, Baltimore, MD', 39.2866, -76.6125)
  returning id into v_school;

  for i in 1 .. array_length(v_names, 1) loop
    insert into public.students (organization_id, first_name, last_initial, grade, school_site_id)
    values (v_org, v_names[i][1], v_names[i][2], v_names[i][3], v_school)
    returning id into v_id;
    v_students := v_students || v_id;
  end loop;

  insert into public.routes (organization_id, name, route_type, school_site_id, assigned_driver_id,
                             assigned_vehicle_id, scheduled_start_time, service_days, status, created_by)
  values (v_org, 'Route 12 — Lincoln AM', 'school_am', v_school, v_owner, v_bus, '07:00', '{1,2,3,4,5,6,7}', 'active', v_owner)
  returning id into v_am;
  insert into public.routes (organization_id, name, route_type, school_site_id, assigned_driver_id,
                             assigned_vehicle_id, scheduled_start_time, service_days, status, created_by)
  values (v_org, 'Route 12 — Lincoln PM', 'school_pm', v_school, v_owner, v_bus, '15:00', '{1,2,3,4,5,6,7}', 'active', v_owner)
  returning id into v_pm;

  -- AM: three pick-ups, then school.
  insert into public.route_stops (route_id, organization_id, seq, name, latitude, longitude, scheduled_time, stop_kind)
  values (v_am, v_org, 1, 'Druid Hill Ave & North Ave', 39.3110, -76.6330, '07:00', 'pickup') returning id into v_stop;
  v_am_stops := v_am_stops || v_stop;
  insert into public.route_stops (route_id, organization_id, seq, name, latitude, longitude, scheduled_time, stop_kind)
  values (v_am, v_org, 2, 'Eutaw Pl & W Lafayette Ave', 39.3010, -76.6260, '07:08', 'pickup') returning id into v_stop;
  v_am_stops := v_am_stops || v_stop;
  insert into public.route_stops (route_id, organization_id, seq, name, latitude, longitude, scheduled_time, stop_kind)
  values (v_am, v_org, 3, 'Mt Vernon Pl', 39.2975, -76.6155, '07:15', 'pickup') returning id into v_stop;
  v_am_stops := v_am_stops || v_stop;
  insert into public.route_stops (route_id, organization_id, seq, name, latitude, longitude, scheduled_time, stop_kind)
  values (v_am, v_org, 4, 'Lincoln Elementary (demo)', 39.2866, -76.6125, '07:30', 'school') returning id into v_stop;
  v_am_stops := v_am_stops || v_stop;

  -- PM: school, then the same stops in reverse.
  insert into public.route_stops (route_id, organization_id, seq, name, latitude, longitude, scheduled_time, stop_kind)
  values (v_pm, v_org, 1, 'Lincoln Elementary (demo)', 39.2866, -76.6125, '15:00', 'school') returning id into v_stop;
  v_pm_stops := v_pm_stops || v_stop;
  insert into public.route_stops (route_id, organization_id, seq, name, latitude, longitude, scheduled_time, stop_kind)
  values (v_pm, v_org, 2, 'Mt Vernon Pl', 39.2975, -76.6155, '15:12', 'dropoff') returning id into v_stop;
  v_pm_stops := v_pm_stops || v_stop;
  insert into public.route_stops (route_id, organization_id, seq, name, latitude, longitude, scheduled_time, stop_kind)
  values (v_pm, v_org, 3, 'Eutaw Pl & W Lafayette Ave', 39.3010, -76.6260, '15:20', 'dropoff') returning id into v_stop;
  v_pm_stops := v_pm_stops || v_stop;
  insert into public.route_stops (route_id, organization_id, seq, name, latitude, longitude, scheduled_time, stop_kind)
  values (v_pm, v_org, 4, 'Druid Hill Ave & North Ave', 39.3110, -76.6330, '15:28', 'dropoff') returning id into v_stop;
  v_pm_stops := v_pm_stops || v_stop;

  -- Students 1-3 at stop 1, 4-6 at stop 2, 7-8 at stop 3. AM: board there,
  -- get off at school. PM: board at school, get off at their stop.
  for i in 1 .. 8 loop
    insert into public.student_stop_assignments (organization_id, student_id, route_id, stop_id, action)
    values (v_org, v_students[i], v_am, v_am_stops[case when i <= 3 then 1 when i <= 6 then 2 else 3 end], 'board'),
           (v_org, v_students[i], v_am, v_am_stops[4], 'alight'),
           (v_org, v_students[i], v_pm, v_pm_stops[1], 'board'),
           (v_org, v_students[i], v_pm, v_pm_stops[case when i <= 3 then 4 when i <= 6 then 3 else 2 end], 'alight');
  end loop;

  raise notice 'Demo org %', v_org;
end $$;
