-- Driving school: students module, phase 1 (user-approved design, 2026-10-19).
--
-- Researched first (Drive Scout, DrivingSchoolSoftware.com, Drivers Ed
-- Solutions, DriveNotes, RoadReady, Clocked): they all keep a student record
-- with a guardian, a report card per lesson, a balance of lessons, a
-- certificate once the required hours are met, a parent/student portal and
-- reminders. None of them can PROVE the hours: they are typed in. Here each
-- class is a real GPS trip with odometer photos (shift_blocks.session_id), so
-- a student's hours, night hours and miles come from those trips and can't be
-- edited, and the certificate is sealed with a hash.
--
-- Plans for the driving-school service (user decision): Starter = miles only
-- (cars, instructors, trips, live map); Growth = + classes and students
-- (record, class <-> student, hours log); Enterprise = + evaluations (report
-- cards), parent/student portal, reminders, packages & balance, certificates.
-- Enterprise is now a real plan: subscription_tier = 'enterprise', and test
-- orgs (tier_enforcement_exempt) get everything.

-- ------------------------------------------------------------------
-- Plans: Enterprise counts as Growth for everything Growth has, plus its own.
-- ------------------------------------------------------------------
create or replace function public.fn_org_tier_internal(p_org_id uuid)
returns text language sql stable security definer set search_path to 'public'
as $$
  select coalesce((
    select case
      when o.tier_enforcement_exempt then 'growth'
      when o.subscription_status in ('active', 'trialing', 'past_due') and o.subscription_tier in ('growth', 'enterprise') then 'growth'
      when o.subscription_status in ('active', 'trialing', 'past_due') and o.subscription_tier = 'starter' then 'starter'
      when now() - o.created_at <= interval '15 days' then 'growth'
      else 'none'
    end
    from public.organizations o
    where o.id = p_org_id
  ), 'none');
$$;

create or replace function public.fn_org_enterprise_internal(p_org_id uuid)
returns boolean language sql stable security definer set search_path to 'public'
as $$
  select coalesce((
    select o.tier_enforcement_exempt
        or (o.subscription_status in ('active', 'trialing', 'past_due') and o.subscription_tier = 'enterprise')
    from public.organizations o where o.id = p_org_id
  ), false);
$$;
revoke execute on function public.fn_org_enterprise_internal(uuid) from public, anon, authenticated;

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
  -- A driving school's or school fleet's admin always sees their drivers
  -- live (user rule, 2026-10-19), on any plan.
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
    -- Driving school, Growth: classes and students (moved from Starter, user decision).
    if v_tpl = 'driving_school' then f := f || array['classes', 'students']; end if;
    -- Driving school, Enterprise.
    if v_tpl = 'driving_school' and public.fn_org_enterprise_internal(p_org_id) then
      f := f || array['student_evaluations', 'student_portal', 'class_reminders',
                      'student_packages', 'student_certificates'];
    end if;
  end if;
  return f;
end;
$$;

-- ------------------------------------------------------------------
-- Tables
-- ------------------------------------------------------------------
create table if not exists public.ds_students (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id) on delete set null,
  first_name text not null check (length(btrim(first_name)) between 1 and 60),
  last_name text not null check (length(btrim(last_name)) between 1 and 60),
  phone text check (phone is null or length(phone) <= 30),
  email text check (email is null or length(email) <= 120),
  guardian_name text check (guardian_name is null or length(guardian_name) <= 120),
  guardian_phone text check (guardian_phone is null or length(guardian_phone) <= 30),
  guardian_email text check (guardian_email is null or length(guardian_email) <= 120),
  status text not null default 'active' check (status in ('registered', 'active', 'finished', 'dropped')),
  notes text check (notes is null or length(notes) <= 1000),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists ds_students_org_idx on public.ds_students (organization_id, status);

