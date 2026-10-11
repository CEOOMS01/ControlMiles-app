-- Silent failure found in the 2026-10-10 audit: no trip had EVER been
-- sealed (sessions.cgc_sealed_at null on all of them). cgc-seal-trip runs
-- after End Trip, i.e. on a CLOSED session, and fn_freeze_closed_session
-- rejected every update to a closed session -- including writing the seal.
-- The function did not check the update's error and answered 200.
--
-- A closed trip stays frozen, with one exception: its seal can be written
-- once (cgc_decision_id / cgc_sealed_at going from null to a value) when
-- nothing else changes. updated_at is excluded from the comparison because
-- tr_sessions_touch_updated_at (fires first, alphabetical order) sets it.

create or replace function public.fn_freeze_closed_session()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  if OLD.is_closed = true then
    if OLD.cgc_sealed_at is null
       and NEW.cgc_sealed_at is not null
       and (to_jsonb(NEW) - 'cgc_decision_id' - 'cgc_sealed_at' - 'updated_at')
         = (to_jsonb(OLD) - 'cgc_decision_id' - 'cgc_sealed_at' - 'updated_at') then
      return NEW;
    end if;
    raise exception 'Cannot modify a closed session';
  end if;
  return NEW;
end;
$$;
