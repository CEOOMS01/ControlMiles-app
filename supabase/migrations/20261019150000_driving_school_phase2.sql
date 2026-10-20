-- Driving school, phase 2 (user-approved design, 2026-10-19).
--
-- Researched first (SuperSaaS, Bookeo, YouCanBookMe, DrivingSchool.Software,
-- Drive Scout; Stripe Connect; Twilio A2P 10DLC; CA DMV DL 400D, TX TDLR
-- DE-964 / ADEE-1317). What this adds:
--   * Programs per school (Teen / Adult / custom): required hours and night
--     hours, class length, and whether the guardian is notified. Classes are
--     for adults too (user note), so the requirement is no longer one school
--     setting: ds_settings.required_* move into programs and are dropped.
--   * Instructor availability (weekly hours + time off) -> free slots.
--   * Booking from the student/parent portal with the school's rules:
--     minimum notice, booking horizon, max upcoming classes, package balance;
--     no instructor or car double-booking.
--   * Cancellation policy: free until N hours before; later counts as used.
--     A freed slot is emailed to the program's other students.
--   * State records: the number of the state's official certificate (paper
--     forms the DMV supplies -- they can't be generated) and a printable
--     hour log (web).
--   * SMS consent recorded now; texts go out once a Twilio account exists.
-- Online payments (Stripe Connect) come with the Stripe step.
--
-- Plans (driving school): programs and availability with Growth (classes +
-- students); booking, state records and SMS with Enterprise.

-- ------------------------------------------------------------------
-- Features
-- ------------------------------------------------------------------
create or replace function public.fn_org_feature_list_internal(p_org_id uuid)
returns text[] language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_tpl text;
  v_tier text;
  f text[] := '{}';
begin
  select industry_template into v_tpl from public.organizations where id = p_org_id;
  if v_tpl is null then
    return f;
  end if;
  v_tier := public.fn_org_tier_internal(p_org_id);
  if v_tier = 'none' then
    return f;
  end if;

  f := array['dvir'];
  if v_tpl in ('delivery', 'trucking', 'general') then f := f || 'owner_operators'::text; end if;
  if v_tpl in ('trucking', 'construction', 'general') then f := f || 'ifta'::text; end if;
  if v_tpl = 'school_transport' then f := f || 'school'::text; end if;
  if v_tpl in ('school_transport', 'driving_school') then f := f || 'live_map'::text; end if;

  if v_tier = 'growth' then
    if not 'live_map' = any(f) then f := f || 'live_map'::text; end if;
    f := f || array['fleet_export', 'activity_log', 'safety_scores', 'fuel_alerts',
                    'shift_schedules', 'open_assignment'];
    if v_tpl in ('delivery', 'field_service', 'trucking', 'construction', 'passenger', 'general') then
      f := f || 'routes'::text;
    end if;
    if v_tpl <> 'driving_school' then f := f || 'geofences'::text; end if;
    if v_tpl = 'school_transport' then f := f || 'school_live'::text; end if;
    if v_tpl = 'sales' then f := f || 'trip_approval'::text; end if;
    if v_tpl = 'driving_school' then f := f || array['classes', 'students']; end if;
    if v_tpl = 'driving_school' and public.fn_org_enterprise_internal(p_org_id) then
      f := f || array['student_evaluations', 'student_portal', 'class_reminders',
                      'student_packages', 'student_certificates',
                      'student_booking', 'state_records', 'sms_reminders'];
    end if;
  end if;
  return f;
end;
$$;

-- ------------------------------------------------------------------
-- Programs
-- ------------------------------------------------------------------
create table if not exists public.ds_programs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 60),
  required_minutes int not null default 0 check (required_minutes between 0 and 100000),
  required_night_minutes int not null default 0 check (required_night_minutes between 0 and 100000),
  class_minutes int not null default 60 check (class_minutes between 15 and 480),
  notify_guardian boolean not null default false,
  is_active boolean not null default true,
  sort int not null default 0,
  created_at timestamptz not null default now(),
  check (required_night_minutes <= required_minutes)
);
create index if not exists ds_programs_org_idx on public.ds_programs (organization_id, sort);

