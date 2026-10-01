-- Silent bug found live (2026-10-01, user report): a trip WITH miles kept
-- its zero-mile segments -- e.g. Lyft 1.97 mi, then a 6-second switch to
-- Empower with 0.0066 mi right before End Trip, shown as a "0.00 mi" trip
-- inside the session. trg_discard_zero_mile_trip (20260929130000) only
-- dropped WHOLE trips under 0.05 mi; segments inside a kept trip were
-- never checked.
--
-- Same 0.05 mi rule, now per segment, when the trip closes (app End Trip
-- or close_abandoned_trips): each segment under 0.05 mi is folded into the
-- nearest segment that has miles (the previous one first) and deleted.
-- Folding, not a plain delete: audit_events and GPS breadcrumbs reference
-- the segment with ON DELETE CASCADE, and audit_events are hash-chained
-- per SESSION (AuditService._getLastHash) -- deleting a segment's events
-- would break the trip's chain. section_id is not part of the event hash
-- (hashJson covers sessionId/eventType/payload/timestamp/prevHash), so
-- re-pointing the events keeps every hash valid. Breadcrumbs move too, so
-- the trip's map keeps its last few meters.
--
-- Segments are left alone when they carry something the driver entered
-- (notes) or an odometer photo, and when no segment of the trip has miles
-- (the whole-trip rule already deletes that trip). The session's own
-- totals are untouched (it is frozen once closed; the folded distance is
-- under 0.05 mi by definition).

create or replace function public.fn_fold_empty_trip_sections(p_session_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_keep uuid;
  v_folded integer := 0;
begin
  for r in
    select id, start_time
      from public.session_sections
     where session_id = p_session_id
       and coalesce(total_miles, 0) < 0.05
       and section_status in ('closed', 'switched')
       and nullif(btrim(coalesce(notes, '')), '') is null
       and start_odometer_image_url is null
       and end_odometer_image_url is null
  loop
    select k.id into v_keep
      from public.session_sections k
     where k.session_id = p_session_id
       and coalesce(k.total_miles, 0) >= 0.05
     order by (k.start_time <= r.start_time) desc,
              abs(extract(epoch from (k.start_time - r.start_time)))
     limit 1;

    continue when v_keep is null;

    update public.audit_events set section_id = v_keep where section_id = r.id;
    update public.session_gps_breadcrumbs set section_id = v_keep where section_id = r.id;
    delete from public.session_sections where id = r.id;
    v_folded := v_folded + 1;
  end loop;
  return v_folded;
end;
$$;

revoke execute on function public.fn_fold_empty_trip_sections(uuid) from public, anon, authenticated;

create or replace function public.fn_discard_zero_mile_trip()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.total_miles, 0) < 0.05
     and coalesce((select sum(ss.total_miles) from public.session_sections ss
                   where ss.session_id = new.id), 0) < 0.05 then
    delete from public.sessions where id = new.id;
  else
    -- Trip kept: drop its empty segments (see header).
    perform public.fn_fold_empty_trip_sections(new.id);
  end if;
  return null;
end;
$$;

revoke execute on function public.fn_discard_zero_mile_trip() from public, anon, authenticated;
