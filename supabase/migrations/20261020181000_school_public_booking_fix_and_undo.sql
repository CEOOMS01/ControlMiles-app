-- Website enrollment, second pass (2026-10-20).
--
-- 1. Fix found testing: the public functions checked the plan with
--    fn_org_has_feature, which also requires the caller to be a member of
--    the school, so an anonymous visitor always got NOT_AVAILABLE (it only
--    worked with an admin session open). They use fn_org_feature_internal,
--    like the student portal functions.
-- 2. Everything can be undone (user request): declining keeps the request
--    as "declined" and it can be restored; approving keeps it as "approved"
--    with the new student, and can be reverted while that student has no
--    classes, packages, evaluations, certificates or portal link yet (after
--    that, mark the student Dropped instead). Decided requests are still
--    removed 90 days after they arrived, like pending ones.

alter table public.ds_enrollment_requests
  add column if not exists status text not null default 'pending' check (status in ('pending', 'approved', 'declined')),
  add column if not exists decided_at timestamptz,
  add column if not exists decided_by uuid references auth.users(id) on delete set null,
  add column if not exists student_id uuid references public.ds_students(id) on delete set null;

create or replace function public.ds_public_page(p_slug text)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select jsonb_build_object(
           'school', coalesce(nullif(btrim(o.report_display_name), ''), o.name),
           'intro', pg.intro,
           'min_age', pg.min_age,
           'terms_url', pg.terms_url,
           'programs', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'name', p.name) order by p.sort, p.name)
                                   from public.ds_programs p where p.organization_id = o.id and p.is_active), '[]'::jsonb),
           'branches', coalesce((select jsonb_agg(jsonb_build_object('id', b.id, 'name', b.name) order by b.name)
                                   from public.branches b where b.organization_id = o.id and not b.is_archived), '[]'::jsonb))
    from public.ds_public_pages pg
    join public.organizations o on o.id = pg.organization_id
   where pg.slug = lower(p_slug) and pg.enabled
     and public.fn_org_feature_internal(o.id, 'student_portal');
$$;

create or replace function public.ds_public_origins(p_slug text)
returns text[] language sql stable security definer set search_path to 'public' as $$
  select pg.allowed_origins
    from public.ds_public_pages pg
   where pg.slug = lower(p_slug) and pg.enabled
     and public.fn_org_feature_internal(pg.organization_id, 'student_portal');
$$;

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
    is_minor, consent_by, consent_name, sms_opt_in, sms_phone)
  values (
    v_org, btrim(p->>'first_name'), btrim(p->>'last_name'), v_birth, v_email, v_phone,
    v_g_name, v_g_email, v_g_phone, v_program, v_branch, left(nullif(btrim(p->>'message'), ''), 500),
    v_minor, case when v_minor then 'guardian' else v_consent_by end, left(btrim(p->>'consent_name'), 120),
    v_sms, case when v_sms then coalesce(nullif(btrim(p->>'sms_phone'), ''), v_phone, v_g_phone) end);
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
    sms_consent_at, sms_consent_phone, sms_consent_source, created_by)
  values (
    r.organization_id, r.first_name, r.last_name, r.birth_date, r.email, r.phone,
    r.guardian_name, r.guardian_email, r.guardian_phone, 'registered', r.program_id, r.branch_id,
    left(concat_ws(E'\n',
      'Online request ' || to_char(r.created_at, 'YYYY-MM-DD') || ', consent by ' || r.consent_by || ' (' || r.consent_name || ').',
      r.message), 1000),
    case when r.sms_opt_in then r.consent_at end,
    case when r.sms_opt_in then r.sms_phone end,
    case when r.sms_opt_in then 'online_request' end,
    auth.uid())
  returning id into v_student;
  update public.ds_enrollment_requests
     set status = 'approved', student_id = v_student, decided_at = now(), decided_by = auth.uid()
   where id = r.id;
  return v_student;
end $$;

create or replace function public.ds_enrollment_decline(p_id uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
declare
  r public.ds_enrollment_requests;
begin
  select * into r from public.ds_enrollment_requests where id = p_id for update;
  if r.id is null then return; end if;
  if not public.is_org_operator_or_above(r.organization_id) or not public.fn_org_has_feature(r.organization_id, 'student_portal') then
    raise exception 'Not authorized';
  end if;
  if r.status <> 'pending' then raise exception 'Only a waiting request can be declined' using errcode = 'P0001'; end if;
  update public.ds_enrollment_requests set status = 'declined', decided_at = now(), decided_by = auth.uid() where id = r.id;
end $$;

-- Undo a decision: a declined request goes back to waiting; an approved one
-- removes the student it created (only while nothing hangs on them yet) and
-- goes back to waiting.
create or replace function public.ds_enrollment_undo(p_id uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
declare
  r public.ds_enrollment_requests;
begin
  select * into r from public.ds_enrollment_requests where id = p_id for update;
  if r.id is null then raise exception 'That request is gone' using errcode = 'P0001'; end if;
  if not public.is_org_operator_or_above(r.organization_id) or not public.fn_org_has_feature(r.organization_id, 'student_portal') then
    raise exception 'Not authorized';
  end if;
  if r.status = 'approved' and r.student_id is not null then
    if exists (select 1 from public.shift_blocks where student_id = r.student_id)
       or exists (select 1 from public.ds_student_packages where student_id = r.student_id)
       or exists (select 1 from public.ds_evaluations where student_id = r.student_id)
       or exists (select 1 from public.ds_certificates where student_id = r.student_id)
       or exists (select 1 from public.ds_portal_links where student_id = r.student_id) then
      raise exception 'This student already has classes, packages or a portal link. Mark them Dropped instead.' using errcode = 'P0001';
    end if;
    delete from public.ds_students where id = r.student_id;
  end if;
  update public.ds_enrollment_requests
     set status = 'pending', student_id = null, decided_at = null, decided_by = null
   where id = r.id;
end $$;
revoke execute on function public.ds_enrollment_undo(uuid) from public, anon;
grant execute on function public.ds_enrollment_undo(uuid) to authenticated;