-- Minors' data, admins only (user decision): kept apart so the row-level
-- rule can hide it from operators and instructors.
create table if not exists public.ds_student_private (
  student_id uuid primary key references public.ds_students(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  date_of_birth date,
  permit_number text check (permit_number is null or length(permit_number) <= 40)
);

alter table public.shift_blocks add column if not exists student_id uuid references public.ds_students(id) on delete set null;
create index if not exists shift_blocks_student_idx on public.shift_blocks (student_id) where student_id is not null;

create table if not exists public.ds_settings (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  required_minutes int not null default 360 check (required_minutes between 0 and 100000),
  required_night_minutes int not null default 0 check (required_night_minutes between 0 and 100000),
  reminder_hours int not null default 24 check (reminder_hours between 1 and 168),
  updated_at timestamptz not null default now()
);

create table if not exists public.ds_skills (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  category text not null check (length(btrim(category)) between 1 and 60),
  name text not null check (length(btrim(name)) between 1 and 80),
  sort int not null default 0,
  is_active boolean not null default true
);
create index if not exists ds_skills_org_idx on public.ds_skills (organization_id, sort);

create table if not exists public.ds_evaluations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  shift_block_id uuid not null unique references public.shift_blocks(id) on delete cascade,
  student_id uuid not null references public.ds_students(id) on delete cascade,
  instructor_id uuid references auth.users(id) on delete set null,
  note text check (note is null or length(note) <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists ds_evaluations_student_idx on public.ds_evaluations (student_id);

create table if not exists public.ds_evaluation_scores (
  evaluation_id uuid not null references public.ds_evaluations(id) on delete cascade,
  skill_id uuid not null references public.ds_skills(id) on delete cascade,
  score smallint not null check (score between 1 and 4),
  primary key (evaluation_id, skill_id)
);

create table if not exists public.ds_packages (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 80),
  minutes int not null check (minutes between 1 and 100000),
  price_cents int not null default 0 check (price_cents >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.ds_student_packages (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  student_id uuid not null references public.ds_students(id) on delete cascade,
  package_id uuid references public.ds_packages(id) on delete set null,
  name text not null,
  minutes int not null check (minutes > 0),
  price_cents int not null default 0 check (price_cents >= 0),
  amount_paid_cents int not null default 0 check (amount_paid_cents >= 0),
  payment_status text not null default 'pending' check (payment_status in ('paid', 'partial', 'pending')),
  note text check (note is null or length(note) <= 500),
  created_at timestamptz not null default now()
);
create index if not exists ds_student_packages_student_idx on public.ds_student_packages (student_id);

create table if not exists public.ds_portal_links (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  student_id uuid not null references public.ds_students(id) on delete cascade,
  token_hash text not null unique,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '180 days',
  revoked_at timestamptz
);

create table if not exists public.ds_certificates (
  id uuid primary key default gen_random_uuid(),
  number text not null unique,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  student_id uuid not null references public.ds_students(id) on delete cascade,
  data jsonb not null,
  sha256 text not null,
  issued_by uuid references auth.users(id) on delete set null,
  issued_at timestamptz not null default now()
);
-- A certificate is a sealed record: never edited.
create or replace function public.fn_ds_certificates_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'CERTIFICATE_IMMUTABLE';
end $$;
drop trigger if exists trg_ds_certificates_immutable on public.ds_certificates;
create trigger trg_ds_certificates_immutable before update on public.ds_certificates
  for each row execute function public.fn_ds_certificates_immutable();

create table if not exists public.ds_reminders_sent (
  shift_block_id uuid not null references public.shift_blocks(id) on delete cascade,
  recipient text not null,
  sent_at timestamptz not null default now(),
  primary key (shift_block_id, recipient)
);

-- updated_at
create or replace function public.fn_ds_touch()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists trg_ds_students_touch on public.ds_students;
create trigger trg_ds_students_touch before update on public.ds_students for each row execute function public.fn_ds_touch();
drop trigger if exists trg_ds_evaluations_touch on public.ds_evaluations;
create trigger trg_ds_evaluations_touch before update on public.ds_evaluations for each row execute function public.fn_ds_touch();

-- A class's student must belong to the same fleet.
create or replace function public.fn_ds_block_student_same_org()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if new.student_id is not null and not exists (
    select 1 from public.ds_students s where s.id = new.student_id and s.organization_id = new.organization_id
  ) then
    raise exception 'Student not found';
  end if;
  return new;
end $$;
drop trigger if exists trg_ds_block_student_same_org on public.shift_blocks;
create trigger trg_ds_block_student_same_org before insert or update of student_id on public.shift_blocks
  for each row execute function public.fn_ds_block_student_same_org();

-- ------------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------------
alter table public.ds_students enable row level security;
alter table public.ds_student_private enable row level security;
alter table public.ds_settings enable row level security;
alter table public.ds_skills enable row level security;
alter table public.ds_evaluations enable row level security;
alter table public.ds_evaluation_scores enable row level security;
alter table public.ds_packages enable row level security;
alter table public.ds_student_packages enable row level security;
alter table public.ds_portal_links enable row level security;
alter table public.ds_certificates enable row level security;
alter table public.ds_reminders_sent enable row level security;

-- Students: office (owner/admin/operator) manages; an instructor reads the
-- students of their own classes.
drop policy if exists ds_students_select on public.ds_students;
create policy ds_students_select on public.ds_students for select to authenticated
  using (public.fn_org_has_feature(organization_id, 'students')
         and (public.is_org_operator_or_above(organization_id)
              or exists (select 1 from public.shift_blocks b
                          where b.student_id = ds_students.id and b.driver_id = auth.uid())));
drop policy if exists ds_students_write on public.ds_students;
create policy ds_students_write on public.ds_students for all to authenticated
  using (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'students'))
  with check (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'students')
              and (branch_id is null or exists (select 1 from public.branches br
                                                where br.id = branch_id and br.organization_id = ds_students.organization_id)));

drop policy if exists ds_student_private_all on public.ds_student_private;
create policy ds_student_private_all on public.ds_student_private for all to authenticated
  using (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'students'))
  with check (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'students')
              and exists (select 1 from public.ds_students s
                          where s.id = student_id and s.organization_id = ds_student_private.organization_id));