alter table public.ds_students add column if not exists program_id uuid references public.ds_programs(id) on delete set null;
alter table public.ds_students add column if not exists state_cert_type text check (state_cert_type is null or length(state_cert_type) <= 40);
alter table public.ds_students add column if not exists state_cert_number text check (state_cert_number is null or length(state_cert_number) <= 40);
alter table public.ds_students add column if not exists sms_consent_at timestamptz;
alter table public.ds_students add column if not exists sms_consent_phone text check (sms_consent_phone is null or length(sms_consent_phone) <= 30);
alter table public.ds_students add column if not exists sms_consent_source text check (sms_consent_source is null or sms_consent_source in ('office', 'portal'));

-- Default programs for a school: Teen (with the school's old requirement)
-- and Adult (no requirement, no guardian).
create or replace function public.ds_ensure_default_programs(p_org uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not public.is_org_member(p_org) and auth.uid() is not null then raise exception 'Not authorized'; end if;
  if exists (select 1 from public.ds_programs where organization_id = p_org) then return; end if;
  insert into public.ds_programs (organization_id, name, required_minutes, required_night_minutes, class_minutes, notify_guardian, sort)
  values (p_org, 'Teen', 360, 0, 60, true, 1),
         (p_org, 'Adult', 0, 0, 60, false, 2);
end $$;
revoke execute on function public.ds_ensure_default_programs(uuid) from public, anon;
grant execute on function public.ds_ensure_default_programs(uuid) to authenticated;

-- Existing schools: Teen takes the old school-wide requirement; students go to Teen.
insert into public.ds_programs (organization_id, name, required_minutes, required_night_minutes, class_minutes, notify_guardian, sort)
select s.organization_id, 'Teen', s.required_minutes, s.required_night_minutes, 60, true, 1
  from public.ds_settings s
 where not exists (select 1 from public.ds_programs p where p.organization_id = s.organization_id);
insert into public.ds_programs (organization_id, name, required_minutes, required_night_minutes, class_minutes, notify_guardian, sort)
select s.organization_id, 'Adult', 0, 0, 60, false, 2
  from public.ds_settings s
 where not exists (select 1 from public.ds_programs p where p.organization_id = s.organization_id and p.name = 'Adult');
update public.ds_students st
   set program_id = (select p.id from public.ds_programs p where p.organization_id = st.organization_id and p.name = 'Teen')
 where st.program_id is null;

-- Booking rules and cancellation policy (the requirement left for programs).
alter table public.ds_settings drop column if exists required_minutes;
alter table public.ds_settings drop column if exists required_night_minutes;
alter table public.ds_settings add column if not exists booking_enabled boolean not null default false;
alter table public.ds_settings add column if not exists booking_lead_hours int not null default 24 check (booking_lead_hours between 0 and 336);
alter table public.ds_settings add column if not exists booking_horizon_days int not null default 21 check (booking_horizon_days between 1 and 90);
alter table public.ds_settings add column if not exists booking_max_upcoming int not null default 2 check (booking_max_upcoming between 1 and 20);
alter table public.ds_settings add column if not exists cancel_free_hours int not null default 24 check (cancel_free_hours between 0 and 336);
alter table public.ds_settings add column if not exists cancellation_policy text check (cancellation_policy is null or length(cancellation_policy) <= 1000);

alter table public.shift_blocks add column if not exists booked_via text check (booked_via is null or booked_via in ('office', 'portal'));
alter table public.shift_blocks add column if not exists cancelled_at timestamptz;
alter table public.shift_blocks add column if not exists late_cancel boolean not null default false;

-- ------------------------------------------------------------------
-- Instructor availability
-- ------------------------------------------------------------------
create table if not exists public.ds_availability (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  instructor_id uuid not null references auth.users(id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  start_time time not null,
  end_time time not null,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  created_at timestamptz not null default now(),
  check (end_time > start_time)
);
create index if not exists ds_availability_org_idx on public.ds_availability (organization_id, weekday);

create table if not exists public.ds_time_off (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  instructor_id uuid not null references auth.users(id) on delete cascade,
  date_from date not null,
  date_to date not null,
  note text check (note is null or length(note) <= 200),
  check (date_to >= date_from)
);

create table if not exists public.ds_slot_notices (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  program_id uuid references public.ds_programs(id) on delete cascade,
  instructor_id uuid,
  vehicle_id uuid,
  block_date date not null,
  start_time time not null,
  end_time time not null,
  freed_by_student uuid,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

alter table public.ds_programs enable row level security;
alter table public.ds_availability enable row level security;
alter table public.ds_time_off enable row level security;
alter table public.ds_slot_notices enable row level security;

drop policy if exists ds_programs_select on public.ds_programs;
create policy ds_programs_select on public.ds_programs for select to authenticated
  using (public.fn_org_has_feature(organization_id, 'students'));
drop policy if exists ds_programs_write on public.ds_programs;
create policy ds_programs_write on public.ds_programs for all to authenticated
  using (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'students'))
  with check (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'students'));

drop policy if exists ds_availability_select on public.ds_availability;
create policy ds_availability_select on public.ds_availability for select to authenticated
  using (public.fn_org_has_feature(organization_id, 'classes')
         and (public.is_org_operator_or_above(organization_id) or instructor_id = auth.uid()));
drop policy if exists ds_availability_write on public.ds_availability;
create policy ds_availability_write on public.ds_availability for all to authenticated
  using (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'classes'))
  with check (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'classes')
              and exists (select 1 from public.organization_members m
                           where m.organization_id = ds_availability.organization_id and m.user_id = instructor_id and m.is_active)
              and (vehicle_id is null or exists (select 1 from public.vehicles v
                                                  where v.id = vehicle_id and v.organization_id = ds_availability.organization_id)));

