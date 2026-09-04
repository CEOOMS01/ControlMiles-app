-- Security hardening (Supabase advisor: function_search_path_mutable, WARN):
-- these 12 functions had no SET search_path, meaning their unqualified
-- object references (tables, other functions) resolve against whatever
-- search_path the CALLING session happens to have -- normally harmless, but
-- an attacker who can create objects earlier in a search_path than `public`
-- (e.g. a schema they own) could in principle shadow a table/function these
-- rely on. All 12 are SECURITY INVOKER (verified: none SECURITY DEFINER),
-- so this was never a privilege-escalation path -- worst case would be the
-- invoking user's own confused-deputy against their own session, still
-- fixed as standard defense-in-depth per Supabase's own lint.
--
-- ALTER FUNCTION ... SET search_path only pins the search_path config
-- parameter -- it does not touch the function body/definition, so this is
-- a zero-behavior-change hardening pass.
alter function public.enforce_fleet_org_membership() set search_path = public;
alter function public.fn_assign_profile_display_id() set search_path = public;
alter function public.fn_touch_updated_at() set search_path = public;
alter function public.fn_block_vehicle_switch_during_active_session() set search_path = public;
alter function public.set_active_vehicle(p_vehicle_id uuid) set search_path = public;
alter function public.fn_assign_vehicle_display_id() set search_path = public;
alter function public.fn_assign_driver_slot_display_id() set search_path = public;
alter function public.fn_freeze_closed_route() set search_path = public;
alter function public.fn_freeze_profile_display_id() set search_path = public;
alter function public.fn_freeze_vehicle_display_id() set search_path = public;
alter function public.fn_freeze_closed_session() set search_path = public;
alter function public.fn_freeze_closed_session_section() set search_path = public;
