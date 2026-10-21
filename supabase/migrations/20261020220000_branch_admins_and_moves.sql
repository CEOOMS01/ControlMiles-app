-- Branches under the owner (user decision 2026-10-20):
--   * the owner assigns an admin to run each branch (branches.manager_id);
--   * each instructor and each student belongs to a branch;
--   * the owner or an admin can move an instructor or a student to another
--     branch, always with a note saying why; every move is kept
--     (branch_moves), so the history can be read later;
--   * online booking only offers a student instructors of the student's
--     branch, instructors who work at any branch, or instructors not yet
--     placed in a branch (a school without branches keeps working as before).

alter table public.branches
  add column if not exists manager_id uuid references auth.users(id) on delete set null;

create table if not exists public.branch_moves (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  subject_type text not null check (subject_type in ('member', 'student')),
  subject_id uuid not null,
  subject_name text,
  from_branch_id uuid references public.branches(id) on delete set null,
  to_branch_id uuid references public.branches(id) on delete set null,
  from_any boolean not null default false,
  to_any boolean not null default false,
  note text not null check (length(btrim(note)) between 3 and 500),
  moved_by uuid references auth.users(id) on delete set null,
  moved_at timestamptz not null default now()
);
create index if not exists branch_moves_org_idx on public.branch_moves (organization_id, moved_at desc);
create index if not exists branch_moves_subject_idx on public.branch_moves (subject_id, moved_at desc);
alter table public.branch_moves enable row level security;
create policy branch_moves_select on public.branch_moves for select
  using (public.is_org_operator_or_above(organization_id));

-- Owner only: who runs a branch (an admin of the fleet, or nobody).
create or replace function public.set_branch_manager(p_branch_id uuid, p_user_id uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
declare
  v_org uuid;
begin
  select organization_id into v_org from public.branches where id = p_branch_id;
  if v_org is null or not public.is_org_owner(v_org) then raise exception 'Only the owner assigns branch admins'; end if;
  if p_user_id is not null and not exists (
    select 1 from public.organization_members
     where organization_id = v_org and user_id = p_user_id and is_active and member_role in ('admin', 'owner')
  ) then
    raise exception 'Pick an admin of this fleet' using errcode = 'P0001';
  end if;
  update public.branches set manager_id = p_user_id where id = p_branch_id;
end $$;
revoke execute on function public.set_branch_manager(uuid, uuid) from public, anon;
grant execute on function public.set_branch_manager(uuid, uuid) to authenticated;

-- Owner or admin: move an instructor (member) or a student, with a reason.
-- p_to_branch null with p_any = true: the instructor works at any branch.
create or replace function public.move_to_branch(
  p_organization_id uuid, p_subject_type text, p_subject_id uuid, p_to_branch uuid, p_any boolean, p_note text
)
returns void language plpgsql security definer set search_path to 'public' as $$
declare
  v_from uuid;
  v_from_any boolean := false;
  v_name text;
  v_any boolean := coalesce(p_any, false) and p_subject_type = 'member';
begin
  if not public.is_org_admin_or_owner(p_organization_id) then raise exception 'Not authorized'; end if;
  if length(btrim(coalesce(p_note, ''))) < 3 then
    raise exception 'Write why you are making this move' using errcode = 'P0001';
  end if;
  if p_to_branch is not null and not exists (
    select 1 from public.branches where id = p_to_branch and organization_id = p_organization_id and not is_archived
  ) then
    raise exception 'That branch belongs to another fleet' using errcode = 'P0001';
  end if;

  if p_subject_type = 'member' then
    select m.branch_id, m.any_branch, nullif(concat_ws(' ', p.first_name, p.last_name), '')
      into v_from, v_from_any, v_name
      from public.organization_members m left join public.profiles p on p.id = m.user_id
     where m.organization_id = p_organization_id and m.user_id = p_subject_id;
    if not found then raise exception 'That person is not on this team' using errcode = 'P0001'; end if;
    update public.organization_members
       set branch_id = case when v_any then null else p_to_branch end, any_branch = v_any
     where organization_id = p_organization_id and user_id = p_subject_id;
  elsif p_subject_type = 'student' then
    select branch_id, concat_ws(' ', first_name, last_name) into v_from, v_name
      from public.ds_students where id = p_subject_id and organization_id = p_organization_id;
    if not found then raise exception 'That student is not in this school' using errcode = 'P0001'; end if;
    update public.ds_students set branch_id = p_to_branch where id = p_subject_id;
  else
    raise exception 'Bad subject';
  end if;

  insert into public.branch_moves (organization_id, subject_type, subject_id, subject_name, from_branch_id, to_branch_id,
                                   from_any, to_any, note, moved_by)
  values (p_organization_id, p_subject_type, p_subject_id, v_name, v_from,
          case when v_any then null else p_to_branch end, coalesce(v_from_any, false), v_any, btrim(p_note), auth.uid());
end $$;
revoke execute on function public.move_to_branch(uuid, text, uuid, uuid, boolean, text) from public, anon;
grant execute on function public.move_to_branch(uuid, text, uuid, uuid, boolean, text) to authenticated;

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
               where (st.preferred_language is null or st.preferred_language = any (m.languages))
                 and (st.branch_id is null or m.any_branch or m.branch_id is null or m.branch_id = st.branch_id)) t), '[]'::jsonb)
  );
end $$;

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
     and (st.branch_id is null or m.any_branch or m.branch_id is null or m.branch_id = st.branch_id)
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