drop policy if exists ds_time_off_select on public.ds_time_off;
create policy ds_time_off_select on public.ds_time_off for select to authenticated
  using (public.fn_org_has_feature(organization_id, 'classes')
         and (public.is_org_operator_or_above(organization_id) or instructor_id = auth.uid()));
drop policy if exists ds_time_off_write on public.ds_time_off;
create policy ds_time_off_write on public.ds_time_off for all to authenticated
  using (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'classes'))
  with check (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'classes')
              and exists (select 1 from public.organization_members m
                           where m.organization_id = ds_time_off.organization_id and m.user_id = instructor_id and m.is_active));
-- (ds_slot_notices: service role only)

-- A student's program must belong to the same school.
create or replace function public.fn_ds_student_program_same_org()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if new.program_id is not null and not exists (
    select 1 from public.ds_programs p where p.id = new.program_id and p.organization_id = new.organization_id
  ) then
    raise exception 'Program not found';
  end if;
  return new;
end $$;
drop trigger if exists trg_ds_student_program_same_org on public.ds_students;
create trigger trg_ds_student_program_same_org before insert or update of program_id on public.ds_students
  for each row execute function public.fn_ds_student_program_same_org();

-- ------------------------------------------------------------------
-- Free slots and balance
-- ------------------------------------------------------------------
-- Free slots of p_minutes in the school's availability, from p_from for
-- p_days, starting at least p_lead_hours from now, with no class of that
-- instructor or that car overlapping. Car: the availability's car, else
-- the instructor's assigned car.
create or replace function public.fn_ds_free_slots(p_org uuid, p_minutes int, p_from date, p_days int, p_lead_hours int)
returns table(instructor_id uuid, vehicle_id uuid, block_date date, start_time time, end_time time, starts_at timestamptz)
language sql stable security definer set search_path to 'public' as $$
  with org as (
    select coalesce(timezone, 'America/New_York') tz from public.organizations where id = p_org
  ),
  days as (
    select (p_from + g)::date d from generate_series(0, greatest(p_days, 1) - 1) g
  ),
  av as (
    select a.instructor_id, a.start_time a_start, a.end_time a_end, d.d,
           coalesce(a.vehicle_id, (select v.id from public.vehicles v
                                    where v.organization_id = p_org and v.assigned_driver_id = a.instructor_id
                                      and not v.is_archived order by v.created_at limit 1)) vid
      from public.ds_availability a
      join days d on a.weekday = extract(dow from d.d)::int
     where a.organization_id = p_org
       and exists (select 1 from public.organization_members m
                    where m.organization_id = p_org and m.user_id = a.instructor_id and m.is_active)
       and not exists (select 1 from public.ds_time_off t
                        where t.organization_id = p_org and t.instructor_id = a.instructor_id
                          and d.d between t.date_from and t.date_to)
  ),
  slots as (
    select av.instructor_id, av.vid, av.d, av.a_end,
           (av.a_start + make_interval(mins => k * p_minutes))::time st,
           (av.a_start + make_interval(mins => (k + 1) * p_minutes))::time en
      from av,
           generate_series(0, greatest(0, (extract(epoch from (av.a_end - av.a_start)) / 60)::int / p_minutes - 1)) k
  )
  select s.instructor_id, s.vid, s.d, s.st, s.en, (s.d + s.st) at time zone (select tz from org)
    from slots s
   where s.en > s.st and s.en <= s.a_end
     and (s.d + s.st) at time zone (select tz from org) >= now() + make_interval(hours => p_lead_hours)
     and not exists (select 1 from public.shift_blocks b
                      where b.organization_id = p_org and b.block_date = s.d and b.status <> 'cancelled'
                        and b.driver_id = s.instructor_id and b.start_time < s.en and b.end_time > s.st)
     and (s.vid is null or not exists (select 1 from public.shift_blocks b
                      where b.organization_id = p_org and b.block_date = s.d and b.status <> 'cancelled'
                        and b.vehicle_id = s.vid and b.start_time < s.en and b.end_time > s.st))
   order by s.d, s.st, s.instructor_id;
