-- Security review (2026-10-20, Supabase advisors):
-- 1. Trigger functions that run as their owner (SECURITY DEFINER) were
--    executable through the API by anon/authenticated. A trigger function
--    refuses a direct call, but it shouldn't be exposed at all; triggers
--    keep firing (EXECUTE is checked when the trigger is created, not when
--    it fires).
-- 2. Four functions had a role-mutable search_path.
-- Accepted, not changed: spatial_ref_sys (PostGIS reference table, owned by
-- the extension) and postgis/pg_net in public (moving them breaks existing
-- objects); is_org_* helpers stay callable because RLS policies call them
-- as the querying role.

do $$
declare
  f regprocedure;
begin
  for f in
    select p.oid::regprocedure
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prosecdef and pg_get_function_result(p.oid) = 'trigger'
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', f);
  end loop;
end $$;

alter function public.fn_ds_certificates_immutable() set search_path = public;
alter function public.fn_ds_touch() set search_path = public;
alter function public.fn_sun_times(double precision, double precision, timestamp with time zone) set search_path = public;
alter function public.fn_valid_origins(text[]) set search_path = public;

-- 3. spatial_ref_sys (PostGIS reference table) granted INSERT, UPDATE,
--    DELETE and TRUNCATE to anon and authenticated: anyone with the public
--    key could have emptied it and broken every geometry lookup (IFTA state
--    miles). The revoke below has NO effect: the table belongs to
--    supabase_admin, not to our role. Needs Supabase support (or moving
--    PostGIS out of public). Kept so a run as the owner fixes it.
revoke insert, update, delete, truncate, references, trigger on public.spatial_ref_sys from anon, authenticated;
