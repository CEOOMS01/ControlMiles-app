-- Pre-launch audit (2026-09-30), applied as prelaunch_hardening.
-- 1. Fixed search_path on the functions the Supabase linter flagged.
alter function public.fn_profile_requires_pretrip(text) set search_path = public;
alter function public.fn_valid_fleet_profile(text) set search_path = public;
alter function public.fn_safety_score(numeric, numeric) set search_path = public;
alter function public.fn_freeze_started_shift_block() set search_path = public;
alter function public.fn_validate_org_timezone() set search_path = public;
alter function public.fn_guard_profile_protected_columns() set search_path = public;

-- 2. Trigger functions are not meant to be called over the API. Triggers
-- still fire (PostgreSQL doesn't check EXECUTE for trigger functions) --
-- verified in a rolled-back transaction after applying.
do $$
declare f text;
begin
  foreach f in array array[
    'fn_enforce_active_org_membership()', 'fn_enforce_odometer_cycle_tier()',
    'fn_enforce_trial_or_subscription()', 'fn_enforce_vehicle_assignment_mode_tier()',
    'fn_enforce_vehicle_count_limit()', 'fn_fuel_purchase_evaluate_trigger()',
    'fn_link_session_to_shift_block()', 'fn_notify_trip_safety()',
    'fn_vehicle_active_trip()', 'handle_new_user()'
  ] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- 3. Duplicate index (the unique constraint's own index stays).
drop index if exists public.idx_profiles_display_id;
