-- SECURITY (2026-09-16, launch audit): check_rate_limit was EXECUTE-able by
-- anon and authenticated via PostgREST (/rest/v1/rpc/check_rate_limit).
-- Because the caller controls every argument, anyone holding the public anon
-- key could:
--   * fill another user's bucket -- check_rate_limit('create-checkout-session',
--     '<victim user id>', ...) a few times locks that user out of checkout;
--   * insert unbounded rows into edge_function_rate_limits (table bloat).
--
-- All six edge functions that use it were redeployed FIRST to call it with the
-- SERVICE-ROLE key instead of the anon/user key, so revoking here does not
-- break rate limiting (which fails open -- silently disabling it would have
-- been worse than the original exposure).
--
-- resolve_driver_invite keeps working: it is SECURITY DEFINER owned by
-- postgres, so its internal call to check_rate_limit runs as postgres, not as
-- the calling role. Verified live as anon after this migration.
revoke execute on function public.check_rate_limit(text, text, integer, integer)
  from anon, authenticated, public;

grant execute on function public.check_rate_limit(text, text, integer, integer)
  to service_role;