drop policy if exists ds_settings_select on public.ds_settings;
create policy ds_settings_select on public.ds_settings for select to authenticated
  using (public.fn_org_has_feature(organization_id, 'students'));
drop policy if exists ds_settings_write on public.ds_settings;
create policy ds_settings_write on public.ds_settings for all to authenticated
  using (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'students'))
  with check (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'students'));

drop policy if exists ds_skills_select on public.ds_skills;
create policy ds_skills_select on public.ds_skills for select to authenticated
  using (public.fn_org_has_feature(organization_id, 'student_evaluations'));
drop policy if exists ds_skills_write on public.ds_skills;
create policy ds_skills_write on public.ds_skills for all to authenticated
  using (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'student_evaluations'))
  with check (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'student_evaluations'));

-- Evaluations: written only through ds_submit_evaluation; read by the
-- office and by the instructor who wrote them.
drop policy if exists ds_evaluations_select on public.ds_evaluations;
create policy ds_evaluations_select on public.ds_evaluations for select to authenticated
  using (public.fn_org_has_feature(organization_id, 'student_evaluations')
         and (public.is_org_operator_or_above(organization_id) or instructor_id = auth.uid()));
drop policy if exists ds_evaluation_scores_select on public.ds_evaluation_scores;
create policy ds_evaluation_scores_select on public.ds_evaluation_scores for select to authenticated
  using (exists (select 1 from public.ds_evaluations e where e.id = evaluation_id));

drop policy if exists ds_packages_select on public.ds_packages;
create policy ds_packages_select on public.ds_packages for select to authenticated
  using (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'student_packages'));
drop policy if exists ds_packages_write on public.ds_packages;
create policy ds_packages_write on public.ds_packages for all to authenticated
  using (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'student_packages'))
  with check (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'student_packages'));

drop policy if exists ds_student_packages_all on public.ds_student_packages;
create policy ds_student_packages_all on public.ds_student_packages for all to authenticated
  using (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'student_packages'))
  with check (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'student_packages')
              and exists (select 1 from public.ds_students s
                          where s.id = student_id and s.organization_id = ds_student_packages.organization_id));

