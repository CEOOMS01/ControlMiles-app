-- Driving school website integration, levels 1 and 2 (user request
-- 2026-10-20: "they keep their domain; students book from their site and
-- ControlMiles runs everything"). Enterprise (student_portal).
--
-- Competitors: DriveScout ("integrate with ANY website" for online
-- enrollment), Teachworks custom forms (a link, button or iframe that
-- creates a profile), carslearning.ca (embeddable self-enrollment link,
-- requests land in the dashboard for approval), Calendly (inline embed /
-- popup). We do the same: a public school page at /book/<slug>, a button
-- or an iframe on the school's site, requests waiting for office approval.
--
-- Minors' data (research 2026-10-20): COPPA covers under 13, and driving
-- students are 15+, so the page refuses ages under the school's minimum
-- (never below 13). State laws now reach 13-17 (Maryland MODPA, in force
-- 2025-10-01: no sale or targeted ads with a known minor's data; Maryland
-- Kids Code: high privacy defaults), and schools must have the parent or
-- guardian in the enrollment agreement (e.g. Ohio 4501-7-12; Maryland
-- keeps signed student rights forms, COMAR 11.23). So:
--   * data minimization: name, birth date, contact, guardian, program,
--     branch and a short message. No permit number, address, ID or SSN
--     online (the office collects those at intake, as the state requires);
--   * under 18: a parent or guardian with a contact is required, and the
--     consent is given and named by the guardian;
--   * consent is recorded (who, typed name, when, which text version);
--   * requests are not students: approving copies them into ds_students
--     and deletes the request; declining deletes it; pending requests are
--     purged after 90 days;
--   * text messages only with a separate opt-in (TCPA), kept on approval;
--   * nothing is sold, shared or used for ads; the public page loads no
--     third-party trackers.

alter table public.ds_students add column if not exists birth_date date;
alter table public.ds_students drop constraint if exists ds_students_sms_consent_source_check;
alter table public.ds_students add constraint ds_students_sms_consent_source_check
  check (sms_consent_source is null or sms_consent_source = any (array['office', 'portal', 'online_request']));

create or replace function public.fn_valid_origins(p text[])
returns boolean language sql immutable as $$
  select coalesce(bool_and(o ~ '^https://[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+(:[0-9]{2,5})?$'), true)
    from unnest(p) o;
$$;

create table if not exists public.ds_public_pages (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$'),
  enabled boolean not null default false,
  intro text check (intro is null or length(intro) <= 600),
  min_age smallint not null default 15 check (min_age between 13 and 25),
  terms_url text check (terms_url is null or (terms_url ~ '^https://' and length(terms_url) <= 300)),
  allowed_origins text[] not null default '{}' check (cardinality(allowed_origins) <= 5 and public.fn_valid_origins(allowed_origins)),
  updated_at timestamptz not null default now()
);
alter table public.ds_public_pages enable row level security;
create policy ds_public_pages_select on public.ds_public_pages for select
  using (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'student_portal'));
create policy ds_public_pages_insert on public.ds_public_pages for insert
  with check (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'student_portal'));
create policy ds_public_pages_update on public.ds_public_pages for update
  using (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'student_portal'))
  with check (public.is_org_admin_or_owner(organization_id) and public.fn_org_has_feature(organization_id, 'student_portal'));

