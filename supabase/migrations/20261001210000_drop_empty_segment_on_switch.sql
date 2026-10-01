-- Rule (explicit user request, 2026-10-01): when a trip switches gig app --
-- manually or through Automatic Detection, both go through
-- switch_gig_app_section -- the segment that just ended is closed right
-- there, and if it tracked no miles (< 0.05 mi, the same threshold as
-- trg_discard_zero_mile_trip) it is removed from the session at that
-- moment, not left as a 0.00 mi "trip". The driver gets the same notice as
-- a discarded trip (the app shows it; see TrackingController.switchSection).
-- The new segment carries on. At End Trip, the last segment follows the
-- same rule through fn_fold_empty_trip_sections (20261001200000).
--
-- Like fn_fold_empty_trip_sections, the segment's audit events and GPS
-- breadcrumbs move to the new segment before it is deleted: events are
-- hash-chained per session and section_id is not hashed, so the chain
-- stays valid. Segments with notes or an odometer photo are kept.

create or replace function public.fn_drop_empty_switched_section(
  p_section_id uuid,
  p_into_section_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.session_sections%rowtype;
begin
  select * into s from public.session_sections where id = p_section_id;
  if not found
     or s.user_id is distinct from auth.uid()
     or s.section_status <> 'switched'
     or coalesce(s.total_miles, 0) >= 0.05
     or nullif(btrim(coalesce(s.notes, '')), '') is not null
     or s.start_odometer_image_url is not null
     or s.end_odometer_image_url is not null then
    return false;
  end if;

  -- The target must be another segment of the same trip owned by the caller.
  if not exists (
    select 1 from public.session_sections t
     where t.id = p_into_section_id
       and t.id <> s.id
       and t.session_id = s.session_id
       and t.user_id = auth.uid()
  ) then
    return false;
  end if;

  update public.audit_events set section_id = p_into_section_id where section_id = s.id;
  update public.session_gps_breadcrumbs set section_id = p_into_section_id where section_id = s.id;
  delete from public.session_sections where id = s.id;
  return true;
end;
$$;

revoke execute on function public.fn_drop_empty_switched_section(uuid, uuid) from public, anon;
grant execute on function public.fn_drop_empty_switched_section(uuid, uuid) to authenticated;

-- Same signature and result as before (the app is unchanged on that
-- side); the only addition is the drop of the old segment, in the same
-- transaction as the switch -- all or nothing.
create or replace function public.switch_gig_app_section(
  p_session_id uuid,
  p_old_section_id uuid,
  p_new_section_id uuid,
  p_new_gig_app text,
  p_new_irs_purpose text,
  p_old_total_miles double precision,
  p_old_total_duration_seconds integer,
  p_old_end_latitude double precision,
  p_old_end_longitude double precision
)
returns setof public.session_sections
language plpgsql
set search_path to 'public'
as $function$
declare
  v_org_id uuid;
begin
  select organization_id into v_org_id from public.sessions where id = p_session_id;

  if p_old_section_id is not null then
    update session_sections
    set section_status = 'switched',
        end_time = now(),
        total_miles = coalesce(p_old_total_miles, total_miles),
        total_duration_seconds = coalesce(p_old_total_duration_seconds, total_duration_seconds),
        end_latitude = p_old_end_latitude,
        end_longitude = p_old_end_longitude
    where id = p_old_section_id
      and user_id = auth.uid()
      and section_status in ('active', 'paused');
  end if;

  insert into session_sections (
    id, session_id, user_id, organization_id, gig_app, irs_purpose,
    section_status, total_miles, total_duration_seconds, start_time
  )
  values (
    p_new_section_id, p_session_id, auth.uid(), v_org_id, p_new_gig_app,
    case when p_new_gig_app = 'custom' then p_new_irs_purpose else 'business' end,
    'active', 0, 0, now()
  );

  if p_old_section_id is not null then
    perform public.fn_drop_empty_switched_section(p_old_section_id, p_new_section_id);
  end if;

  return query select * from session_sections where id = p_new_section_id;
end;
$function$;
