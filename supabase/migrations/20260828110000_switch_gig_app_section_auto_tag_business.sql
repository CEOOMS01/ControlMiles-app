-- Olympus Mont Systems LLC - ControlMiles
-- IRS Fase 3 (2026-08-28): the RPC itself was hardcoding irs_purpose to
-- null for any non-'custom' gig_app, silently discarding whatever the
-- Dart caller passed -- switching to a named gig app mid-trip (the
-- auto-detect path, and the manual GigAppSelector path) never got tagged
-- as business use no matter what the client sent. Driving for a named
-- gig platform is unambiguously business use; reuses the same
-- IrsPurposeCatalog category system 'custom' mode already writes to.

CREATE OR REPLACE FUNCTION public.switch_gig_app_section(
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
RETURNS SETOF session_sections
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
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

  return query
  insert into session_sections (
    id, session_id, user_id, organization_id, gig_app, irs_purpose,
    section_status, total_miles, total_duration_seconds, start_time
  )
  values (
    p_new_section_id, p_session_id, auth.uid(), v_org_id, p_new_gig_app,
    case when p_new_gig_app = 'custom' then p_new_irs_purpose else 'business' end,
    'active', 0, 0, now()
  )
  returning *;
end;
$function$;