create table if not exists public.ds_enrollment_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  first_name text not null check (length(btrim(first_name)) between 1 and 60),
  last_name text not null check (length(btrim(last_name)) between 1 and 60),
  birth_date date not null,
  email text check (email is null or length(email) <= 120),
  phone text check (phone is null or length(phone) <= 30),
  guardian_name text check (guardian_name is null or length(guardian_name) <= 120),
  guardian_email text check (guardian_email is null or length(guardian_email) <= 120),
  guardian_phone text check (guardian_phone is null or length(guardian_phone) <= 30),
  program_id uuid references public.ds_programs(id) on delete set null,
  branch_id uuid references public.branches(id) on delete set null,
  message text check (message is null or length(message) <= 500),
  is_minor boolean not null,
  consent_by text not null check (consent_by in ('student', 'guardian')),
  consent_name text not null check (length(btrim(consent_name)) between 2 and 120),
  consent_version text not null default '2026-10-20',
  consent_at timestamptz not null default now(),
  sms_opt_in boolean not null default false,
  sms_phone text check (sms_phone is null or length(sms_phone) <= 30),
  created_at timestamptz not null default now()
);
create index if not exists ds_enrollment_requests_org_idx on public.ds_enrollment_requests (organization_id, created_at desc);
alter table public.ds_enrollment_requests enable row level security;
-- Read by the office; written only through the functions below.
create policy ds_enrollment_requests_select on public.ds_enrollment_requests for select
  using (public.is_org_operator_or_above(organization_id) and public.fn_org_has_feature(organization_id, 'student_portal'));

-- The school's public page (anyone with the link).
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
     and public.fn_org_has_feature(o.id, 'student_portal');
$$;
revoke execute on function public.ds_public_page(text) from public;
grant execute on function public.ds_public_page(text) to anon, authenticated;

-- Sites allowed to show the page in an iframe (the web proxy's frame-ancestors).
create or replace function public.ds_public_origins(p_slug text)
returns text[] language sql stable security definer set search_path to 'public' as $$
  select pg.allowed_origins
    from public.ds_public_pages pg
   where pg.slug = lower(p_slug) and pg.enabled
     and public.fn_org_has_feature(pg.organization_id, 'student_portal');
$$;
revoke execute on function public.ds_public_origins(text) from public;
grant execute on function public.ds_public_origins(text) to anon, authenticated;

-- An enrollment request from the public page. Errors are short codes the
-- page turns into messages.
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
     and public.fn_org_has_feature(pg.organization_id, 'student_portal');
  if v_org is null then raise exception 'NOT_AVAILABLE' using errcode = 'P0001'; end if;

  -- Housekeeping: requests nobody handled in 90 days are removed.
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
    if v_consent_by not in ('student', 'guardian') then raise exception 'CONSENT' using errcode = 'P0001'; end if;
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

  -- Abuse limits: 30 requests an hour per school; the same person twice in
  -- a day is taken once.
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
revoke execute on function public.ds_public_enroll(text, jsonb) from public;
grant execute on function public.ds_public_enroll(text, jsonb) to anon, authenticated;

-- Office: approve (copies into students, removes the request) or decline (removes it).
create or replace function public.ds_enrollment_approve(p_id uuid)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare
  r public.ds_enrollment_requests;
  v_student uuid;
begin
  select * into r from public.ds_enrollment_requests where id = p_id;
  if r.id is null then raise exception 'That request is gone' using errcode = 'P0001'; end if;
  if not public.is_org_operator_or_above(r.organization_id) or not public.fn_org_has_feature(r.organization_id, 'student_portal') then
    raise exception 'Not authorized';
  end if;
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
  delete from public.ds_enrollment_requests where id = r.id;
  return v_student;
end $$;
revoke execute on function public.ds_enrollment_approve(uuid) from public, anon;
grant execute on function public.ds_enrollment_approve(uuid) to authenticated;

create or replace function public.ds_enrollment_decline(p_id uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
declare
  v_org uuid;
begin
  select organization_id into v_org from public.ds_enrollment_requests where id = p_id;
  if v_org is null then return; end if;
  if not public.is_org_operator_or_above(v_org) or not public.fn_org_has_feature(v_org, 'student_portal') then
    raise exception 'Not authorized';
  end if;
  delete from public.ds_enrollment_requests where id = p_id;
end $$;
revoke execute on function public.ds_enrollment_decline(uuid) from public, anon;
grant execute on function public.ds_enrollment_decline(uuid) to authenticated;
