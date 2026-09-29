-- INDUSTRY TEMPLATES (user request 2026-09-29: "diseñados para darle un
-- toque más personalizado a las empresas"). Researched first: vertical SaaS
-- (HubSpot's onboarding survey, Connecteam's per-industry setups, Jobber)
-- ask what kind of business it is and switch on only the matching features
-- and vocabulary, changeable later in Settings. Available on every fleet
-- subscription for now (user decision; may move to higher fleet tiers).
--
-- 'general'        -- default fleet: weekly shifts, routes, etc.
-- 'driving_school' -- adds hourly Classes (shift_blocks): the Day schedule
--                     on the web and "Today's classes" in the driver app.
-- A fleet that is not a driving school never sees or generates classes.

alter table public.organizations
  add column if not exists industry_template text not null default 'general';

do $$ begin
  alter table public.organizations
    add constraint organizations_industry_template_check
    check (industry_template in ('general', 'driving_school'));
exception when duplicate_object then null; end $$;

create or replace function public.fn_org_has_classes(p_org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select industry_template = 'driving_school' from public.organizations where id = p_org), false);
$$;
revoke execute on function public.fn_org_has_classes(uuid) from public, anon;
grant execute on function public.fn_org_has_classes(uuid) to authenticated;

-- One-off classes can only be created in a driving-school fleet.
drop policy if exists shift_blocks_insert on public.shift_blocks;
create policy shift_blocks_insert on public.shift_blocks for insert to authenticated
  with check (public.is_org_operator_or_above(organization_id)
              and source = 'one_off'
              and public.fn_org_has_classes(organization_id));

-- The weekly template only becomes classes in a driving-school fleet.
create or replace function public.materialize_shift_blocks(p_org uuid, p_date date)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_org_member(p_org, null) then
    raise exception 'Not a member of this organization';
  end if;
  if not public.fn_org_has_classes(p_org) then
    return;
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

-- Driver app: no classes at all unless the fleet is a driving school.
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
  if not public.fn_org_has_classes(p_org) then
    return jsonb_build_object('date', null, 'window_minutes', null,
      'workday_open', false, 'workday_closed', false, 'blocks', '[]'::jsonb);
  end if;

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

-- Classes already scheduled (not started) in fleets that aren't driving
-- schools -- e.g. the test fleet's weekly 8-5 shift that had been
-- materialized as a "class" -- are removed; history (started/done) stays.
delete from public.shift_blocks b
using public.organizations o
where o.id = b.organization_id
  and o.industry_template <> 'driving_school'
  and b.status = 'scheduled';
