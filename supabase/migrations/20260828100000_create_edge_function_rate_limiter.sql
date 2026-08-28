-- Olympus Mont Systems LLC - ControlMiles
-- REAL FIX (2026-08-28): an in-memory Map-based rate limiter was deployed
-- to report-error/create-checkout-session/create-portal-session/
-- cgc-seal-trip and verified LIVE via a genuine 25-request concurrent
-- burst against report-error -- every single request returned 200, no
-- 429s at all. Supabase's Deno edge runtime does not reliably share a
-- module-level in-memory Map across concurrent (or even close-together
-- sequential) invocations the way a single warm traditional server
-- would -- the exact same lesson CGC Core's own TenantManager already
-- learned the hard way (see that project's own migration history:
-- in-memory usage counts never actually enforced a limit, replaced with
-- a real Postgres counter). Same fix here: a durable table + a
-- SECURITY DEFINER function that does an atomic prune+count+insert
-- under an advisory lock, so concurrent calls from the same caller
-- can't race past the limit either.

CREATE TABLE IF NOT EXISTS public.edge_function_rate_limits (
  id bigserial PRIMARY KEY,
  fn_name text NOT NULL,
  client_key text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_edge_function_rate_limits_lookup
  ON public.edge_function_rate_limits(fn_name, client_key, created_at DESC);

ALTER TABLE public.edge_function_rate_limits ENABLE ROW LEVEL SECURITY;
-- Deliberately no policies -- only ever touched via the SECURITY DEFINER
-- function below, never read/written directly by anon/authenticated.

CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_fn_name text,
  p_client_key text,
  p_max_requests int,
  p_window_seconds int
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int;
BEGIN
  -- Scoped advisory lock so concurrent calls from the SAME caller are
  -- serialized (can't both read "under limit" then both insert) --
  -- different callers never block each other.
  PERFORM pg_advisory_xact_lock(hashtext(p_fn_name || ':' || p_client_key));

  DELETE FROM public.edge_function_rate_limits
  WHERE fn_name = p_fn_name AND client_key = p_client_key
    AND created_at < now() - (p_window_seconds || ' seconds')::interval;

  SELECT count(*) INTO v_count
  FROM public.edge_function_rate_limits
  WHERE fn_name = p_fn_name AND client_key = p_client_key;

  IF v_count >= p_max_requests THEN
    RETURN false;
  END IF;

  INSERT INTO public.edge_function_rate_limits (fn_name, client_key) VALUES (p_fn_name, p_client_key);
  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_rate_limit(text, text, int, int) TO anon, authenticated;
