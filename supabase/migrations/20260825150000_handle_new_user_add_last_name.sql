-- BUG FIX: profiles.last_name/full_name have existed since before this
-- session (profile_screen.dart already edits them, reports_screen.dart
-- already reads full_name for the PDF legal name), but handle_new_user
-- only ever read/wrote first_name at signup -- last_name/full_name stayed
-- NULL for every account until the user separately visited Profile and
-- filled them in by hand. login_screen.dart's signup form now collects
-- both, so the trigger needs to actually store what it's sent.
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_first_name TEXT;
  v_last_name TEXT;
  v_full_name TEXT;
BEGIN
  v_first_name := COALESCE(
    NEW.raw_user_meta_data->>'first_name',
    SPLIT_PART(COALESCE(NEW.email, ''), '@', 1)
  );
  v_last_name := COALESCE(NEW.raw_user_meta_data->>'last_name', '');
  v_full_name := NULLIF(TRIM(BOTH ' ' FROM (v_first_name || ' ' || v_last_name)), '');

  INSERT INTO public.profiles (id, email, first_name, last_name, full_name, account_type)
  VALUES (NEW.id, NEW.email, v_first_name, NULLIF(v_last_name, ''), v_full_name, 'gig')
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
