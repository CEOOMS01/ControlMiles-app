-- Security advisor flagged create_organization as callable by `anon` --
-- Postgres functions default to PUBLIC-executable unless revoked, so the
-- earlier GRANT TO authenticated was additive, not restrictive. The
-- function's own `auth.uid() IS NULL` guard already made an anon call fail
-- safely, but there's no reason to expose the RPC to unauthenticated
-- callers at all. Explicit revoke + grant, matching the intent.
REVOKE EXECUTE ON FUNCTION public.create_organization(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_organization(text) TO authenticated;
