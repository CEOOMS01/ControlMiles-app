-- HOURLY SHIFT BLOCKS (user request 2026-09-29: "shift de colocación por
-- hora, ejemplo una escuela de manejo"). Researched against driving-school
-- schedulers (Teachworks: instructor + vehicle per lesson, one-off moves on
-- top of a recurring calendar) and time clocks (Connecteam: clock-in only
-- inside a window around the scheduled start; break -> resume / end shift).
--
-- User decisions:
--   * Blocks come from BOTH the weekly template (public.shifts, already one
--     row per driver/day/start time) AND one-off blocks on a date.
--   * A driver can start a block from W minutes before to W minutes after
--     its start (W per org); starting after the start time marks it late.
--   * Between blocks nothing is tracked (no GPS); the WORKDAY stays open
--     until the driver ends it.
--   * Each block has an optional free-text note ("Clase — Juan Pérez").
--
-- Model: shift_blocks holds every block on a date -- one-offs, and the
-- template's rows materialized for that date (so one class can be moved or
-- cancelled without touching the weekly template). Each started block is
-- one trip (sessions.shift_block_id). driver_workdays is the day the
-- driver opens with their first block and closes by hand.
--
-- Times are the fleet's local wall-clock: organizations.timezone.
--
-- Error codes (ERROR_CODES.md): 416 too early, 417 window closed,
-- 418 another block in progress, 419 day already closed, 422 block still
-- in progress when closing the day.

alter table public.organizations
  add column if not exists timezone text not null default 'America/New_York',
  add column if not exists shift_start_window_minutes integer not null default 10;

do $$ begin
  alter table public.organizations
    add constraint organizations_shift_window_check
    check (shift_start_window_minutes between 0 and 120);
exception when duplicate_object then null; end $$;

create or replace function public.fn_validate_org_timezone()
returns trigger language plpgsql as $$
begin
  if not exists (select 1 from pg_timezone_names where name = new.timezone) then
    raise exception 'Unknown timezone: %', new.timezone;
  end if;
  return new;
end $$;

drop trigger if exists tr_organizations_validate_timezone on public.organizations;
create trigger tr_organizations_validate_timezone
  before insert or update of timezone on public.organizations
  for each row execute function public.fn_validate_org_timezone();

-- ── Blocks ────────────────────────────────────────────────────────────
create table if not exists public.shift_blocks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  driver_id uuid not null references public.profiles(id) on delete cascade,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  block_date date not null,
  start_time time not null,
  end_time time not null,
  note text,
  source text not null default 'one_off' check (source in ('template', 'one_off')),
  template_shift_id uuid references public.shifts(id) on delete set null,
  status text not null default 'scheduled'
    check (status in ('scheduled', 'in_progress', 'done', 'cancelled')),
  started_at timestamptz,
  ended_at timestamptz,
  late_minutes integer,
  session_id uuid,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shift_blocks_time_order check (end_time > start_time),
  constraint shift_blocks_template_date_key unique (template_shift_id, block_date)
);

create index if not exists shift_blocks_org_date_idx on public.shift_blocks (organization_id, block_date);
create index if not exists shift_blocks_driver_date_idx on public.shift_blocks (driver_id, block_date);

drop trigger if exists shift_blocks_touch_updated_at on public.shift_blocks;
create trigger shift_blocks_touch_updated_at
  before update on public.shift_blocks
  for each row execute function public.fn_touch_updated_at();

alter table public.shift_blocks enable row level security;

drop policy if exists shift_blocks_select on public.shift_blocks;
create policy shift_blocks_select on public.shift_blocks for select to authenticated
  using (driver_id = auth.uid() or public.is_org_operator_or_above(organization_id));

-- Admins/operators schedule; drivers only move their own blocks through
-- the SECURITY DEFINER functions below.
drop policy if exists shift_blocks_insert on public.shift_blocks;
create policy shift_blocks_insert on public.shift_blocks for insert to authenticated
  with check (public.is_org_operator_or_above(organization_id) and source = 'one_off');

drop policy if exists shift_blocks_update on public.shift_blocks;
create policy shift_blocks_update on public.shift_blocks for update to authenticated
  using (public.is_org_operator_or_above(organization_id))
  with check (public.is_org_operator_or_above(organization_id));

drop policy if exists shift_blocks_delete on public.shift_blocks;
create policy shift_blocks_delete on public.shift_blocks for delete to authenticated
  using (public.is_org_operator_or_above(organization_id) and status = 'scheduled');

