-- CRITICAL BUG FIX: the previous version of this function (see
-- 20260825150000_handle_new_user_add_last_name.sql) explicitly INSERTed a
-- computed value into full_name -- but full_name is actually a
-- GENERATED ALWAYS AS (...) STORED column (computed automatically by
-- Postgres from first_name/last_name), which was never checked before
-- writing that INSERT. Every real signup since that migration would have
-- hit "column full_name can only be updated to DEFAULT", been swallowed by
-- this function's own EXCEPTION WHEN OTHERS handler, and silently created
-- NO profiles row and NO user_onboarding row for the new user -- while
-- auth.users itself still succeeded, so the person would appear to have
-- signed up but the app would be broken for them everywhere profiles is
-- read. Confirmed via a live check (auth.users LEFT JOIN profiles) that
-- this had NOT actually happened yet -- both real users predate the bug --
-- but it would have on the very next real signup. Fix: stop passing
-- full_name explicitly; Postgres computes it on its own.
--
-- The exact same mistake existed in profile_screen.dart's _saveProfile
-- (a plain UPDATE targeting full_name directly) -- that one predates this
-- session entirely and has presumably been broken since full_name was
-- first added as a generated column. Fixed in the same pass, client-side.
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_first_name TEXT;
  v_last_name TEXT;
BEGIN
  v_first_name := COALESCE(
    NEW.raw_user_meta_data->>'first_name',
    SPLIT_PART(COALESCE(NEW.email, ''), '@', 1)
  );
  v_last_name := NULLIF(COALESCE(NEW.raw_user_meta_data->>'last_name', ''), '');

  INSERT INTO public.profiles (id, email, first_name, last_name, account_type)
  VALUES (NEW.id, NEW.email, v_first_name, v_last_name, 'gig')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_onboarding (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;

EXCEPTION WHEN OTHERS THEN
  RAISE LOG '[ControlMiles] handle_new_user FAILED for uid=% email=% | error: %', NEW.id, NEW.email, SQLERRM;
  RETURN NEW;
END;
$function$;
