-- Explicit user requirement (2026-09-17): Gig tier restructuring --
-- Started's free trial shortened from 30 to 15 days (Basic goes to
-- $5.99/mo, Premium stays $9.99/mo but gains its own separate 5-day
-- trial handled entirely on the Stripe side via
-- subscription_data[trial_period_days] in create-checkout-session --
-- that one never touches this function, since a Premium subscriber
-- already has premium_entitled true from the moment Stripe creates the
-- trialing subscription, via the existing stripe-webhook sync).
--
-- Real floor lives here (fn_enforce_trial_or_subscription, the trigger
-- that blocks a new trip once expired); lib/logic/app_state.dart's
-- _freeTrialDays is the client-side mirror for instant UX only, updated
-- to match in the same commit as this migration.

create or replace function public.fn_enforce_trial_or_subscription()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_created_at timestamptz;
  v_base boolean;
  v_premium boolean;
  v_account_type text;
  v_exempt boolean;
begin
  select created_at, base_entitled, premium_entitled, account_type, tier_enforcement_exempt
    into v_created_at, v_base, v_premium, v_account_type, v_exempt
    from public.profiles
    where id = new.user_id;

  if v_exempt is true then
    return new;
  end if;

  if v_account_type is distinct from 'gig' then
    return new;
  end if;

  if v_base is true or v_premium is true then
    return new;
  end if;

  if v_created_at is not null and now() - v_created_at > interval '15 days' then
    raise exception 'FREE_TRIAL_EXPIRED';
  end if;

  return new;
end;
$$;