-- A block that already happened is history: only scheduled blocks can be
-- edited by hand (status changes go through the functions below).
create or replace function public.fn_freeze_started_shift_block()
returns trigger language plpgsql as $$
begin
  if old.status <> 'scheduled' and current_setting('cm.shift_block_rpc', true) is distinct from 'on' then
    raise exception 'A class that already started cannot be edited';
  end if;
  return new;
end $$;

drop trigger if exists tr_shift_blocks_freeze_started on public.shift_blocks;
create trigger tr_shift_blocks_freeze_started
  before update on public.shift_blocks
  for each row execute function public.fn_freeze_started_shift_block();

-- ── Workdays ──────────────────────────────────────────────────────────
create table if not exists public.driver_workdays (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  driver_id uuid not null references public.profiles(id) on delete cascade,
  work_date date not null,
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  constraint driver_workdays_unique unique (organization_id, driver_id, work_date)
);

alter table public.driver_workdays enable row level security;

drop policy if exists driver_workdays_select on public.driver_workdays;
create policy driver_workdays_select on public.driver_workdays for select to authenticated
  using (driver_id = auth.uid() or public.is_org_operator_or_above(organization_id));
-- No insert/update/delete policies: only the functions below write here.

-- ── Trips linked to blocks ───────────────────────────────────────────
alter table public.sessions
  add column if not exists shift_block_id uuid references public.shift_blocks(id) on delete set null;

do $$ begin
  alter table public.shift_blocks
    add constraint shift_blocks_session_fk foreign key (session_id)
    references public.sessions(id) on delete set null;
exception when duplicate_object then null; end $$;

-- A trip may only be attached to the caller's own block that is in progress;
-- the block then points back at the trip.
create or replace function public.fn_link_session_to_shift_block()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.shift_block_id is null then
    return new;
  end if;
  if not exists (
    select 1 from public.shift_blocks b
    where b.id = new.shift_block_id and b.driver_id = new.user_id and b.status = 'in_progress'
  ) then
    raise exception 'This class is not in progress';
  end if;
  perform set_config('cm.shift_block_rpc', 'on', true);
  update public.shift_blocks set session_id = new.id where id = new.shift_block_id;
  perform set_config('cm.shift_block_rpc', 'off', true);
  return new;
end $$;

drop trigger if exists tr_sessions_link_shift_block on public.sessions;
create trigger tr_sessions_link_shift_block
  after insert on public.sessions
  for each row execute function public.fn_link_session_to_shift_block();

-- ── Helpers ───────────────────────────────────────────────────────────
create or replace function public.fn_org_local_today(p_org uuid)
returns date language sql stable security definer set search_path = public as $$
  select (now() at time zone o.timezone)::date from public.organizations o where o.id = p_org;
$$;

-- Materializes the weekly template (public.shifts) into shift_blocks for one
-- date. Scheduled template instances follow template edits; a deleted or
-- deactivated template row drops its still-scheduled instances. Started,
-- done and cancelled blocks are never touched.
create or replace function public.materialize_shift_blocks(p_org uuid, p_date date)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_org_member(p_org, null) then
    raise exception 'Not a member of this organization';
  end if;

  perform set_config('cm.shift_block_rpc', 'on', true);

  insert into public.shift_blocks
    (organization_id, driver_id, vehicle_id, block_date, start_time, end_time, note, source, template_shift_id)
  select s.organization_id, s.driver_id, s.vehicle_id, p_date, s.start_time, s.end_time, s.notes, 'template', s.id
  from public.shifts s
  where s.organization_id = p_org
    and s.is_active
    and s.day_of_week = extract(dow from p_date)::int
  on conflict (template_shift_id, block_date) do update
    set driver_id = excluded.driver_id,
        vehicle_id = excluded.vehicle_id,
        start_time = excluded.start_time,
        end_time = excluded.end_time,
        note = excluded.note
    where public.shift_blocks.status = 'scheduled';

  delete from public.shift_blocks b
  where b.organization_id = p_org
    and b.block_date = p_date
    and b.source = 'template'
    and b.status = 'scheduled'
    and not exists (
      select 1 from public.shifts s
      where s.id = b.template_shift_id and s.is_active
        and s.day_of_week = extract(dow from p_date)::int
    );

  perform set_config('cm.shift_block_rpc', 'off', true);
end $$;

