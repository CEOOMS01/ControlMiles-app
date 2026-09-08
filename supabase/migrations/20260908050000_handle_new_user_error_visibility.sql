-- Security hardening (explicit user request, 2026-09-08): handle_new_user's
-- broad EXCEPTION WHEN OTHERS is kept exactly as-is on purpose -- it exists
-- so an unrelated profile-creation hiccup can never turn into a broken
-- signup (auth.users still succeeds even if this trigger's own inserts
-- fail). The real gap: the only visibility today is RAISE LOG, which goes
-- to Postgres's own server log -- not queryable from the app or a normal
-- SQL client, easy to lose to log rotation, and nobody is alerted. This
-- adds a durable, queryable record of the exact same failure alongside
-- the existing RAISE LOG (kept, not replaced -- real-time ops tailing logs
-- still want it), so a silent signup failure is auditable via a plain
-- SELECT instead of invisible.

CREATE TABLE public.auth_signup_errors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  email text,
  error_message text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.auth_signup_errors ENABLE ROW LEVEL SECURITY;
-- Deliberately no policies at all -- this is an internal diagnostic log,
-- never meant to be readable by any client role (authenticated or anon).
-- Only ever written by handle_new_user (SECURITY DEFINER) below; read via
-- the Supabase SQL editor / service role, same access model already used
-- for edge_function_rate_limits.

REVOKE ALL ON public.auth_signup_errors FROM public, anon, authenticated;

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

  -- Best-effort: if even THIS insert fails somehow, still return NEW so
  -- the real signup is never blocked by a logging problem.
  BEGIN
    INSERT INTO public.auth_signup_errors (user_id, email, error_message)
    VALUES (NEW.id, NEW.email, SQLERRM);
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$function$;
