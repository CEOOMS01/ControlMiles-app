-- Lesson language preference (user request 2026-10-20, driving schools):
-- instructors list the languages they teach in (English, Spanish for now),
-- a student may prefer one, and online booking only offers times with an
-- instructor who teaches in it. The instructor is never picked by the
-- student or shown before booking: among the qualified instructors free at
-- that time one is chosen at random, so the choice can't be used to
-- discriminate. No other preferences on purpose.

alter table public.organization_members
  add column if not exists languages text[] not null default '{en}'
    check (cardinality(languages) between 1 and 2 and languages <@ array['en', 'es']);
alter table public.ds_students
  add column if not exists preferred_language text check (preferred_language in ('en', 'es'));
alter table public.ds_enrollment_requests
  add column if not exists preferred_language text check (preferred_language in ('en', 'es'));

-- The office sets an instructor's languages (owners and admins).
create or replace function public.set_member_languages(p_organization_id uuid, p_user_id uuid, p_languages text[])
returns void language plpgsql security definer set search_path to 'public' as $$
declare
  v text[] := array(select distinct x from unnest(p_languages) x where x in ('en', 'es') order by 1);
begin
  if not public.is_org_admin_or_owner(p_organization_id) then raise exception 'Not authorized'; end if;
  if cardinality(v) = 0 then raise exception 'Pick at least one language' using errcode = 'P0001'; end if;
  update public.organization_members set languages = v
   where organization_id = p_organization_id and user_id = p_user_id;
end $$;
revoke execute on function public.set_member_languages(uuid, uuid, text[]) from public, anon;
grant execute on function public.set_member_languages(uuid, uuid, text[]) to authenticated;

-- Free times for the portal: one row per time, instructors not shown, only
-- instructors who teach in the student's preferred language (if any).
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
    'language', st.preferred_language,
    'slots', coalesce((
      select jsonb_agg(jsonb_build_object('date', t.block_date, 'start', t.start_time, 'end', t.end_time)
                       order by t.block_date, t.start_time)
        from (select distinct s.block_date, s.start_time, s.end_time
                from public.fn_ds_free_slots(l.organization_id, pr.class_minutes, (now() at time zone v_tz)::date,
                                             cfg.booking_horizon_days, cfg.booking_lead_hours) s
                join public.organization_members m
                  on m.organization_id = l.organization_id and m.user_id = s.instructor_id
               where st.preferred_language is null or st.preferred_language = any (m.languages)) t), '[]'::jsonb)
  );
end $$;

-- Book a time: the instructor is picked at random among the qualified ones
-- free then. Replaces the version that took an instructor.
drop function if exists public.ds_portal_book(text, uuid, date, time without time zone);
create or replace function public.ds_portal_book(p_token text, p_date date, p_start time without time zone)
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

  -- One booking at a time for this school, day and start time.
  perform pg_advisory_xact_lock(hashtext(l.organization_id::text || p_date::text || p_start::text));

  select count(*) into v_upcoming from public.shift_blocks
   where student_id = st.id and status = 'scheduled' and (block_date + start_time) at time zone v_tz > now();
  if v_upcoming >= cfg.booking_max_upcoming then raise exception 'TOO_MANY_UPCOMING'; end if;

  if public.fn_org_feature_internal(l.organization_id, 'student_packages')
     and exists (select 1 from public.ds_packages where organization_id = l.organization_id and is_active) then
    bal := public.fn_ds_balance(st.id);
    if bal.purchased - bal.used - bal.booked < pr.class_minutes then raise exception 'NO_BALANCE'; end if;
  end if;

  select f.* into s
    from public.fn_ds_free_slots(l.organization_id, pr.class_minutes, p_date, 1, cfg.booking_lead_hours) f
    join public.organization_members m on m.organization_id = l.organization_id and m.user_id = f.instructor_id
   where f.start_time = p_start
     and p_date <= (now() at time zone v_tz)::date + cfg.booking_horizon_days
     and (st.preferred_language is null or st.preferred_language = any (m.languages))
   order by random()
   limit 1;
  if s.instructor_id is null then raise exception 'SLOT_TAKEN'; end if;

  insert into public.shift_blocks (organization_id, driver_id, vehicle_id, block_date, start_time, end_time, source,
                                   status, student_id, booked_via, note)
  values (l.organization_id, s.instructor_id, s.vehicle_id, s.block_date, s.start_time, s.end_time, 'one_off',
          'scheduled', st.id, 'portal', 'Booked online')
  returning id into v_id;
  return v_id;
end $$;
revoke execute on function public.ds_portal_book(text, date, time without time zone) from public;
grant execute on function public.ds_portal_book(text, date, time without time zone) to anon, authenticated;