$$;
revoke execute on function public.fn_ds_free_slots(uuid, int, date, int, int) from public, anon, authenticated;

-- Minutes bought, used (finished classes + late cancellations) and booked
-- ahead, by class length -- what a package pays for.
create or replace function public.fn_ds_balance(p_student uuid,
  out purchased int, out used int, out booked int, out available int)
language sql stable security definer set search_path to 'public' as $$
  select x.p, x.u, x.b, x.p - x.u - x.b from (
    select coalesce((select sum(minutes)::int from public.ds_student_packages where student_id = p_student), 0) p,
           coalesce((select (sum(extract(epoch from (end_time - start_time))) / 60)::int from public.shift_blocks
                      where student_id = p_student and (status = 'done' or (status = 'cancelled' and late_cancel))), 0) u,
           coalesce((select (sum(extract(epoch from (end_time - start_time))) / 60)::int from public.shift_blocks
                      where student_id = p_student and status in ('scheduled', 'in_progress')), 0) b
  ) x
$$;
revoke execute on function public.fn_ds_balance(uuid) from public, anon, authenticated;

-- ------------------------------------------------------------------
-- Snapshot (portal + certificate): the requirement now comes from the
-- student's program; the portal also gets booking info.
-- ------------------------------------------------------------------
create or replace function public.fn_ds_student_snapshot(p_student uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare
  st public.ds_students;
  pr public.ds_programs;
  v_tz text;
  v_org_name text;
  v_classes jsonb;
  v_upcoming jsonb;
begin
  select * into st from public.ds_students where id = p_student;
  if st.id is null then return null; end if;
  select * into pr from public.ds_programs where id = st.program_id;
  select coalesce(timezone, 'America/New_York'), coalesce(report_display_name, name) into v_tz, v_org_name
    from public.organizations where id = st.organization_id;

  select coalesce(jsonb_agg(jsonb_build_object(
           'date', b.block_date, 'start', b.start_time, 'end', b.end_time,
           'instructor', nullif(concat_ws(' ', p.first_name, left(p.last_name, 1)), ''),
           'vehicle', nullif(concat_ws(' ', v.make, v.model), ''), 'vehicle_id', v.display_id,
           'minutes', n.minutes, 'night_minutes', n.night_minutes, 'miles', n.miles,
           'map_token', s.map_token, 'session_id', b.session_id,
           'evaluation', (select jsonb_build_object('note', e.note, 'scores',
                            coalesce((select jsonb_agg(jsonb_build_object('skill', k.name, 'category', k.category, 'score', sc.score) order by k.sort)
                                        from public.ds_evaluation_scores sc join public.ds_skills k on k.id = sc.skill_id
                                       where sc.evaluation_id = e.id), '[]'::jsonb))
                          from public.ds_evaluations e where e.shift_block_id = b.id)
         ) order by b.block_date, b.start_time), '[]'::jsonb)
    into v_classes
    from public.shift_blocks b
    cross join lateral public.fn_ds_class_numbers(b.id) n
    left join public.profiles p on p.id = b.driver_id
    left join public.vehicles v on v.id = b.vehicle_id
    left join public.sessions s on s.id = b.session_id
   where b.student_id = p_student and b.status = 'done';

  select coalesce(jsonb_agg(jsonb_build_object('id', b.id, 'date', b.block_date, 'start', b.start_time, 'end', b.end_time,
           'instructor', nullif(concat_ws(' ', p.first_name, left(p.last_name, 1)), ''),
           'starts_at', (b.block_date + b.start_time) at time zone v_tz)
         order by b.block_date, b.start_time), '[]'::jsonb)
    into v_upcoming
    from public.shift_blocks b
    left join public.profiles p on p.id = b.driver_id
   where b.student_id = p_student and b.status = 'scheduled'
     and (b.block_date + b.start_time) at time zone v_tz > now();

  return jsonb_build_object(
    'school', v_org_name,
    'timezone', v_tz,
    'student', jsonb_build_object('first_name', st.first_name, 'last_name', st.last_name, 'status', st.status),
    'program', coalesce(pr.name, ''),
    'required_minutes', coalesce(pr.required_minutes, 0),
    'required_night_minutes', coalesce(pr.required_night_minutes, 0),
    'classes', v_classes,
    'upcoming', v_upcoming,
    'minutes', (select coalesce(sum((c->>'minutes')::numeric), 0) from jsonb_array_elements(v_classes) c),
    'night_minutes', (select coalesce(sum((c->>'night_minutes')::numeric), 0) from jsonb_array_elements(v_classes) c),
    'miles', (select coalesce(round(sum((c->>'miles')::numeric), 1), 0) from jsonb_array_elements(v_classes) c)
  );
end $$;

create or replace function public.ds_portal_view(p_token text)
returns jsonb language plpgsql stable security definer set search_path to 'public', 'extensions' as $$
declare
  l public.ds_portal_links;
  st public.ds_students;
  cfg public.ds_settings;
  bal record;
  v jsonb;
  v_booking boolean;
begin
  select * into l from public.ds_portal_links
   where token_hash = encode(digest(coalesce(p_token, ''), 'sha256'), 'hex')
     and revoked_at is null and expires_at > now();
  if l.id is null then return null; end if;
  if not public.fn_org_feature_internal(l.organization_id, 'student_portal') then return null; end if;
  select * into st from public.ds_students where id = l.student_id;
  select * into cfg from public.ds_settings where organization_id = l.organization_id;
  bal := public.fn_ds_balance(l.student_id);
  v_booking := public.fn_org_feature_internal(l.organization_id, 'student_booking') and coalesce(cfg.booking_enabled, false)
               and st.status in ('registered', 'active') and st.program_id is not null;
  v := public.fn_ds_student_snapshot(l.student_id);
  return v || jsonb_build_object(
    'certificates', coalesce((select jsonb_agg(jsonb_build_object('number', c.number, 'issued_at', c.issued_at, 'sha256', c.sha256) order by c.issued_at)
                                from public.ds_certificates c where c.student_id = l.student_id), '[]'::jsonb),
    'booking', jsonb_build_object(
       'enabled', v_booking,
       'cancel_free_hours', coalesce(cfg.cancel_free_hours, 24),
       'policy', cfg.cancellation_policy,
       'max_upcoming', coalesce(cfg.booking_max_upcoming, 2)),
    'balance', case when public.fn_org_feature_internal(l.organization_id, 'student_packages')
                     and exists (select 1 from public.ds_student_packages where student_id = l.student_id)
                    then jsonb_build_object('purchased', bal.purchased, 'used', bal.used, 'booked', bal.booked,
                                            'available', bal.purchased - bal.used - bal.booked)
                    else null end,
    'sms', jsonb_build_object('available', public.fn_org_feature_internal(l.organization_id, 'sms_reminders'),
                              'consent', st.sms_consent_at is not null,
                              'phone', st.sms_consent_phone)
  );
end $$;

-- Certificate: requirement from the program.
create or replace function public.ds_issue_certificate(p_student uuid)
returns uuid language plpgsql security definer set search_path to 'public', 'extensions' as $$
declare
  v_org uuid;
  v jsonb;
  v_id uuid := gen_random_uuid();
  v_number text;
begin
  select organization_id into v_org from public.ds_students where id = p_student;
  if v_org is null or not public.is_org_admin_or_owner(v_org) then raise exception 'Not authorized'; end if;
  perform public.fn_require_org_feature(v_org, 'student_certificates');
  v := public.fn_ds_student_snapshot(p_student);
  if (v->>'minutes')::numeric < (v->>'required_minutes')::numeric
     or (v->>'night_minutes')::numeric < (v->>'required_night_minutes')::numeric
     or jsonb_array_length(v->'classes') = 0 then
    raise exception 'REQUIRED_HOURS_NOT_MET';
  end if;
  v_number := 'CM-' || to_char(now() at time zone (v->>'timezone'), 'YYYYMMDD') || '-' || upper(substr(replace(v_id::text, '-', ''), 1, 6));
  v := (v - 'upcoming') || jsonb_build_object('number', v_number, 'issued_at', now());
  insert into public.ds_certificates (id, number, organization_id, student_id, data, sha256, issued_by)
  values (v_id, v_number, v_org, p_student, v, encode(digest(v::text, 'sha256'), 'hex'), auth.uid());
  return v_id;
end $$;

-- ------------------------------------------------------------------
-- Portal: free slots, book, cancel, SMS consent
-- ------------------------------------------------------------------
create or replace function public.fn_ds_portal_link(p_token text)
returns public.ds_portal_links language sql stable security definer set search_path to 'public', 'extensions' as $$
  select * from public.ds_portal_links
   where token_hash = encode(digest(coalesce(p_token, ''), 'sha256'), 'hex')
     and revoked_at is null and expires_at > now();
$$;
revoke execute on function public.fn_ds_portal_link(text) from public, anon, authenticated;

create or replace function public.ds_portal_slots(p_token text)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare
  l public.ds_portal_links := public.fn_ds_portal_link(p_token);
  st public.ds_students;
  pr public.ds_programs;
  cfg public.ds_settings;
  v_tz text;
begin
  if l.id is null then return null; end if;
  if not public.fn_org_feature_internal(l.organization_id, 'student_booking') then return null; end if;
  select * into cfg from public.ds_settings where organization_id = l.organization_id;
  if not coalesce(cfg.booking_enabled, false) then return null; end if;
  select * into st from public.ds_students where id = l.student_id;
  select * into pr from public.ds_programs where id = st.program_id and is_active;
  if pr.id is null or st.status not in ('registered', 'active') then return null; end if;
  select coalesce(timezone, 'America/New_York') into v_tz from public.organizations where id = l.organization_id;
  return jsonb_build_object(
    'minutes', pr.class_minutes,
    'slots', coalesce((
      select jsonb_agg(jsonb_build_object(
               'instructor_id', s.instructor_id,
               'instructor', nullif(concat_ws(' ', p.first_name, left(p.last_name, 1)), ''),
               'date', s.block_date, 'start', s.start_time, 'end', s.end_time) order by s.block_date, s.start_time)
        from public.fn_ds_free_slots(l.organization_id, pr.class_minutes, (now() at time zone v_tz)::date,
                                     cfg.booking_horizon_days, cfg.booking_lead_hours) s
        left join public.profiles p on p.id = s.instructor_id), '[]'::jsonb)
  );
end $$;
revoke execute on function public.ds_portal_slots(text) from public;
grant execute on function public.ds_portal_slots(text) to anon, authenticated;

create or replace function public.ds_portal_book(p_token text, p_instructor uuid, p_date date, p_start time)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare
  l public.ds_portal_links := public.fn_ds_portal_link(p_token);
  st public.ds_students;
  pr public.ds_programs;
  cfg public.ds_settings;
  v_tz text;
  s record;
  bal record;
  v_upcoming int;
  v_id uuid;
begin
  if l.id is null then raise exception 'LINK_NOT_ACTIVE'; end if;
  perform public.fn_require_org_feature(l.organization_id, 'student_booking');
  select * into cfg from public.ds_settings where organization_id = l.organization_id;
  if not coalesce(cfg.booking_enabled, false) then raise exception 'BOOKING_OFF'; end if;
  select * into st from public.ds_students where id = l.student_id;
  select * into pr from public.ds_programs where id = st.program_id and is_active;
  if pr.id is null or st.status not in ('registered', 'active') then raise exception 'BOOKING_OFF'; end if;
  select coalesce(timezone, 'America/New_York') into v_tz from public.organizations where id = l.organization_id;

  -- One booking at a time per instructor and day.
  perform pg_advisory_xact_lock(hashtext(p_instructor::text || p_date::text));

  select count(*) into v_upcoming from public.shift_blocks
   where student_id = st.id and status = 'scheduled' and (block_date + start_time) at time zone v_tz > now();
  if v_upcoming >= cfg.booking_max_upcoming then raise exception 'TOO_MANY_UPCOMING'; end if;

  if public.fn_org_feature_internal(l.organization_id, 'student_packages')
     and exists (select 1 from public.ds_packages where organization_id = l.organization_id and is_active) then
    bal := public.fn_ds_balance(st.id);
    if bal.purchased - bal.used - bal.booked < pr.class_minutes then raise exception 'NO_BALANCE'; end if;
  end if;

  select * into s from public.fn_ds_free_slots(l.organization_id, pr.class_minutes, p_date, 1, cfg.booking_lead_hours) f
   where f.instructor_id = p_instructor and f.start_time = p_start
     and p_date <= (now() at time zone v_tz)::date + cfg.booking_horizon_days;
  if s.instructor_id is null then raise exception 'SLOT_TAKEN'; end if;

  insert into public.shift_blocks (organization_id, driver_id, vehicle_id, block_date, start_time, end_time, source,
                                   status, student_id, booked_via, note)
  values (l.organization_id, s.instructor_id, s.vehicle_id, s.block_date, s.start_time, s.end_time, 'one_off',
          'scheduled', st.id, 'portal', 'Booked online')
  returning id into v_id;
  return v_id;
end $$;
revoke execute on function public.ds_portal_book(text, uuid, date, time) from public;
grant execute on function public.ds_portal_book(text, uuid, date, time) to anon, authenticated;

create or replace function public.ds_portal_cancel(p_token text, p_block uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  l public.ds_portal_links := public.fn_ds_portal_link(p_token);
  b public.shift_blocks;
  cfg public.ds_settings;
  st public.ds_students;
  v_tz text;
  v_starts timestamptz;
  v_late boolean;
begin
  if l.id is null then raise exception 'LINK_NOT_ACTIVE'; end if;
  perform public.fn_require_org_feature(l.organization_id, 'student_booking');
  select * into b from public.shift_blocks where id = p_block and student_id = l.student_id;
  if b.id is null or b.status <> 'scheduled' then raise exception 'CLASS_NOT_CANCELLABLE'; end if;
  select * into cfg from public.ds_settings where organization_id = l.organization_id;
  select * into st from public.ds_students where id = l.student_id;
  select coalesce(timezone, 'America/New_York') into v_tz from public.organizations where id = l.organization_id;
  v_starts := (b.block_date + b.start_time) at time zone v_tz;
  if v_starts <= now() then raise exception 'CLASS_NOT_CANCELLABLE'; end if;
  v_late := v_starts - now() < make_interval(hours => coalesce(cfg.cancel_free_hours, 24));

  update public.shift_blocks set status = 'cancelled', cancelled_at = now(), late_cancel = v_late where id = b.id;

  -- Offer the freed slot to the program's other students (send-class-reminders).
  if v_starts > now() + make_interval(hours => coalesce(cfg.booking_lead_hours, 24)) then
    insert into public.ds_slot_notices (organization_id, program_id, instructor_id, vehicle_id, block_date, start_time, end_time, freed_by_student)
    values (l.organization_id, st.program_id, b.driver_id, b.vehicle_id, b.block_date, b.start_time, b.end_time, st.id);
  end if;
  return jsonb_build_object('late', v_late);
end $$;
revoke execute on function public.ds_portal_cancel(text, uuid) from public;
grant execute on function public.ds_portal_cancel(text, uuid) to anon, authenticated;

create or replace function public.ds_portal_set_sms(p_token text, p_on boolean, p_phone text default null)
returns void language plpgsql security definer set search_path to 'public' as $$
declare
  l public.ds_portal_links := public.fn_ds_portal_link(p_token);
  v_phone text := nullif(regexp_replace(coalesce(p_phone, ''), '[^0-9+]', '', 'g'), '');
begin
  if l.id is null then raise exception 'LINK_NOT_ACTIVE'; end if;
  perform public.fn_require_org_feature(l.organization_id, 'sms_reminders');
  if p_on then
    if v_phone is null or length(v_phone) < 10 then raise exception 'PHONE_REQUIRED'; end if;
    update public.ds_students set sms_consent_at = now(), sms_consent_phone = v_phone, sms_consent_source = 'portal'
     where id = l.student_id;
  else
    update public.ds_students set sms_consent_at = null, sms_consent_phone = null, sms_consent_source = null
     where id = l.student_id;
  end if;
end $$;
revoke execute on function public.ds_portal_set_sms(text, boolean, text) from public;
grant execute on function public.ds_portal_set_sms(text, boolean, text) to anon, authenticated;

-- ------------------------------------------------------------------
-- Reminders: guardian only when the program says so; freed slots.
-- ------------------------------------------------------------------
create or replace function public.ds_due_class_reminders()
returns table(shift_block_id uuid, organization_id uuid, school text, timezone text, block_date date,
              start_time time, student_first_name text, recipient text, instructor text)
language sql stable security definer set search_path to 'public' as $$
  select b.id, b.organization_id, coalesce(o.report_display_name, o.name), coalesce(o.timezone, 'America/New_York'),
         b.block_date, b.start_time, st.first_name, lower(btrim(r.email)),
         nullif(concat_ws(' ', p.first_name, left(p.last_name, 1)), '')
    from public.shift_blocks b
    join public.organizations o on o.id = b.organization_id
    join public.ds_students st on st.id = b.student_id and st.status in ('registered', 'active')
    left join public.ds_programs pr on pr.id = st.program_id
    left join public.ds_settings cfg on cfg.organization_id = b.organization_id
    left join public.profiles p on p.id = b.driver_id
    cross join lateral (values (st.email), (case when coalesce(pr.notify_guardian, true) then st.guardian_email end)) as r(email)
   where b.status = 'scheduled'
     and r.email is not null and btrim(r.email) <> ''
     and (b.block_date + b.start_time) at time zone coalesce(o.timezone, 'America/New_York')
         between now() and now() + make_interval(hours => coalesce(cfg.reminder_hours, 24))
     and public.fn_org_feature_internal(b.organization_id, 'class_reminders')
     and not exists (select 1 from public.ds_reminders_sent x
                      where x.shift_block_id = b.id and x.recipient = lower(btrim(r.email)));
$$;
revoke execute on function public.ds_due_class_reminders() from public, anon, authenticated;

-- Freed slots still free, and who to tell: the program's other current
-- students (the student, plus the guardian if the program says so).
create or replace function public.ds_due_slot_notices()
returns table(notice_id uuid, school text, block_date date, start_time time, instructor text, recipient text, first_name text)
language sql stable security definer set search_path to 'public' as $$
  select n.id, coalesce(o.report_display_name, o.name), n.block_date, n.start_time,
         nullif(concat_ws(' ', p.first_name, left(p.last_name, 1)), ''), lower(btrim(r.email)), st.first_name
    from public.ds_slot_notices n
    join public.organizations o on o.id = n.organization_id
    join public.ds_settings cfg on cfg.organization_id = n.organization_id and cfg.booking_enabled
    left join public.ds_programs pr on pr.id = n.program_id
    left join public.profiles p on p.id = n.instructor_id
    join public.ds_students st on st.organization_id = n.organization_id and st.program_id = n.program_id
                              and st.status in ('registered', 'active') and st.id is distinct from n.freed_by_student
                              and exists (select 1 from public.ds_portal_links pl
                                           where pl.student_id = st.id and pl.revoked_at is null and pl.expires_at > now())
    cross join lateral (values (st.email), (case when coalesce(pr.notify_guardian, true) then st.guardian_email end)) as r(email)
   where n.sent_at is null
     and r.email is not null and btrim(r.email) <> ''
     and public.fn_org_feature_internal(n.organization_id, 'student_booking')
     and (n.block_date + n.start_time) at time zone coalesce(o.timezone, 'America/New_York') > now()
     and not exists (select 1 from public.shift_blocks b
                      where b.organization_id = n.organization_id and b.block_date = n.block_date
                        and b.status <> 'cancelled' and b.driver_id = n.instructor_id
                        and b.start_time < n.end_time and b.end_time > n.start_time);
$$;
revoke execute on function public.ds_due_slot_notices() from public, anon, authenticated;