-- ── Driver: today's classes ──────────────────────────────────────────
create or replace function public.get_my_shift_day(p_org uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_tz text;
  v_window int;
  v_today date;
  v_blocks jsonb;
  v_day public.driver_workdays;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  select timezone, shift_start_window_minutes into v_tz, v_window
  from public.organizations where id = p_org;
  v_today := (now() at time zone v_tz)::date;

  perform public.materialize_shift_blocks(p_org, v_today);

  select * into v_day from public.driver_workdays
  where organization_id = p_org and driver_id = v_uid and work_date = v_today;

  select coalesce(jsonb_agg(jsonb_build_object(
      'id', b.id,
      'start_time', b.start_time,
      'end_time', b.end_time,
      'note', b.note,
      'vehicle_id', b.vehicle_id,
      'vehicle_label', nullif(concat_ws(' ', v.make, v.model), ''),
      'vehicle_display_id', v.display_id,
      'status', b.status,
      'late_minutes', b.late_minutes,
      'opens_at', ((b.block_date + b.start_time) at time zone v_tz) - make_interval(mins => v_window),
      'closes_at', ((b.block_date + b.start_time) at time zone v_tz) + make_interval(mins => v_window)
    ) order by b.start_time), '[]'::jsonb)
  into v_blocks
  from public.shift_blocks b
  left join public.vehicles v on v.id = b.vehicle_id
  where b.organization_id = p_org and b.driver_id = v_uid and b.block_date = v_today
    and b.status <> 'cancelled';

  return jsonb_build_object(
    'date', v_today,
    'window_minutes', v_window,
    'workday_open', v_day.id is not null and v_day.closed_at is null,
    'workday_closed', v_day.closed_at is not null,
    'blocks', v_blocks
  );
end $$;

create or replace function public.start_shift_block(p_block_id uuid)
returns public.shift_blocks language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  b public.shift_blocks;
  v_tz text;
  v_window int;
  v_start timestamptz;
  v_day public.driver_workdays;
begin
  select * into b from public.shift_blocks where id = p_block_id for update;
  if b.id is null or b.driver_id is distinct from v_uid then
    raise exception 'Class not found';
  end if;
  if b.status <> 'scheduled' then
    raise exception 'This class is not available to start';
  end if;

  select timezone, shift_start_window_minutes into v_tz, v_window
  from public.organizations where id = b.organization_id;
  v_start := (b.block_date + b.start_time) at time zone v_tz;

  if now() < v_start - make_interval(mins => v_window) then
    raise exception 'SHIFT_BLOCK_TOO_EARLY:%', to_char((v_start - make_interval(mins => v_window)) at time zone v_tz, 'HH12:MI AM');
  end if;
  if now() > v_start + make_interval(mins => v_window) then
    raise exception 'SHIFT_BLOCK_WINDOW_CLOSED';
  end if;
  if exists (select 1 from public.shift_blocks x
             where x.driver_id = v_uid and x.status = 'in_progress' and x.id <> b.id) then
    raise exception 'SHIFT_BLOCK_ANOTHER_IN_PROGRESS';
  end if;

  select * into v_day from public.driver_workdays
  where organization_id = b.organization_id and driver_id = v_uid and work_date = b.block_date;
  if v_day.closed_at is not null then
    raise exception 'WORKDAY_ALREADY_CLOSED';
  end if;
  if v_day.id is null then
    insert into public.driver_workdays (organization_id, driver_id, work_date)
    values (b.organization_id, v_uid, b.block_date);
  end if;

  perform set_config('cm.shift_block_rpc', 'on', true);
  update public.shift_blocks
     set status = 'in_progress',
         started_at = now(),
         late_minutes = greatest(0, floor(extract(epoch from (now() - v_start)) / 60))::int
   where id = b.id
   returning * into b;
  perform set_config('cm.shift_block_rpc', 'off', true);
  return b;
end $$;

-- Undo a start whose trip never got going (GPS/odometer step failed).
create or replace function public.abort_shift_block_start(p_block_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform set_config('cm.shift_block_rpc', 'on', true);
  update public.shift_blocks
     set status = 'scheduled', started_at = null, late_minutes = null
   where id = p_block_id and driver_id = auth.uid()
     and status = 'in_progress' and session_id is null;
  perform set_config('cm.shift_block_rpc', 'off', true);
end $$;

create or replace function public.end_shift_block(p_block_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform set_config('cm.shift_block_rpc', 'on', true);
  update public.shift_blocks
     set status = 'done', ended_at = now()
   where id = p_block_id and driver_id = auth.uid() and status = 'in_progress';
  perform set_config('cm.shift_block_rpc', 'off', true);
end $$;

create or replace function public.close_my_workday(p_org uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
begin
  if exists (select 1 from public.shift_blocks
             where organization_id = p_org and driver_id = v_uid and status = 'in_progress') then
    raise exception 'WORKDAY_BLOCK_IN_PROGRESS';
  end if;
  update public.driver_workdays
     set closed_at = now()
   where organization_id = p_org and driver_id = v_uid
     and work_date = public.fn_org_local_today(p_org) and closed_at is null;
end $$;

-- ── Admin/operator: a day's schedule (web) ───────────────────────────
create or replace function public.get_org_shift_day(p_org uuid, p_date date)
returns setof public.shift_blocks language plpgsql security definer set search_path = public as $$
begin
  if not public.is_org_operator_or_above(p_org) then
    raise exception 'Only an owner, admin or operator can see the schedule';
  end if;
  perform public.materialize_shift_blocks(p_org, p_date);
  return query
    select * from public.shift_blocks
    where organization_id = p_org and block_date = p_date
    order by start_time;
end $$;

revoke execute on function public.materialize_shift_blocks(uuid, date) from public, anon;
revoke execute on function public.get_my_shift_day(uuid) from public, anon;
revoke execute on function public.start_shift_block(uuid) from public, anon;
revoke execute on function public.abort_shift_block_start(uuid) from public, anon;
revoke execute on function public.end_shift_block(uuid) from public, anon;
revoke execute on function public.close_my_workday(uuid) from public, anon;
revoke execute on function public.get_org_shift_day(uuid, date) from public, anon;
revoke execute on function public.fn_org_local_today(uuid) from public, anon;
grant execute on function public.get_my_shift_day(uuid) to authenticated;
grant execute on function public.start_shift_block(uuid) to authenticated;
grant execute on function public.abort_shift_block_start(uuid) to authenticated;
grant execute on function public.end_shift_block(uuid) to authenticated;
grant execute on function public.close_my_workday(uuid) to authenticated;
grant execute on function public.get_org_shift_day(uuid, date) to authenticated;

-- ── Abandoned classes/days (same hourly job as abandoned trips) ──────
create or replace function public.close_abandoned_trips(p_idle interval default interval '12 hours')
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_closed integer := 0;
begin
  for r in
    select s.id,
           greatest(
             s.start_time,
             s.updated_at,
             (select max(b.recorded_at) from public.session_gps_breadcrumbs b where b.session_id = s.id),
             (select max(x.updated_at) from public.session_sections x where x.session_id = s.id)
           ) as last_activity
    from public.sessions s
    where not coalesce(s.is_closed, false)
  loop
    continue when r.last_activity is null or r.last_activity > now() - p_idle;

    update public.session_sections
       set section_status = 'closed',
           end_time = coalesce(end_time, r.last_activity)
     where session_id = r.id
       and section_status in ('active', 'paused');

    update public.sessions s
       set is_closed = true,
           session_status = 'closed',
           end_time = coalesce(s.end_time, r.last_activity),
           total_miles = greatest(
             coalesce(s.total_miles, 0),
             coalesce((select sum(x.total_miles) from public.session_sections x where x.session_id = s.id), 0)
           )
     where s.id = r.id;

    v_closed := v_closed + 1;
  end loop;

  -- A class left in progress past the idle limit (the app died mid-class)
  -- is ended; a workday left open for more than a day is closed.
  perform set_config('cm.shift_block_rpc', 'on', true);
  update public.shift_blocks b
     set status = 'done', ended_at = coalesce(
       (select s.end_time from public.sessions s where s.id = b.session_id), now())
   where b.status = 'in_progress'
     and b.started_at < now() - p_idle
     and not exists (select 1 from public.sessions s where s.id = b.session_id and not s.is_closed);
  perform set_config('cm.shift_block_rpc', 'off', true);

  update public.driver_workdays set closed_at = now()
   where closed_at is null and opened_at < now() - interval '24 hours';

  return v_closed;
end;
$$;

-- (applied separately as shift_blocks_allow_restore) A cancelled class can
-- be put back on the schedule (status only); any other edit to a block that
-- is no longer 'scheduled' stays refused.
create or replace function public.fn_freeze_started_shift_block()
returns trigger language plpgsql as $$
begin
  if current_setting('cm.shift_block_rpc', true) is not distinct from 'on' then
    return new;
  end if;
  if old.status = 'scheduled' then
    return new;
  end if;
  if old.status = 'cancelled' and new.status = 'scheduled'
     and (new.driver_id, new.vehicle_id, new.block_date, new.start_time, new.end_time, new.note)
         is not distinct from
         (old.driver_id, old.vehicle_id, old.block_date, old.start_time, old.end_time, old.note) then
    return new;
  end if;
  raise exception 'A class that already started cannot be edited';
end $$;
