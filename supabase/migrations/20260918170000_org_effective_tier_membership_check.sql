-- Security hardening, found while wiring page-level Growth gating into
-- controlmiles-web (2026-09-18): fn_org_effective_tier had no membership
-- check of its own -- every internal caller (RLS policies, RPCs that
-- already gate via is_org_operator_or_above first) only ever invoked it
-- after confirming the caller belongs to that org, but the function is
-- GRANT EXECUTE'd to `authenticated`, which means PostgREST exposes it as
-- a directly callable RPC to any signed-in user, with any org_id they
-- want to guess. Low severity (only leaks which of three tier strings an
-- org is on, nothing else), but free to close: any non-member now gets
-- 'none' instead of a real answer, matching how is_org_member-gated
-- reads already behave everywhere else in this schema.
create or replace function public.fn_org_effective_tier(p_org_id uuid)
returns text
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_tier text;
begin
  if not public.is_org_member(p_org_id) then
    return 'none';
  end if;

  select case
    when o.tier_enforcement_exempt then 'growth'
    when o.subscription_status in ('active', 'trialing') and o.subscription_tier = 'growth' then 'growth'
    when o.subscription_status in ('active', 'trialing') and o.subscription_tier = 'starter' then 'starter'
    when now() - o.created_at <= interval '5 days' then 'starter'
    else 'none'
  end
  into v_tier
  from public.organizations o
  where o.id = p_org_id;

  return v_tier;
end;
$$;