create or replace function public.ds_public_enroll(p_slug text, p jsonb)
returns text language plpgsql volatile security definer set search_path to 'public' as $$
declare
  v_org uuid;
  v_min smallint;
  v_birth date;
  v_age int;
  v_minor boolean;
  v_email text := nullif(lower(btrim(p->>'email')), '');
  v_phone text := nullif(btrim(p->>'phone'), '');
  v_g_name text := nullif(btrim(p->>'guardian_name'), '');
  v_g_email text := nullif(lower(btrim(p->>'guardian_email')), '');
  v_g_phone text := nullif(btrim(p->>'guardian_phone'), '');
  v_program uuid;
  v_branch uuid;
  v_sms boolean := coalesce((p->>'sms_opt_in')::boolean, false);
  v_consent_by text := p->>'consent_by';
  v_email_re text := '^[^@\s]+@[^@\s]+\.[^@\s]+$';
  v_lang text := case when p->>'preferred_language' in ('en', 'es') then p->>'preferred_language' end;
begin
  select pg.organization_id, pg.min_age into v_org, v_min
    from public.ds_public_pages pg
   where pg.slug = lower(p_slug) and pg.enabled
     and public.fn_org_feature_internal(pg.organization_id, 'student_portal');
  if v_org is null then raise exception 'NOT_AVAILABLE' using errcode = 'P0001'; end if;

  -- Housekeeping: requests are kept 90 days, whatever their status.
  delete from public.ds_enrollment_requests where organization_id = v_org and created_at < now() - interval '90 days';

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
  if v_age > 100 then raise exception 'BIRTH_DATE' using errcode = 'P0001'; end if;
  if v_age < greatest(v_min, 13) then raise exception 'TOO_YOUNG' using errcode = 'P0001'; end if;
  v_minor := v_age < 18;

  if (v_email is not null and v_email !~ v_email_re) or (v_g_email is not null and v_g_email !~ v_email_re) then
    raise exception 'EMAIL' using errcode = 'P0001';
  end if;
  if v_minor then
    if v_g_name is null or (v_g_email is null and v_g_phone is null) then
      raise exception 'GUARDIAN_REQUIRED' using errcode = 'P0001';
    end if;
    if v_consent_by is distinct from 'guardian' then raise exception 'GUARDIAN_CONSENT' using errcode = 'P0001'; end if;
  else
    if v_email is null and v_phone is null then raise exception 'CONTACT_REQUIRED' using errcode = 'P0001'; end if;
    if v_consent_by is null or v_consent_by not in ('student', 'guardian') then raise exception 'CONSENT' using errcode = 'P0001'; end if;
  end if;
  if coalesce((p->>'consent')::boolean, false) is not true or length(btrim(coalesce(p->>'consent_name', ''))) < 2 then
    raise exception 'CONSENT' using errcode = 'P0001';
  end if;
  if v_sms and coalesce(nullif(btrim(p->>'sms_phone'), ''), v_phone, v_g_phone) is null then
    raise exception 'SMS_PHONE' using errcode = 'P0001';
  end if;

  begin
    v_program := nullif(p->>'program_id', '')::uuid;
    v_branch := nullif(p->>'branch_id', '')::uuid;
  exception when others then
    raise exception 'INVALID' using errcode = 'P0001';
  end;
  if v_program is not null and not exists (select 1 from public.ds_programs where id = v_program and organization_id = v_org and is_active) then
    v_program := null;
  end if;
  if v_branch is not null and not exists (select 1 from public.branches where id = v_branch and organization_id = v_org and not is_archived) then
    v_branch := null;
  end if;

  if (select count(*) from public.ds_enrollment_requests
       where organization_id = v_org and created_at > now() - interval '1 hour') >= 30 then
    raise exception 'BUSY' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.ds_enrollment_requests r
              where r.organization_id = v_org and r.created_at > now() - interval '24 hours'
                and lower(r.first_name) = lower(btrim(p->>'first_name')) and lower(r.last_name) = lower(btrim(p->>'last_name'))
                and r.birth_date = v_birth) then
    return 'ok';
  end if;

  insert into public.ds_enrollment_requests (
    organization_id, first_name, last_name, birth_date, email, phone,
    guardian_name, guardian_email, guardian_phone, program_id, branch_id, message,
    is_minor, consent_by, consent_name, sms_opt_in, sms_phone, preferred_language)
  values (
    v_org, btrim(p->>'first_name'), btrim(p->>'last_name'), v_birth, v_email, v_phone,
    v_g_name, v_g_email, v_g_phone, v_program, v_branch, left(nullif(btrim(p->>'message'), ''), 500),
    v_minor, case when v_minor then 'guardian' else v_consent_by end, left(btrim(p->>'consent_name'), 120),
    v_sms, case when v_sms then coalesce(nullif(btrim(p->>'sms_phone'), ''), v_phone, v_g_phone) end, v_lang);
  return 'ok';
end $$;

create or replace function public.ds_enrollment_approve(p_id uuid)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare
  r public.ds_enrollment_requests;
  v_student uuid;
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
  return v_student;
end $$;
