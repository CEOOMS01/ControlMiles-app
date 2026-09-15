-- CRITICAL SECURITY FIX (2026-09-15, launch audit).
--
-- Before this: profiles_update_own only checks auth.uid()=id, and the
-- `authenticated` role held UPDATE on ALL 18 profiles columns. A signed-in user
-- could send a raw PostgREST PATCH on their own row setting premium_entitled /
-- base_entitled / tier_enforcement_exempt / multi_org_entitled = true (or
-- escalate account_type) and unlock the entire paid app for free -- bypassing
-- the Stripe paywall, the 30-day trial gate, and the multi-org gate at once.
-- Confirmed exploitable live under RLS as a real account.
--
-- Fix: a BEFORE UPDATE trigger that rejects any change to a protected column
-- when the caller is a client role (`authenticated`/`anon`). It is
-- SECURITY INVOKER on purpose -- as a DEFINER function current_user would always
-- resolve to the owner (postgres) and the guard would be a silent no-op (this
-- was the first, broken version; kept as a lesson). Because it is INVOKER,
-- current_user reflects the true caller:
--   * raw client write  -> 'authenticated'/'anon'  -> BLOCKED
--   * SECURITY DEFINER RPC (create_organization, switch_default_organization,
--     claim_driver_slot, respond_to_invite, ...) runs as its owner
--                        -> 'postgres'              -> allowed
--   * Stripe webhook (service_role key)             -> 'service_role' -> allowed
-- so every legitimate path that must change these columns keeps working, and
-- only a direct client-side write is stopped.
--
-- Columns the client legitimately updates directly (name, mileage_method, and
-- other non-sensitive profile fields) are deliberately NOT in the protected set.

create or replace function public.fn_guard_profile_protected_columns()
returns trigger
language plpgsql
security invoker
set search_path to 'public'
as $$
begin
  if current_user in ('authenticated', 'anon') then
    if new.id                        is distinct from old.id
       or new.display_id             is distinct from old.display_id
       or new.email                  is distinct from old.email
       or new.account_type           is distinct from old.account_type
       or new.is_active              is distinct from old.is_active
       or new.default_org_id         is distinct from old.default_org_id
       or new.base_entitled          is distinct from old.base_entitled
       or new.premium_entitled       is distinct from old.premium_entitled
       or new.multi_org_entitled     is distinct from old.multi_org_entitled
       or new.tier_enforcement_exempt is distinct from old.tier_enforcement_exempt
       or new.created_at             is distinct from old.created_at
    then
      raise exception 'PROTECTED_PROFILE_COLUMN: this field cannot be changed directly';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_profile_protected_columns on public.profiles;
create trigger trg_guard_profile_protected_columns
  before update on public.profiles
  for each row
  execute function public.fn_guard_profile_protected_columns();
