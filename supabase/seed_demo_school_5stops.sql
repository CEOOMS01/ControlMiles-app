-- Demo data, 5-stop school route (2026-10-09). NOT a migration: run by hand
-- after seed_demo_school.sql. Adds Bus 7, 10 invented students and
-- "Route 7 — Lincoln AM/PM": 5 different pick-up stops (2 students each)
-- then school; PM is school then the 5 stops in reverse. Idempotent on the
-- route name.
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
    array['Olivia','K','2'], array['James','B','3'], array['Isabella','F','1'], array['Mateo','D','4'],
    array['Amelia','S','2'], array['Henry','J','5'], array['Harper','N','3'], array['Daniel','V','1'],
    array['Chloe','H','4'], array['Leo','A','2']];
  -- name, lat, lng, AM time, PM time
  v_stops text[][] := array[
    array['N Charles St & E 25th St',      '39.3166', '-76.6168', '06:50', '15:40'],
    array['Greenmount Ave & E 33rd St',    '39.3271', '-76.6094', '06:57', '15:33'],
    array['Guilford Ave & E 22nd St',      '39.3127', '-76.6131', '07:04', '15:26'],
    array['W 36th St & Roland Ave',        '39.3310', '-76.6330', '07:11', '15:19'],
    array['Remington Ave & W 28th St',     '39.3215', '-76.6270', '07:18', '15:12']];
  v_students uuid[] := '{}';
  v_am_stops uuid[] := '{}';
  v_pm_stops uuid[] := '{}';
  v_id uuid;
  i int;
begin
  select id into v_org from public.organizations where name = 'Demo School Bus Co';
  if v_org is null then raise exception 'Run seed_demo_school.sql first'; end if;
  if exists (select 1 from public.routes where organization_id = v_org and name = 'Route 7 — Lincoln AM') then
    raise notice 'Route 7 already exists';
    return;
  end if;
  select id into v_school from public.school_sites where organization_id = v_org limit 1;

  insert into public.vehicles (organization_id, nickname, make, model, year, plate, is_active)
  values (v_org, 'Bus 7', 'Thomas Built', 'Saf-T-Liner C2', 2021, 'DEMO07', true)
  returning id into v_bus;

  for i in 1 .. array_length(v_names, 1) loop
    insert into public.students (organization_id, first_name, last_initial, grade, school_site_id)
    values (v_org, v_names[i][1], v_names[i][2], v_names[i][3], v_school)
    returning id into v_id;
    v_students := v_students || v_id;
  end loop;

  insert into public.routes (organization_id, name, route_type, school_site_id, assigned_driver_id,
                             assigned_vehicle_id, scheduled_start_time, service_days, status, created_by)
  values (v_org, 'Route 7 — Lincoln AM', 'school_am', v_school, v_owner, v_bus, '06:50', '{1,2,3,4,5,6,7}', 'active', v_owner)
  returning id into v_am;
  insert into public.routes (organization_id, name, route_type, school_site_id, assigned_driver_id,
                             assigned_vehicle_id, scheduled_start_time, service_days, status, created_by)
  values (v_org, 'Route 7 — Lincoln PM', 'school_pm', v_school, v_owner, v_bus, '15:00', '{1,2,3,4,5,6,7}', 'active', v_owner)
  returning id into v_pm;

  -- AM: 5 pick-ups, then school.
  for i in 1 .. 5 loop
    insert into public.route_stops (route_id, organization_id, seq, name, latitude, longitude, scheduled_time, stop_kind)
    values (v_am, v_org, i, v_stops[i][1], v_stops[i][2]::float8, v_stops[i][3]::float8, v_stops[i][4]::time, 'pickup')
    returning id into v_stop;
    v_am_stops := v_am_stops || v_stop;
  end loop;
  insert into public.route_stops (route_id, organization_id, seq, name, latitude, longitude, scheduled_time, stop_kind)
  values (v_am, v_org, 6, 'Lincoln Elementary (demo)', 39.2866, -76.6125, '07:35', 'school') returning id into v_stop;
  v_am_stops := v_am_stops || v_stop;

  -- PM: school, then the 5 stops in reverse.
  insert into public.route_stops (route_id, organization_id, seq, name, latitude, longitude, scheduled_time, stop_kind)
  values (v_pm, v_org, 1, 'Lincoln Elementary (demo)', 39.2866, -76.6125, '15:00', 'school') returning id into v_stop;
  v_pm_stops := v_pm_stops || v_stop;
  for i in reverse 5 .. 1 loop
    insert into public.route_stops (route_id, organization_id, seq, name, latitude, longitude, scheduled_time, stop_kind)
    values (v_pm, v_org, 7 - i, v_stops[i][1], v_stops[i][2]::float8, v_stops[i][3]::float8, v_stops[i][5]::time, 'dropoff')
    returning id into v_stop;
    v_pm_stops := v_pm_stops || v_stop;
  end loop;

  -- Students 2k-1 and 2k live at stop k. v_pm_stops: [school, stop5, stop4, stop3, stop2, stop1].
  for i in 1 .. 10 loop
    insert into public.student_stop_assignments (organization_id, student_id, route_id, stop_id, action)
    values (v_org, v_students[i], v_am, v_am_stops[(i + 1) / 2], 'board'),
           (v_org, v_students[i], v_am, v_am_stops[6], 'alight'),
           (v_org, v_students[i], v_pm, v_pm_stops[1], 'board'),
           (v_org, v_students[i], v_pm, v_pm_stops[7 - (i + 1) / 2], 'alight');
  end loop;
end $$;