drop policy if exists ds_portal_links_select on public.ds_portal_links;
create policy ds_portal_links_select on public.ds_portal_links for select to authenticated
  using (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'student_portal'));

drop policy if exists ds_certificates_select on public.ds_certificates;
create policy ds_certificates_select on public.ds_certificates for select to authenticated
  using (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'student_certificates'));
-- (no policy on ds_reminders_sent: service role only)

-- ------------------------------------------------------------------
-- Hours: day / night from the class's real trip.
-- ------------------------------------------------------------------
-- Sunrise / sunset (NOAA / suncalc formulation, ~1 minute accuracy) for the
-- solar day closest to p_at at that place. Night = sunset to sunrise, the
-- definition state supervised-driving logs use.
create or replace function public.fn_sun_times(p_lat double precision, p_lng double precision, p_at timestamptz,
                                               out sunrise timestamptz, out sunset timestamptz)
language plpgsql immutable as $$
declare
  rad constant double precision := pi() / 180;
  j2000 constant double precision := 2451545;
  j0 constant double precision := 0.0009;
  lw double precision := rad * -p_lng;
  phi double precision := rad * p_lat;
  d double precision;
  n double precision;
  ds double precision;
  m double precision;
  c double precision;
  l double precision;
  dec double precision;
  jnoon double precision;
  cosw double precision;
  w double precision;
  jset double precision;
  jrise double precision;
begin
  d := extract(epoch from p_at) / 86400 - 0.5 + 2440588 - j2000;
  n := round(d - j0 - lw / (2 * pi()));
  ds := j0 + lw / (2 * pi()) + n;
  m := rad * (357.5291 + 0.98560028 * ds);
  c := rad * (1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m));
  l := m + c + rad * 102.9372 + pi();
  dec := asin(sin(l) * sin(rad * 23.4397));
  jnoon := j2000 + ds + 0.0053 * sin(m) - 0.0069 * sin(2 * l);
  cosw := (sin(rad * -0.833) - sin(phi) * sin(dec)) / (cos(phi) * cos(dec));
  cosw := greatest(-1, least(1, cosw));
  w := acos(cosw);
  jset := j2000 + (j0 + (w + lw) / (2 * pi()) + n) + 0.0053 * sin(m) - 0.0069 * sin(2 * l);
  jrise := jnoon - (jset - jnoon);
  sunrise := to_timestamp((jrise + 0.5 - 2440588) * 86400);
  sunset := to_timestamp((jset + 0.5 - 2440588) * 86400);
end $$;

-- Minutes, night minutes and miles of one class, from its trip (or the
-- class start/end if the trip is missing). Location: the trip's first GPS
-- point; without one, night = 8 pm to 6 am fleet time.
create or replace function public.fn_ds_class_numbers(p_block_id uuid,
  out minutes numeric, out night_minutes numeric, out miles numeric, out started timestamptz, out ended timestamptz)
language plpgsql stable security definer set search_path to 'public' as $$
declare
  b public.shift_blocks;
  s public.sessions;
  v_lat double precision;
  v_lng double precision;
  v_tz text;
  st record;
  v_dark_end timestamptz;
  v_dark_start timestamptz;
begin
  select * into b from public.shift_blocks where id = p_block_id;
  if b.id is null then return; end if;
  if b.session_id is not null then
    select * into s from public.sessions where id = b.session_id;
  end if;
  started := coalesce(s.start_time, b.started_at);
  ended := coalesce(s.end_time, b.ended_at);
  miles := coalesce(s.total_miles, 0);
  if started is null or ended is null or ended <= started then
    minutes := 0; night_minutes := 0; return;
  end if;
  minutes := round(extract(epoch from (ended - started)) / 60, 1);

  if s.id is not null then
    select latitude, longitude into v_lat, v_lng from public.session_gps_breadcrumbs
     where session_id = s.id order by recorded_at limit 1;
  end if;
  if v_lat is not null then
    st := public.fn_sun_times(v_lat, v_lng, started);
    v_dark_end := st.sunrise;
    v_dark_start := st.sunset;
  else
    select coalesce(timezone, 'America/New_York') into v_tz from public.organizations where id = b.organization_id;
    v_dark_end := ((started at time zone v_tz)::date + time '06:00') at time zone v_tz;
    v_dark_start := ((started at time zone v_tz)::date + time '20:00') at time zone v_tz;
  end if;
  night_minutes := round((
      greatest(0, extract(epoch from (least(ended, v_dark_end) - started)))
    + greatest(0, extract(epoch from (ended - greatest(started, v_dark_start))))
  ) / 60, 1);
  night_minutes := least(night_minutes, minutes);
