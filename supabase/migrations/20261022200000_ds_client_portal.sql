-- Driving school client portal (2026-10-22, owner's spec).
--   * A driving school's clients are adult students, minors and the parents
--     of minors. They use the website only (nobody installs an app for a
--     month of lessons); instructors keep using the Fleet app. Owners,
--     admins and operators sign in to the website as before; clients get a
--     light profile next to them: name, email and their students, nothing
--     of the fleet.
--   * A minor sits under the parent if, and only if, the minor is not
--     emancipated: the link counts only while the student's birth date says
--     minor in the school's age of majority (18 by default, up to 21) and no
--     admin has recorded an emancipation. At majority or emancipation the
--     parent stops seeing the student at once (every read checks it) and a
--     daily job closes the link on record. Only an admin or the owner can
--     record an emancipation, after seeing the document; a parent can't.
--   * A parent registers more children from the portal; each one is an
--     enrollment request the school approves, as on the public page. Until
--     then the parent sees nothing of that child.
--   * Sign-in is a link sent by email (Resend), no password: the
--     ds-portal-access function asks ds_client_request_links for one link
--     per school that has that email, and answers the same whether or not it
--     has any. Opening the link gives a 30-day session the website keeps in
--     an httpOnly cookie. Tokens are stored hashed, like ds_portal_links.
--   * The per-student portal links (ds_portal_links) keep working: their
--     functions now call the same internals as the client portal.

set local lock_timeout = '5s';

insert into ops.domain_tables (tbl, domain) values
  ('ds_clients', 'driving_school'),
  ('ds_client_students', 'driving_school'),
  ('ds_client_tokens', 'driving_school')
on conflict (tbl) do update set domain = excluded.domain;

-- ------------------------------------------------------------------
-- Age of majority and emancipation
-- ------------------------------------------------------------------
alter table public.ds_settings
  add column if not exists age_of_majority smallint not null default 18 check (age_of_majority between 18 and 21);

alter table public.ds_students
  add column if not exists emancipated_at timestamptz,
  add column if not exists emancipated_by uuid references auth.users(id) on delete set null,
  add column if not exists emancipation_note text check (emancipation_note is null or length(emancipation_note) <= 300);

-- Minor = birth date known, under the school's age of majority today (in
-- the school's time zone) and not emancipated. Unknown birth date = not a
-- minor here: a parent never sees a student whose age the school can't show.
create or replace function public.fn_ds_is_minor(p_student uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select coalesce((
    select st.emancipated_at is null
       and coalesce(st.birth_date, pv.date_of_birth) is not null
       and coalesce(st.birth_date, pv.date_of_birth) + make_interval(years => coalesce(cfg.age_of_majority, 18))
           > (now() at time zone coalesce(o.timezone, 'America/New_York'))::date
      from public.ds_students st
      join public.organizations o on o.id = st.organization_id
      left join public.ds_student_private pv on pv.student_id = st.id
      left join public.ds_settings cfg on cfg.organization_id = st.organization_id
     where st.id = p_student), false);
$$;
revoke execute on function public.fn_ds_is_minor(uuid) from public, anon, authenticated;

-- ------------------------------------------------------------------
-- Tables
-- ------------------------------------------------------------------
create table if not exists public.ds_clients (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  email text not null check (email = lower(btrim(email)) and length(email) <= 120
                             and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  first_name text not null check (length(btrim(first_name)) between 1 and 60),
  last_name text not null check (length(btrim(last_name)) between 1 and 60),
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  last_seen_at timestamptz,
  unique (organization_id, email)
);

create table if not exists public.ds_client_students (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  client_id uuid not null references public.ds_clients(id) on delete cascade,
  student_id uuid not null references public.ds_students(id) on delete cascade,
  relation text not null check (relation in ('self', 'guardian')),
  -- Ending keeps the row: who could see a student, and why it ended,
  -- stays on record.
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  ended_at timestamptz,
  ended_reason text check (ended_reason is null or ended_reason in ('majority', 'emancipated', 'revoked')),
  unique (client_id, student_id)
);
create index if not exists ds_client_students_student_idx on public.ds_client_students (student_id);
-- A student has one own (adult) profile at a time.
create unique index if not exists ds_client_students_one_self
  on public.ds_client_students (student_id) where relation = 'self' and is_active;

create table if not exists public.ds_client_tokens (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  client_id uuid not null references public.ds_clients(id) on delete cascade,
  kind text not null check (kind in ('link', 'session')),
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  used_at timestamptz,
  revoked_at timestamptz
);
create index if not exists ds_client_tokens_client_idx on public.ds_client_tokens (client_id);

alter table public.ds_enrollment_requests
  add column if not exists client_id uuid references public.ds_clients(id) on delete set null;

alter table public.ds_clients enable row level security;
alter table public.ds_client_students enable row level security;
alter table public.ds_client_tokens enable row level security;

-- Staff read; every write goes through the functions below. Tokens: no
-- policy at all (functions only).
create policy ds_clients_select on public.ds_clients for select
  using (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'student_portal'));
create policy ds_client_students_select on public.ds_client_students for select
  using (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'student_portal'));

-- ------------------------------------------------------------------
-- Portal internals, by student (shared by both portals)
-- ------------------------------------------------------------------
create or replace function public.fn_ds_portal_payload(p_student uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare
  st public.ds_students;
  cfg public.ds_settings;
  bal record;
  v_booking boolean;
begin
  select * into st from public.ds_students where id = p_student;
  if st.id is null or not public.fn_org_feature_internal(st.organization_id, 'student_portal') then return null; end if;
  select * into cfg from public.ds_settings where organization_id = st.organization_id;
  bal := public.fn_ds_balance(st.id);
  v_booking := public.fn_org_feature_internal(st.organization_id, 'student_booking') and coalesce(cfg.booking_enabled, false)
               and st.status in ('registered', 'active') and st.program_id is not null;
  return public.fn_ds_student_snapshot(st.id) || jsonb_build_object(
    'certificates', coalesce((select jsonb_agg(jsonb_build_object('number', c.number, 'issued_at', c.issued_at, 'sha256', c.sha256) order by c.issued_at)
                                from public.ds_certificates c where c.student_id = st.id), '[]'::jsonb),
    'booking', jsonb_build_object(
       'enabled', v_booking,
       'cancel_free_hours', coalesce(cfg.cancel_free_hours, 24),
       'policy', cfg.cancellation_policy,
       'max_upcoming', coalesce(cfg.booking_max_upcoming, 2)),
    'balance', case when public.fn_org_feature_internal(st.organization_id, 'student_packages')
                     and exists (select 1 from public.ds_student_packages where student_id = st.id)
                    then jsonb_build_object('purchased', bal.purchased, 'used', bal.used, 'booked', bal.booked,
                                            'available', bal.purchased - bal.used - bal.booked)
                    else null end,
    'sms', jsonb_build_object('available', public.fn_org_feature_internal(st.organization_id, 'sms_reminders'),
                              'consent', st.sms_consent_at is not null,
                              'phone', st.sms_consent_phone)
  );
end $$;
revoke execute on function public.fn_ds_portal_payload(uuid) from public, anon, authenticated;

create or replace function public.fn_ds_portal_slots_for(p_student uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare
  st public.ds_students;
  pr public.ds_programs;
  cfg public.ds_settings;
  v_tz text;
begin
  select * into st from public.ds_students where id = p_student;
  if st.id is null then return null; end if;
  if not public.fn_org_feature_internal(st.organization_id, 'student_booking') then return null; end if;
  select * into cfg from public.ds_settings where organization_id = st.organization_id;
  if not coalesce(cfg.booking_enabled, false) then return null; end if;
  select * into pr from public.ds_programs where id = st.program_id and is_active;
  if pr.id is null or st.status not in ('registered', 'active') then return null; end if;
  select coalesce(timezone, 'America/New_York') into v_tz from public.organizations where id = st.organization_id;
  return jsonb_build_object(
    'minutes', pr.class_minutes,
    'language', st.preferred_language,
    'slots', coalesce((
      select jsonb_agg(jsonb_build_object('date', t.block_date, 'start', t.start_time, 'end', t.end_time)
                       order by t.block_date, t.start_time)
        from (select distinct s.block_date, s.start_time, s.end_time
                from public.fn_ds_free_slots(st.organization_id, pr.class_minutes, (now() at time zone v_tz)::date,
                                             cfg.booking_horizon_days, cfg.booking_lead_hours) s
                join public.organization_members m
                  on m.organization_id = st.organization_id and m.user_id = s.instructor_id
               where (st.preferred_language is null or st.preferred_language = any (m.languages))
                 and (st.branch_id is null or m.any_branch or m.branch_id is null or m.branch_id = st.branch_id)) t), '[]'::jsonb)
  );
end $$;
revoke execute on function public.fn_ds_portal_slots_for(uuid) from public, anon, authenticated;

create or replace function public.fn_ds_portal_book_for(p_student uuid, p_date date, p_start time)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare
  st public.ds_students;
  pr public.ds_programs;
  cfg public.ds_settings;
  v_tz text;
  s record;
  bal record;
  v_upcoming int;
  v_id uuid;
begin
  select * into st from public.ds_students where id = p_student;
  if st.id is null then raise exception 'LINK_NOT_ACTIVE'; end if;
  perform public.fn_require_org_feature(st.organization_id, 'student_booking');
  select * into cfg from public.ds_settings where organization_id = st.organization_id;
  if not coalesce(cfg.booking_enabled, false) then raise exception 'BOOKING_OFF'; end if;
  select * into pr from public.ds_programs where id = st.program_id and is_active;
  if pr.id is null or st.status not in ('registered', 'active') then raise exception 'BOOKING_OFF'; end if;
  select coalesce(timezone, 'America/New_York') into v_tz from public.organizations where id = st.organization_id;

  perform pg_advisory_xact_lock(hashtext(st.organization_id::text || p_date::text || p_start::text));

  select count(*) into v_upcoming from public.shift_blocks
   where student_id = st.id and status = 'scheduled' and (block_date + start_time) at time zone v_tz > now();
  if v_upcoming >= cfg.booking_max_upcoming then raise exception 'TOO_MANY_UPCOMING'; end if;

  if public.fn_org_feature_internal(st.organization_id, 'student_packages')
     and exists (select 1 from public.ds_packages where organization_id = st.organization_id and is_active) then
    bal := public.fn_ds_balance(st.id);
    if bal.purchased - bal.used - bal.booked < pr.class_minutes then raise exception 'NO_BALANCE'; end if;
  end if;

  select f.* into s
    from public.fn_ds_free_slots(st.organization_id, pr.class_minutes, p_date, 1, cfg.booking_lead_hours) f
    join public.organization_members m on m.organization_id = st.organization_id and m.user_id = f.instructor_id
   where f.start_time = p_start
     and p_date <= (now() at time zone v_tz)::date + cfg.booking_horizon_days
     and (st.preferred_language is null or st.preferred_language = any (m.languages))
     and (st.branch_id is null or m.any_branch or m.branch_id is null or m.branch_id = st.branch_id)
   order by random()
   limit 1;
  if s.instructor_id is null then raise exception 'SLOT_TAKEN'; end if;

  insert into public.shift_blocks (organization_id, driver_id, vehicle_id, block_date, start_time, end_time, source,
                                   status, student_id, booked_via, note)
  values (st.organization_id, s.instructor_id, s.vehicle_id, s.block_date, s.start_time, s.end_time, 'one_off',
          'scheduled', st.id, 'portal', 'Booked online')
  returning id into v_id;
  return v_id;
end $$;
revoke execute on function public.fn_ds_portal_book_for(uuid, date, time) from public, anon, authenticated;

create or replace function public.fn_ds_portal_cancel_for(p_student uuid, p_block uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  b public.shift_blocks;
  cfg public.ds_settings;
  st public.ds_students;
  v_tz text;
  v_starts timestamptz;
  v_late boolean;
begin
  select * into st from public.ds_students where id = p_student;
  if st.id is null then raise exception 'LINK_NOT_ACTIVE'; end if;
  perform public.fn_require_org_feature(st.organization_id, 'student_booking');
  select * into b from public.shift_blocks where id = p_block and student_id = st.id;
  if b.id is null or b.status <> 'scheduled' then raise exception 'CLASS_NOT_CANCELLABLE'; end if;
  select * into cfg from public.ds_settings where organization_id = st.organization_id;
  select coalesce(timezone, 'America/New_York') into v_tz from public.organizations where id = st.organization_id;
  v_starts := (b.block_date + b.start_time) at time zone v_tz;
  if v_starts <= now() then raise exception 'CLASS_NOT_CANCELLABLE'; end if;
  v_late := v_starts - now() < make_interval(hours => coalesce(cfg.cancel_free_hours, 24));

  update public.shift_blocks set status = 'cancelled', cancelled_at = now(), late_cancel = v_late where id = b.id;

  if v_starts > now() + make_interval(hours => coalesce(cfg.booking_lead_hours, 24)) then
    insert into public.ds_slot_notices (organization_id, program_id, instructor_id, vehicle_id, block_date, start_time, end_time, freed_by_student)
    values (st.organization_id, st.program_id, b.driver_id, b.vehicle_id, b.block_date, b.start_time, b.end_time, st.id);
  end if;
  return jsonb_build_object('late', v_late);
end $$;
revoke execute on function public.fn_ds_portal_cancel_for(uuid, uuid) from public, anon, authenticated;

create or replace function public.fn_ds_portal_set_sms_for(p_student uuid, p_on boolean, p_phone text)
returns void language plpgsql security definer set search_path to 'public' as $$
declare
  v_org uuid;
  v_phone text := nullif(regexp_replace(coalesce(p_phone, ''), '[^0-9+]', '', 'g'), '');
begin
  select organization_id into v_org from public.ds_students where id = p_student;
  if v_org is null then raise exception 'LINK_NOT_ACTIVE'; end if;
  perform public.fn_require_org_feature(v_org, 'sms_reminders');
  if p_on then
    if v_phone is null or length(v_phone) < 10 then raise exception 'PHONE_REQUIRED'; end if;
    update public.ds_students set sms_consent_at = now(), sms_consent_phone = v_phone, sms_consent_source = 'portal'
     where id = p_student;
  else
    update public.ds_students set sms_consent_at = null, sms_consent_phone = null, sms_consent_source = null
     where id = p_student;
  end if;
end $$;
revoke execute on function public.fn_ds_portal_set_sms_for(uuid, boolean, text) from public, anon, authenticated;

create or replace function public.fn_ds_portal_certificate_for(p_student uuid, p_number text)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare
  c public.ds_certificates;
  v_org uuid;
begin
  select organization_id into v_org from public.ds_students where id = p_student;
  if v_org is null or not public.fn_org_feature_internal(v_org, 'student_portal') then return null; end if;
  select * into c from public.ds_certificates where student_id = p_student and number = p_number;
  if c.id is null then return null; end if;
  return jsonb_build_object('data', c.data, 'sha256', c.sha256, 'number', c.number, 'issued_at', c.issued_at);
end $$;
revoke execute on function public.fn_ds_portal_certificate_for(uuid, text) from public, anon, authenticated;

-- The per-student link portal, same behaviour, now on the internals.
create or replace function public.ds_portal_view(p_token text)
returns jsonb language plpgsql stable security definer set search_path to 'public', 'extensions' as $$
declare
  l public.ds_portal_links := public.fn_ds_portal_link(p_token);
begin
  if l.id is null then return null; end if;
  return public.fn_ds_portal_payload(l.student_id);
end $$;

create or replace function public.ds_portal_slots(p_token text)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare
  l public.ds_portal_links := public.fn_ds_portal_link(p_token);
begin
  if l.id is null then return null; end if;
  return public.fn_ds_portal_slots_for(l.student_id);
end $$;

create or replace function public.ds_portal_book(p_token text, p_date date, p_start time)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare
  l public.ds_portal_links := public.fn_ds_portal_link(p_token);
begin
  if l.id is null then raise exception 'LINK_NOT_ACTIVE'; end if;
  return public.fn_ds_portal_book_for(l.student_id, p_date, p_start);
end $$;

create or replace function public.ds_portal_cancel(p_token text, p_block uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  l public.ds_portal_links := public.fn_ds_portal_link(p_token);
begin
  if l.id is null then raise exception 'LINK_NOT_ACTIVE'; end if;
  return public.fn_ds_portal_cancel_for(l.student_id, p_block);
end $$;

create or replace function public.ds_portal_set_sms(p_token text, p_on boolean, p_phone text default null)
returns void language plpgsql security definer set search_path to 'public' as $$
declare
  l public.ds_portal_links := public.fn_ds_portal_link(p_token);
begin
  if l.id is null then raise exception 'LINK_NOT_ACTIVE'; end if;
  perform public.fn_ds_portal_set_sms_for(l.student_id, p_on, p_phone);
end $$;

create or replace function public.ds_portal_certificate(p_token text, p_number text)
returns jsonb language plpgsql stable security definer set search_path to 'public', 'extensions' as $$
declare
  l public.ds_portal_links := public.fn_ds_portal_link(p_token);
begin
  if l.id is null then return null; end if;
  return public.fn_ds_portal_certificate_for(l.student_id, p_number);
end $$;

-- ------------------------------------------------------------------
-- Clients: who sees which student
-- ------------------------------------------------------------------
create or replace function public.fn_ds_client_session(p_session text)
returns public.ds_clients language sql stable security definer set search_path to 'public', 'extensions' as $$
  select c.* from public.ds_client_tokens t
    join public.ds_clients c on c.id = t.client_id
   where t.token_hash = encode(digest(coalesce(p_session, ''), 'sha256'), 'hex')
     and t.kind = 'session' and t.revoked_at is null and t.expires_at > now()
     and c.is_active and public.fn_org_feature_internal(c.organization_id, 'student_portal');
$$;
revoke execute on function public.fn_ds_client_session(text) from public, anon, authenticated;

-- The rule itself: a parent sees a minor, an adult sees themself.
create or replace function public.fn_ds_link_counts(p_relation text, p_student uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select case p_relation
           when 'guardian' then public.fn_ds_is_minor(p_student)
           when 'self' then not public.fn_ds_is_minor(p_student)
           else false end;
$$;
revoke execute on function public.fn_ds_link_counts(text, uuid) from public, anon, authenticated;

-- The student, if this session may see them; raises otherwise.
create or replace function public.fn_ds_client_student(p_session text, p_student uuid)
returns uuid language plpgsql stable security definer set search_path to 'public' as $$
declare
  c public.ds_clients := public.fn_ds_client_session(p_session);
  v uuid;
begin
  if c.id is null then raise exception 'SESSION_ENDED'; end if;
  select cs.student_id into v from public.ds_client_students cs
   where cs.client_id = c.id and cs.student_id = p_student and cs.is_active
     and public.fn_ds_link_counts(cs.relation, cs.student_id);
  if v is null then raise exception 'NO_ACCESS'; end if;
  return v;
end $$;
revoke execute on function public.fn_ds_client_student(text, uuid) from public, anon, authenticated;

create or replace function public.fn_ds_upsert_client(p_org uuid, p_email text, p_first text, p_last text, p_reactivate boolean)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_id uuid;
  v_active boolean;
begin
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or length(v_email) > 120 then raise exception 'EMAIL' using errcode = 'P0001'; end if;
  select id, is_active into v_id, v_active from public.ds_clients where organization_id = p_org and email = v_email;
  if v_id is null then
    insert into public.ds_clients (organization_id, email, first_name, last_name, created_by)
    values (p_org, v_email, left(btrim(p_first), 60), left(btrim(p_last), 60), auth.uid())
    returning id into v_id;
  elsif not v_active then
    -- A revoked client comes back only by an explicit staff action.
    if not p_reactivate then return null; end if;
    update public.ds_clients set is_active = true, revoked_at = null where id = v_id;
  end if;
  return v_id;
end $$;
revoke execute on function public.fn_ds_upsert_client(uuid, text, text, text, boolean) from public, anon, authenticated;

create or replace function public.fn_ds_link_client(p_client uuid, p_student uuid, p_relation text)
returns void language plpgsql security definer set search_path to 'public' as $$
declare
  v_org uuid;
begin
  select organization_id into v_org from public.ds_students where id = p_student;
  if p_relation = 'self' then
    update public.ds_client_students set is_active = false, ended_at = now(), ended_reason = 'revoked'
     where student_id = p_student and relation = 'self' and is_active and client_id <> p_client;
  end if;
  insert into public.ds_client_students (organization_id, client_id, student_id, relation)
  values (v_org, p_client, p_student, p_relation)
  on conflict (client_id, student_id) do update
    set relation = excluded.relation, is_active = true, ended_at = null, ended_reason = null;
end $$;
revoke execute on function public.fn_ds_link_client(uuid, uuid, text) from public, anon, authenticated;

-- Approving a request also gives its family a profile: the parent of a
-- minor (the one who registered from the portal, or the guardian email on
-- the request), or the adult student themself.
create or replace function public.ds_enrollment_approve(p_id uuid)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare
  r public.ds_enrollment_requests;
  v_student uuid;
  v_client uuid;
  v_first text;
  v_last text;
begin
  select * into r from public.ds_enrollment_requests where id = p_id for update;
  if r.id is null then raise exception 'That request is gone' using errcode = 'P0001'; end if;
  if not public.is_org_operator_or_above(r.organization_id) or not public.fn_org_has_feature(r.organization_id, 'student_portal') then
    raise exception 'Not authorized';
  end if;
  if r.status = 'approved' and r.student_id is not null then return r.student_id; end if;
  insert into public.ds_students (
    organization_id, first_name, last_name, birth_date, email, phone,
    guardian_name, guardian_email, guardian_phone, status, program_id, branch_id, notes,
    sms_consent_at, sms_consent_phone, sms_consent_source, created_by, preferred_language)
  values (
    r.organization_id, r.first_name, r.last_name, r.birth_date, r.email, r.phone,
    r.guardian_name, r.guardian_email, r.guardian_phone, 'registered', r.program_id, r.branch_id,
    left(concat_ws(E'\n',
      'Online request ' || to_char(r.created_at, 'YYYY-MM-DD') || ', consent by ' || r.consent_by || ' (' || r.consent_name || ').',
      r.message), 1000),
    case when r.sms_opt_in then r.consent_at end,
    case when r.sms_opt_in then r.sms_phone end,
    case when r.sms_opt_in then 'online_request' end,
    auth.uid(), r.preferred_language)
  returning id into v_student;
  update public.ds_enrollment_requests
     set status = 'approved', student_id = v_student, decided_at = now(), decided_by = auth.uid()
   where id = r.id;

  if public.fn_ds_is_minor(v_student) then
    if r.client_id is not null then
      v_client := (select id from public.ds_clients where id = r.client_id and is_active);
    elsif r.guardian_email is not null then
      v_first := split_part(btrim(coalesce(r.guardian_name, '')), ' ', 1);
      v_last := nullif(btrim(substr(btrim(coalesce(r.guardian_name, '')), length(v_first) + 1)), '');
      v_client := public.fn_ds_upsert_client(r.organization_id, r.guardian_email,
                                             coalesce(nullif(v_first, ''), r.last_name), coalesce(v_last, r.last_name), false);
    end if;
    if v_client is not null then perform public.fn_ds_link_client(v_client, v_student, 'guardian'); end if;
  elsif r.email is not null then
    v_client := public.fn_ds_upsert_client(r.organization_id, r.email, r.first_name, r.last_name, false);
    if v_client is not null then perform public.fn_ds_link_client(v_client, v_student, 'self'); end if;
  end if;
  return v_student;
end $$;

-- ------------------------------------------------------------------
-- Staff: profiles, emancipation, welcome link
-- ------------------------------------------------------------------
create or replace function public.ds_client_link(p_student uuid, p_email text, p_first_name text, p_last_name text, p_relation text)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare
  v_org uuid;
  v_client uuid;
begin
  select organization_id into v_org from public.ds_students where id = p_student;
  if v_org is null or not public.is_org_operator_or_above(v_org) then raise exception 'Not authorized'; end if;
  perform public.fn_require_org_feature(v_org, 'student_portal');
  if p_relation not in ('self', 'guardian') then raise exception 'INVALID' using errcode = 'P0001'; end if;
  if length(btrim(coalesce(p_first_name, ''))) = 0 or length(btrim(coalesce(p_last_name, ''))) = 0 then
    raise exception 'NAME_REQUIRED' using errcode = 'P0001';
  end if;
  -- A parent only for a minor (birth date on file, not emancipated); an
  -- own profile only for an adult or an emancipated minor.
  if p_relation = 'guardian' and not public.fn_ds_is_minor(p_student) then
    raise exception 'NOT_A_MINOR' using errcode = 'P0001';
  end if;
  if p_relation = 'self' and public.fn_ds_is_minor(p_student) then
    raise exception 'STUDENT_IS_MINOR' using errcode = 'P0001';
  end if;
  v_client := public.fn_ds_upsert_client(v_org, p_email, p_first_name, p_last_name, true);
  perform public.fn_ds_link_client(v_client, p_student, p_relation);
  return v_client;
end $$;
revoke execute on function public.ds_client_link(uuid, text, text, text, text) from public, anon;
grant execute on function public.ds_client_link(uuid, text, text, text, text) to authenticated;

create or replace function public.ds_client_unlink(p_client uuid, p_student uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
declare
  v_org uuid;
begin
  select organization_id into v_org from public.ds_clients where id = p_client;
  if v_org is null or not public.is_org_operator_or_above(v_org) then raise exception 'Not authorized'; end if;
  update public.ds_client_students set is_active = false, ended_at = now(), ended_reason = 'revoked'
   where client_id = p_client and student_id = p_student and is_active;
end $$;
revoke execute on function public.ds_client_unlink(uuid, uuid) from public, anon;
grant execute on function public.ds_client_unlink(uuid, uuid) to authenticated;

create or replace function public.ds_client_revoke(p_client uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
declare
  v_org uuid;
begin
  select organization_id into v_org from public.ds_clients where id = p_client;
  if v_org is null or not public.is_org_operator_or_above(v_org) then raise exception 'Not authorized'; end if;
  update public.ds_clients set is_active = false, revoked_at = now() where id = p_client;
  update public.ds_client_tokens set revoked_at = now() where client_id = p_client and revoked_at is null;
  update public.ds_client_students set is_active = false, ended_at = now(), ended_reason = 'revoked'
   where client_id = p_client and is_active;
end $$;
revoke execute on function public.ds_client_revoke(uuid) from public, anon;
grant execute on function public.ds_client_revoke(uuid) to authenticated;

-- Admin or owner only, with what was seen (the document).
create or replace function public.ds_set_emancipation(p_student uuid, p_emancipated boolean, p_note text)
returns void language plpgsql security definer set search_path to 'public' as $$
declare
  v_org uuid;
begin
  select organization_id into v_org from public.ds_students where id = p_student;
  if v_org is null or not public.is_org_admin_or_owner(v_org) then raise exception 'Not authorized'; end if;
  perform public.fn_require_org_feature(v_org, 'students');
  if p_emancipated then
    if length(btrim(coalesce(p_note, ''))) < 3 then raise exception 'NOTE_REQUIRED' using errcode = 'P0001'; end if;
    update public.ds_students
       set emancipated_at = now(), emancipated_by = auth.uid(), emancipation_note = left(btrim(p_note), 300)
     where id = p_student;
    update public.ds_client_students set is_active = false, ended_at = now(), ended_reason = 'emancipated'
     where student_id = p_student and relation = 'guardian' and is_active;
  else
    update public.ds_students set emancipated_at = null, emancipated_by = null, emancipation_note = null
     where id = p_student;
  end if;
end $$;
revoke execute on function public.ds_set_emancipation(uuid, boolean, text) from public, anon;
grant execute on function public.ds_set_emancipation(uuid, boolean, text) to authenticated;

-- A sign-in link for this client (7 days), for the welcome email that
-- ds-portal-access sends. Staff of the client's school only.
create or replace function public.ds_client_welcome_link(p_client uuid)
returns text language plpgsql security definer set search_path to 'public', 'extensions' as $$
declare
  c public.ds_clients;
  v_token text := encode(gen_random_bytes(24), 'hex');
begin
  select * into c from public.ds_clients where id = p_client;
  if c.id is null or not public.is_org_operator_or_above(c.organization_id) then raise exception 'Not authorized'; end if;
  perform public.fn_require_org_feature(c.organization_id, 'student_portal');
  if not c.is_active then raise exception 'CLIENT_REVOKED' using errcode = 'P0001'; end if;
  insert into public.ds_client_tokens (organization_id, client_id, kind, token_hash, expires_at)
  values (c.organization_id, c.id, 'link', encode(digest(v_token, 'sha256'), 'hex'), now() + interval '7 days');
  return v_token;
end $$;
revoke execute on function public.ds_client_welcome_link(uuid) from public, anon;
grant execute on function public.ds_client_welcome_link(uuid) to authenticated;

-- ------------------------------------------------------------------
-- Sign-in (service role: the ds-portal-access function)
-- ------------------------------------------------------------------
-- One 30-minute link per school where this email has an active profile.
-- No rows = nothing to send; the function answers the same either way.
create or replace function public.ds_client_request_links(p_email text)
returns table (school text, first_name text, token text)
language plpgsql security definer set search_path to 'public', 'extensions' as $$
declare
  c record;
  v_token text;
begin
  for c in
    select cl.id, cl.organization_id, cl.first_name, coalesce(o.report_display_name, o.name) as school
      from public.ds_clients cl
      join public.organizations o on o.id = cl.organization_id
     where cl.email = lower(btrim(coalesce(p_email, ''))) and cl.is_active
       and public.fn_org_feature_internal(cl.organization_id, 'student_portal')
  loop
    v_token := encode(gen_random_bytes(24), 'hex');
    insert into public.ds_client_tokens (organization_id, client_id, kind, token_hash, expires_at)
    values (c.organization_id, c.id, 'link', encode(digest(v_token, 'sha256'), 'hex'), now() + interval '30 minutes');
    school := c.school;
    first_name := c.first_name;
    token := v_token;
    return next;
  end loop;
end $$;
revoke execute on function public.ds_client_request_links(text) from public, anon, authenticated;
grant execute on function public.ds_client_request_links(text) to service_role;

-- For the welcome email: re-reads what the token was issued for.
create or replace function public.ds_client_link_info(p_token text)
returns table (organization_id uuid, school text, email text, first_name text)
language sql stable security definer set search_path to 'public', 'extensions' as $$
  select c.organization_id, coalesce(o.report_display_name, o.name), c.email, c.first_name
    from public.ds_client_tokens t
    join public.ds_clients c on c.id = t.client_id
    join public.organizations o on o.id = c.organization_id
   where t.token_hash = encode(digest(coalesce(p_token, ''), 'sha256'), 'hex')
     and t.kind = 'link' and t.used_at is null and t.revoked_at is null and t.expires_at > now()
     and c.is_active;
$$;
revoke execute on function public.ds_client_link_info(text) from public, anon, authenticated;
grant execute on function public.ds_client_link_info(text) to service_role;

-- ------------------------------------------------------------------
-- Portal (website, anon key; the session token is the credential)
-- ------------------------------------------------------------------
-- A link works once; it becomes a 30-day session.
create or replace function public.ds_client_open_link(p_token text)
returns text language plpgsql security definer set search_path to 'public', 'extensions' as $$
declare
  t public.ds_client_tokens;
  v_session text := encode(gen_random_bytes(32), 'hex');
begin
  select * into t from public.ds_client_tokens
   where token_hash = encode(digest(coalesce(p_token, ''), 'sha256'), 'hex') and kind = 'link'
   for update;
  if t.id is null or t.used_at is not null or t.revoked_at is not null or t.expires_at <= now()
     or not exists (select 1 from public.ds_clients where id = t.client_id and is_active)
     or not public.fn_org_feature_internal(t.organization_id, 'student_portal') then
    return null;
  end if;
  update public.ds_client_tokens set used_at = now() where id = t.id;
  insert into public.ds_client_tokens (organization_id, client_id, kind, token_hash, expires_at)
  values (t.organization_id, t.client_id, 'session', encode(digest(v_session, 'sha256'), 'hex'), now() + interval '30 days');
  update public.ds_clients set last_seen_at = now() where id = t.client_id;
  return v_session;
end $$;

create or replace function public.ds_client_sign_out(p_session text)
returns void language sql security definer set search_path to 'public', 'extensions' as $$
  update public.ds_client_tokens set revoked_at = now()
   where token_hash = encode(digest(coalesce(p_session, ''), 'sha256'), 'hex') and kind = 'session' and revoked_at is null;
$$;

create or replace function public.ds_client_home(p_session text)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare
  c public.ds_clients := public.fn_ds_client_session(p_session);
begin
  if c.id is null then return null; end if;
  return jsonb_build_object(
    'school', (select coalesce(report_display_name, name) from public.organizations where id = c.organization_id),
    'client', jsonb_build_object('first_name', c.first_name, 'last_name', c.last_name, 'email', c.email),
    'students', coalesce((
      select jsonb_agg(jsonb_build_object('id', st.id, 'first_name', st.first_name, 'last_name', st.last_name,
                                          'status', st.status, 'relation', cs.relation)
                       order by st.first_name)
        from public.ds_client_students cs
        join public.ds_students st on st.id = cs.student_id
       where cs.client_id = c.id and cs.is_active and public.fn_ds_link_counts(cs.relation, cs.student_id)), '[]'::jsonb),
    'pending', coalesce((
      select jsonb_agg(jsonb_build_object('first_name', r.first_name, 'requested_at', r.created_at) order by r.created_at)
        from public.ds_enrollment_requests r
       where r.client_id = c.id and r.status = 'pending'), '[]'::jsonb),
    'enroll_slug', (select pg.slug from public.ds_public_pages pg where pg.organization_id = c.organization_id and pg.enabled)
  );
end $$;

create or replace function public.ds_client_student_view(p_session text, p_student uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  return public.fn_ds_portal_payload(public.fn_ds_client_student(p_session, p_student));
end $$;

create or replace function public.ds_client_slots(p_session text, p_student uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  return public.fn_ds_portal_slots_for(public.fn_ds_client_student(p_session, p_student));
end $$;

create or replace function public.ds_client_book(p_session text, p_student uuid, p_date date, p_start time)
returns uuid language plpgsql security definer set search_path to 'public' as $$
begin
  return public.fn_ds_portal_book_for(public.fn_ds_client_student(p_session, p_student), p_date, p_start);
end $$;

create or replace function public.ds_client_cancel(p_session text, p_student uuid, p_block uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
begin
  return public.fn_ds_portal_cancel_for(public.fn_ds_client_student(p_session, p_student), p_block);
end $$;

create or replace function public.ds_client_set_sms(p_session text, p_student uuid, p_on boolean, p_phone text default null)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  perform public.fn_ds_portal_set_sms_for(public.fn_ds_client_student(p_session, p_student), p_on, p_phone);
end $$;

create or replace function public.ds_client_certificate(p_session text, p_student uuid, p_number text)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
begin
  return public.fn_ds_portal_certificate_for(public.fn_ds_client_student(p_session, p_student), p_number);
end $$;

-- A parent registers another child: an enrollment request on the parent's
-- profile, which the school approves like any other. Minors only (an adult
-- registers themself on the school's page).
create or replace function public.ds_client_add_child(p_session text, p jsonb)
returns text language plpgsql security definer set search_path to 'public' as $$
declare
  c public.ds_clients := public.fn_ds_client_session(p_session);
  v_min smallint;
  v_major smallint;
  v_birth date;
  v_age int;
  v_program uuid;
  v_branch uuid;
  v_lang text := case when p->>'preferred_language' in ('en', 'es') then p->>'preferred_language' end;
begin
  if c.id is null then raise exception 'SESSION_ENDED'; end if;
  select pg.min_age into v_min from public.ds_public_pages pg where pg.organization_id = c.organization_id and pg.enabled;
  if v_min is null then raise exception 'NOT_AVAILABLE' using errcode = 'P0001'; end if;
  select coalesce((select age_of_majority from public.ds_settings where organization_id = c.organization_id), 18) into v_major;

  if nullif(btrim(p->>'first_name'), '') is null or nullif(btrim(p->>'last_name'), '') is null then
    raise exception 'NAME_REQUIRED' using errcode = 'P0001';
  end if;
  begin
    v_birth := (p->>'birth_date')::date;
  exception when others then
    raise exception 'BIRTH_DATE' using errcode = 'P0001';
  end;
  if v_birth is null or v_birth > current_date then raise exception 'BIRTH_DATE' using errcode = 'P0001'; end if;
  v_age := extract(year from age(current_date, v_birth))::int;
  if v_age < greatest(v_min, 13) then raise exception 'TOO_YOUNG' using errcode = 'P0001'; end if;
  if v_age >= v_major then raise exception 'NOT_A_MINOR' using errcode = 'P0001'; end if;
  if coalesce((p->>'consent')::boolean, false) is not true or length(btrim(coalesce(p->>'consent_name', ''))) < 2 then
    raise exception 'CONSENT' using errcode = 'P0001';
  end if;

  begin
    v_program := nullif(p->>'program_id', '')::uuid;
    v_branch := nullif(p->>'branch_id', '')::uuid;
  exception when others then
    raise exception 'INVALID' using errcode = 'P0001';
  end;
  if v_program is not null and not exists (select 1 from public.ds_programs where id = v_program and organization_id = c.organization_id and is_active) then
    v_program := null;
  end if;
  if v_branch is not null and not exists (select 1 from public.branches where id = v_branch and organization_id = c.organization_id and not is_archived) then
    v_branch := null;
  end if;

  if (select count(*) from public.ds_enrollment_requests where client_id = c.id and status = 'pending') >= 5 then
    raise exception 'BUSY' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.ds_enrollment_requests r
              where r.client_id = c.id and r.status = 'pending'
                and lower(r.first_name) = lower(btrim(p->>'first_name')) and r.birth_date = v_birth) then
    return 'ok';
  end if;

  insert into public.ds_enrollment_requests (
    organization_id, client_id, first_name, last_name, birth_date,
    guardian_name, guardian_email, program_id, branch_id, message,
    is_minor, consent_by, consent_name, sms_opt_in, preferred_language)
  values (
    c.organization_id, c.id, left(btrim(p->>'first_name'), 60), left(btrim(p->>'last_name'), 60), v_birth,
    c.first_name || ' ' || c.last_name, c.email, v_program, v_branch, left(nullif(btrim(p->>'message'), ''), 500),
    true, 'guardian', left(btrim(p->>'consent_name'), 120), false, v_lang);
  return 'ok';
end $$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'ds_client_open_link(text)', 'ds_client_sign_out(text)', 'ds_client_home(text)',
    'ds_client_student_view(text, uuid)', 'ds_client_slots(text, uuid)',
    'ds_client_book(text, uuid, date, time)', 'ds_client_cancel(text, uuid, uuid)',
    'ds_client_set_sms(text, uuid, boolean, text)', 'ds_client_certificate(text, uuid, text)',
    'ds_client_add_child(text, jsonb)']
  loop
    execute format('revoke execute on function public.%s from public', f);
    execute format('grant execute on function public.%s to anon, authenticated', f);
  end loop;
end $$;

-- ------------------------------------------------------------------
-- Daily: close on record the parent links that no longer count
-- ------------------------------------------------------------------
create or replace function public.fn_ds_close_guardian_links()
returns void language sql security definer set search_path to 'public' as $$
  update public.ds_client_students cs
     set is_active = false, ended_at = now(),
         ended_reason = case when st.emancipated_at is not null then 'emancipated' else 'majority' end
    from public.ds_students st
   where st.id = cs.student_id and cs.relation = 'guardian' and cs.is_active
     and not public.fn_ds_is_minor(cs.student_id);
$$;
revoke execute on function public.fn_ds_close_guardian_links() from public, anon, authenticated;

select cron.schedule('ds-guardian-links-daily', '17 8 * * *', 'select public.fn_ds_close_guardian_links()');
