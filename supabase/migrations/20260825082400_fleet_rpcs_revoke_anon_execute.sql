-- Real fix, corrects a mistake in this session's own earlier migration
-- (create_organization_restrict_to_authenticated): Supabase's public schema
-- has a default-privileges rule that auto-grants EXECUTE directly to the
-- `anon` role on every newly created function -- confirmed via pg_proc.proacl
-- (anon=X/postgres), NOT via the `PUBLIC` pseudo-role. `REVOKE ... FROM
-- PUBLIC` (what the earlier migration did) revokes a grant that was never
-- the one actually in effect, so it silently did nothing. None of these
-- functions have ever been exploitable as anon regardless -- every one has
-- its own internal `auth.uid() IS NULL` guard that raises before doing
-- anything -- but the grant itself should still say what's actually
-- intended rather than leave a stale, misleading REVOKE FROM PUBLIC in the
-- migration history.
REVOKE EXECUTE ON FUNCTION public.create_organization(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.invite_member_by_email(uuid, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.respond_to_invite(uuid, boolean) FROM anon;
REVOKE EXECUTE ON FUNCTION public.assign_vehicle_to_driver(uuid, uuid) FROM anon;