end $$;
revoke execute on function public.fn_ds_class_numbers(uuid) from public, anon, authenticated;

-- Each student's progress: finished classes, hours, night hours, miles,
-- next class, hours bought. Office only.
create or replace function public.ds_student_progress(p_org uuid, p_student uuid default null)
returns table(student_id uuid, classes_done int, minutes numeric, night_minutes numeric, miles numeric,
              last_class date, next_class timestamptz, purchased_minutes numeric, evaluations int)
language plpgsql stable security definer set search_path to 'public' as $$
declare
  v_tz text;
begin
  if not public.is_org_operator_or_above(p_org) then raise exception 'Not authorized'; end if;
  perform public.fn_require_org_feature(p_org, 'students');
  select coalesce(timezone, 'America/New_York') into v_tz from public.organizations where id = p_org;
  return query
  with done as (
    select b.student_id sid, b.block_date, n.minutes, n.night_minutes, n.miles
      from public.shift_blocks b, lateral public.fn_ds_class_numbers(b.id) n
     where b.organization_id = p_org and b.student_id is not null and b.status = 'done'
       and (p_student is null or b.student_id = p_student)
  )
  select st.id,
         coalesce((select count(*)::int from done where sid = st.id), 0),
         coalesce((select sum(d.minutes) from done d where d.sid = st.id), 0),
         coalesce((select sum(d.night_minutes) from done d where d.sid = st.id), 0),
         coalesce((select round(sum(d.miles), 1) from done d where d.sid = st.id), 0),
         (select max(d.block_date) from done d where d.sid = st.id),
         (select min((b.block_date + b.start_time) at time zone v_tz) from public.shift_blocks b
           where b.student_id = st.id and b.status = 'scheduled'
             and (b.block_date + b.start_time) at time zone v_tz > now()),
         coalesce((select sum(sp.minutes)::numeric from public.ds_student_packages sp where sp.student_id = st.id), 0),
         coalesce((select count(*)::int from public.ds_evaluations e where e.student_id = st.id), 0)
    from public.ds_students st
   where st.organization_id = p_org and (p_student is null or st.id = p_student);
end $$;
revoke execute on function public.ds_student_progress(uuid, uuid) from public, anon;
grant execute on function public.ds_student_progress(uuid, uuid) to authenticated;

-- One student's finished classes with their numbers (office).
create or replace function public.ds_student_classes(p_student uuid)
returns table(block_id uuid, block_date date, start_time time, end_time time, status text,
              instructor_id uuid, vehicle_id uuid, session_id uuid, map_token text,
              minutes numeric, night_minutes numeric, miles numeric, evaluated boolean)
language plpgsql stable security definer set search_path to 'public' as $$
declare v_org uuid;
begin
  select organization_id into v_org from public.ds_students where id = p_student;
  if v_org is null or not public.is_org_operator_or_above(v_org) then raise exception 'Not authorized'; end if;
  perform public.fn_require_org_feature(v_org, 'students');
  return query
  select b.id, b.block_date, b.start_time, b.end_time, b.status, b.driver_id, b.vehicle_id, b.session_id, s.map_token::text,
         n.minutes, n.night_minutes, n.miles,
         exists (select 1 from public.ds_evaluations e where e.shift_block_id = b.id)
    from public.shift_blocks b
    left join public.sessions s on s.id = b.session_id
    cross join lateral public.fn_ds_class_numbers(b.id) n
   where b.student_id = p_student and b.status <> 'cancelled'
   order by b.block_date desc, b.start_time desc;
end $$;
revoke execute on function public.ds_student_classes(uuid) from public, anon;
grant execute on function public.ds_student_classes(uuid) to authenticated;

