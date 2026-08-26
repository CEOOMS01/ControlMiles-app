-- Explicit user requirement: an org owner can rename their organization
-- freely, but can NEVER edit user display IDs (CM-D####/CM-<letter>),
-- vehicle display IDs (CM-T####), or recorded miles/duration once a
-- session/section is saved and closed. Org name itself needs no schema
-- change (organizations_update_admin RLS already allows it) -- this
-- migration is entirely about freezing what should never move.
--
-- Verified live (in ROLLBACK'd transactions / disposable test rows,
-- real data never touched): changing a real profile's or vehicle's
-- display_id is blocked; updating total_miles on an already-closed
-- session or session_section is blocked; the legitimate close
-- transition (is_closed false->true, setting final miles in the SAME
-- statement) still succeeds; editing a closed section's `notes`
-- (history_screen.dart's real feature) still succeeds.

create or replace function public.fn_freeze_profile_display_id()
returns trigger
language plpgsql
as $$
begin
  if OLD.display_id is not null and NEW.display_id is distinct from OLD.display_id then
    raise exception 'display_id cannot be changed once assigned';
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_freeze_profile_display_id on public.profiles;
create trigger trg_freeze_profile_display_id
  before update on public.profiles
  for each row execute function public.fn_freeze_profile_display_id();

create or replace function public.fn_freeze_vehicle_display_id()
returns trigger
language plpgsql
as $$
begin
  if OLD.display_id is not null and NEW.display_id is distinct from OLD.display_id then
    raise exception 'display_id cannot be changed once assigned';
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_freeze_vehicle_display_id on public.vehicles;
create trigger trg_freeze_vehicle_display_id
  before update on public.vehicles
  for each row execute function public.fn_freeze_vehicle_display_id();

create or replace function public.fn_freeze_closed_session()
returns trigger
language plpgsql
as $$
begin
  if OLD.is_closed = true then
    raise exception 'Cannot modify a closed session';
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_freeze_closed_session on public.sessions;
create trigger trg_freeze_closed_session
  before update on public.sessions
  for each row execute function public.fn_freeze_closed_session();

create or replace function public.fn_freeze_closed_session_section()
returns trigger
language plpgsql
as $$
begin
  if OLD.section_status = 'closed' then
    if NEW.total_miles is distinct from OLD.total_miles
      or NEW.total_duration_seconds is distinct from OLD.total_duration_seconds
      or NEW.start_time is distinct from OLD.start_time
      or NEW.end_time is distinct from OLD.end_time
      or NEW.gig_app is distinct from OLD.gig_app
      or NEW.irs_purpose is distinct from OLD.irs_purpose
      or NEW.start_latitude is distinct from OLD.start_latitude
      or NEW.start_longitude is distinct from OLD.start_longitude
      or NEW.end_latitude is distinct from OLD.end_latitude
      or NEW.end_longitude is distinct from OLD.end_longitude
      or NEW.session_id is distinct from OLD.session_id
      or NEW.user_id is distinct from OLD.user_id
      or NEW.organization_id is distinct from OLD.organization_id
    then
      raise exception 'Cannot modify a closed trip section''s recorded data';
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_freeze_closed_session_section on public.session_sections;
create trigger trg_freeze_closed_session_section
  before update on public.session_sections
  for each row execute function public.fn_freeze_closed_session_section();
