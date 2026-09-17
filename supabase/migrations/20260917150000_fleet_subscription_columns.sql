-- Fleet self-serve billing, piece 1 (explicit user request, 2026-09-17):
-- the individual Gig-driver Stripe integration (subscriptions,
-- profiles.base_entitled/premium_entitled, stripe-webhook) has existed
-- since 2026-08-28, but nothing analogous exists for a Fleet org -- the
-- public pricing page has always advertised Starter/Growth per-vehicle
-- pricing with no live checkout behind it. These columns are the org-side
-- mirror of what `subscriptions` already tracks per-user: a Fleet
-- subscription belongs to the ORGANIZATION (its price scales with vehicle
-- count, not with any one admin's account), so it lives on
-- `organizations` directly rather than a separate join table -- there is
-- at most one active Fleet subscription per org, same one-row-per-subject
-- shape `profiles.premium_entitled` already uses for the per-user case.
alter table public.organizations
  add column stripe_customer_id text,
  add column subscription_tier text check (subscription_tier in ('starter', 'growth')),
  add column subscription_status text,
  add column subscription_vehicle_count integer,
  add column subscription_updated_at timestamptz;

-- Mirrors profiles_select_own's own reasoning: an org's billing state is
-- readable by anyone who can already read the org row (is_org_member),
-- same as compliance_mode/vehicle_assignment_mode above it -- there is no
-- separate, more restrictive policy here because organizations_select
-- already covers this table and these are just more columns on it, not a
-- new table needing its own RLS.