-- ------------------------------------------------------------------
-- Skills (report card)
-- ------------------------------------------------------------------
create or replace function public.ds_ensure_default_skills(p_org uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not public.is_org_member(p_org) then raise exception 'Not authorized'; end if;
  perform public.fn_require_org_feature(p_org, 'student_evaluations');
  if exists (select 1 from public.ds_skills where organization_id = p_org) then return; end if;
  insert into public.ds_skills (organization_id, category, name, sort)
  select p_org, c, n, row_number() over () from (values
    ('Vehicle control', 'Steering'), ('Vehicle control', 'Smooth braking'), ('Vehicle control', 'Smooth acceleration'),
    ('Vehicle control', 'Mirrors and blind spots'),
    ('Intersections', 'Stop signs and signals'), ('Intersections', 'Right-of-way'), ('Intersections', 'Turns'),
    ('Lanes', 'Lane position'), ('Lanes', 'Lane changes'), ('Lanes', 'Merging'),
    ('Speed and space', 'Speed control'), ('Speed and space', 'Following distance'), ('Speed and space', 'Hazard awareness'),
    ('Parking', 'Parallel parking'), ('Parking', 'Angle and perpendicular parking'), ('Parking', 'Backing up'),
    ('Highway', 'Entering and exiting'), ('Highway', 'Highway lane changes'),
    ('Rules', 'Signaling'), ('Rules', 'Traffic signs'), ('Rules', 'Pedestrians and school zones')
  ) as t(c, n);
end $$;
revoke execute on function public.ds_ensure_default_skills(uuid) from public, anon;
grant execute on function public.ds_ensure_default_skills(uuid) to authenticated;

-- The instructor of the class (or the office) saves its report card:
-- only the skills practiced, 1 (needs work) to 4 (mastered), and a note.
create or replace function public.ds_submit_evaluation(p_block_id uuid, p_scores jsonb, p_note text default null)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare
  b public.shift_blocks;
  v_eval uuid;
  r record;
begin
  select * into b from public.shift_blocks where id = p_block_id;
  if b.id is null or not (b.driver_id = auth.uid() or public.is_org_operator_or_above(b.organization_id)) then
    raise exception 'Not authorized';
  end if;
  perform public.fn_require_org_feature(b.organization_id, 'student_evaluations');
  if b.student_id is null then raise exception 'CLASS_HAS_NO_STUDENT'; end if;
  if b.status not in ('in_progress', 'done') then raise exception 'CLASS_NOT_STARTED'; end if;
  if p_scores is null or jsonb_typeof(p_scores) <> 'object' or p_scores = '{}'::jsonb then
    raise exception 'RATE_AT_LEAST_ONE_SKILL';
  end if;

  insert into public.ds_evaluations (organization_id, shift_block_id, student_id, instructor_id, note)
  values (b.organization_id, b.id, b.student_id, b.driver_id, nullif(btrim(p_note), ''))
  on conflict (shift_block_id) do update set note = excluded.note
  returning id into v_eval;

  delete from public.ds_evaluation_scores where evaluation_id = v_eval;
  for r in select key, value from jsonb_each_text(p_scores) loop
    if not exists (select 1 from public.ds_skills k where k.id = r.key::uuid and k.organization_id = b.organization_id) then
      raise exception 'Unknown skill';
    end if;
    insert into public.ds_evaluation_scores (evaluation_id, skill_id, score)
    values (v_eval, r.key::uuid, r.value::smallint);
  end loop;
  return v_eval;
end $$;
revoke execute on function public.ds_submit_evaluation(uuid, jsonb, text) from public, anon;
grant execute on function public.ds_submit_evaluation(uuid, jsonb, text) to authenticated;

-- The instructor's classes today now carry the student and whether the
-- class was evaluated (app). Added to the existing function's output.
do $$
declare d text := pg_get_functiondef('public.get_my_shift_day(uuid)'::regprocedure);
begin
  if strpos(d, '''student_name''') = 0 then
    d := replace(d,
      E'      ''late_minutes'', b.late_minutes,\n',
      E'      ''late_minutes'', b.late_minutes,\n      ''student_id'', b.student_id,\n      ''student_name'', nullif(concat_ws('' '', st.first_name, st.last_name), ''''),\n      ''evaluated'', exists (select 1 from public.ds_evaluations e where e.shift_block_id = b.id),\n');
    d := replace(d,
      E'  left join public.vehicles v on v.id = b.vehicle_id\n',
      E'  left join public.vehicles v on v.id = b.vehicle_id\n  left join public.ds_students st on st.id = b.student_id\n');
    if strpos(d, 'left join public.ds_students st') = 0 or strpos(d, '''student_name''') = 0 then
      raise exception 'get_my_shift_day: anchors not found';
    end if;
    execute d;
  end if;
end $$;

-- ------------------------------------------------------------------
-- Portal by link (no account) and certificate
-- ------------------------------------------------------------------
create or replace function public.ds_create_portal_link(p_student uuid)
returns text language plpgsql security definer set search_path to 'public', 'extensions' as $$
declare
  v_org uuid;
  v_token text;
begin
  select organization_id into v_org from public.ds_students where id = p_student;
  if v_org is null or not public.is_org_operator_or_above(v_org) then raise exception 'Not authorized'; end if;
  perform public.fn_require_org_feature(v_org, 'student_portal');
  -- One live link per student: a new one replaces the old.
  update public.ds_portal_links set revoked_at = now() where student_id = p_student and revoked_at is null;
  v_token := encode(gen_random_bytes(24), 'hex');
  insert into public.ds_portal_links (organization_id, student_id, token_hash, created_by)
  values (v_org, p_student, encode(digest(v_token, 'sha256'), 'hex'), auth.uid());
  return v_token;
end $$;
revoke execute on function public.ds_create_portal_link(uuid) from public, anon;
grant execute on function public.ds_create_portal_link(uuid) to authenticated;

create or replace function public.ds_revoke_portal_link(p_student uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
declare v_org uuid;
begin
  select organization_id into v_org from public.ds_students where id = p_student;
  if v_org is null or not public.is_org_operator_or_above(v_org) then raise exception 'Not authorized'; end if;
  update public.ds_portal_links set revoked_at = now() where student_id = p_student and revoked_at is null;
end $$;
revoke execute on function public.ds_revoke_portal_link(uuid) from public, anon;
grant execute on function public.ds_revoke_portal_link(uuid) to authenticated;

-- Shared snapshot of a student's record (portal and certificate).
create or replace function public.fn_ds_student_snapshot(p_student uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare
  st public.ds_students;
  v_tz text;
  v_org_name text;
  v_set public.ds_settings;
  v_classes jsonb;
  v_upcoming jsonb;
begin
  select * into st from public.ds_students where id = p_student;
  if st.id is null then return null; end if;
  select coalesce(timezone, 'America/New_York'), coalesce(report_display_name, name) into v_tz, v_org_name
    from public.organizations where id = st.organization_id;
  select * into v_set from public.ds_settings where organization_id = st.organization_id;

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

  select coalesce(jsonb_agg(jsonb_build_object('date', b.block_date, 'start', b.start_time, 'end', b.end_time,
           'instructor', nullif(concat_ws(' ', p.first_name, left(p.last_name, 1)), ''))
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
    'required_minutes', coalesce(v_set.required_minutes, 360),
    'required_night_minutes', coalesce(v_set.required_night_minutes, 0),
    'classes', v_classes,
    'upcoming', v_upcoming,
    'minutes', (select coalesce(sum((c->>'minutes')::numeric), 0) from jsonb_array_elements(v_classes) c),
    'night_minutes', (select coalesce(sum((c->>'night_minutes')::numeric), 0) from jsonb_array_elements(v_classes) c),
    'miles', (select coalesce(round(sum((c->>'miles')::numeric), 1), 0) from jsonb_array_elements(v_classes) c)
  );
end $$;
revoke execute on function public.fn_ds_student_snapshot(uuid) from public, anon, authenticated;

-- What a parent/student sees with their link. Anonymous on purpose (no
-- account): the token is the key, stored only as a hash, revocable, expiring.
create or replace function public.ds_portal_view(p_token text)
returns jsonb language plpgsql stable security definer set search_path to 'public', 'extensions' as $$
declare
  l public.ds_portal_links;
  v jsonb;
begin
  select * into l from public.ds_portal_links
   where token_hash = encode(digest(coalesce(p_token, ''), 'sha256'), 'hex')
     and revoked_at is null and expires_at > now();
  if l.id is null then return null; end if;
  if not public.fn_org_feature_internal(l.organization_id, 'student_portal') then return null; end if;
  v := public.fn_ds_student_snapshot(l.student_id);
  return v || jsonb_build_object('certificates',
    coalesce((select jsonb_agg(jsonb_build_object('number', c.number, 'issued_at', c.issued_at, 'sha256', c.sha256) order by c.issued_at)
                from public.ds_certificates c where c.student_id = l.student_id), '[]'::jsonb));
end $$;
revoke execute on function public.ds_portal_view(text) from public;
grant execute on function public.ds_portal_view(text) to anon, authenticated;

-- Certificate: only once the school's required hours (and night hours)
-- are met; the snapshot is stored and sealed with its SHA-256.
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
     or (v->>'night_minutes')::numeric < (v->>'required_night_minutes')::numeric then
    raise exception 'REQUIRED_HOURS_NOT_MET';
  end if;
  v_number := 'CM-' || to_char(now() at time zone (v->>'timezone'), 'YYYYMMDD') || '-' || upper(substr(replace(v_id::text, '-', ''), 1, 6));
  v := (v - 'upcoming') || jsonb_build_object('number', v_number, 'issued_at', now());
  insert into public.ds_certificates (id, number, organization_id, student_id, data, sha256, issued_by)
  values (v_id, v_number, v_org, p_student, v, encode(digest(v::text, 'sha256'), 'hex'), auth.uid());
  return v_id;
end $$;
revoke execute on function public.ds_issue_certificate(uuid) from public, anon;
grant execute on function public.ds_issue_certificate(uuid) to authenticated;

-- ------------------------------------------------------------------
-- Reminders: classes starting within the school's reminder window that
-- haven't been reminded yet (service role, send-class-reminders).
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
    left join public.ds_settings cfg on cfg.organization_id = b.organization_id
    left join public.profiles p on p.id = b.driver_id
    cross join lateral (values (st.email), (st.guardian_email)) as r(email)
   where b.status = 'scheduled'
     and r.email is not null and btrim(r.email) <> ''
     and (b.block_date + b.start_time) at time zone coalesce(o.timezone, 'America/New_York')
         between now() and now() + make_interval(hours => coalesce(cfg.reminder_hours, 24))
     and public.fn_org_feature_internal(b.organization_id, 'class_reminders')
     and not exists (select 1 from public.ds_reminders_sent x
                      where x.shift_block_id = b.id and x.recipient = lower(btrim(r.email)));
$$;
revoke execute on function public.ds_due_class_reminders() from public, anon, authenticated;

-- A certificate's sealed data, for the portal link that belongs to the
-- same student (download from the portal, no account).
create or replace function public.ds_portal_certificate(p_token text, p_number text)
returns jsonb language plpgsql stable security definer set search_path to 'public', 'extensions' as $$
declare
  l public.ds_portal_links;
  c public.ds_certificates;
begin
  select * into l from public.ds_portal_links
   where token_hash = encode(digest(coalesce(p_token, ''), 'sha256'), 'hex')
     and revoked_at is null and expires_at > now();
  if l.id is null or not public.fn_org_feature_internal(l.organization_id, 'student_portal') then return null; end if;
  select * into c from public.ds_certificates where student_id = l.student_id and number = p_number;
  if c.id is null then return null; end if;
  return jsonb_build_object('data', c.data, 'sha256', c.sha256, 'number', c.number, 'issued_at', c.issued_at);
end $$;
revoke execute on function public.ds_portal_certificate(text, text) from public;
grant execute on function public.ds_portal_certificate(text, text) to anon, authenticated;
