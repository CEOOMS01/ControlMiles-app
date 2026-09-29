-- Internal tables: written/read only by SECURITY DEFINER functions and the
-- service_role (stripe-webhook, rate limiter). RLS was already on with no
-- policies (deny-all for clients); also drop the leftover table grants so
-- anon/authenticated have no path at all, even if RLS were ever disabled.
revoke all on table public.driver_slot_claim_attempts from anon, authenticated;
revoke all on table public.edge_function_rate_limits  from anon, authenticated;
revoke all on table public.report_access_attempts     from anon, authenticated;
revoke all on table public.subscription_events        from anon, authenticated;
revoke all on table public.auth_signup_errors         from anon, authenticated;

comment on table public.subscription_events is 'Internal: service_role only (stripe-webhook). No client policies by design.';
comment on table public.report_access_attempts is 'Internal: written by redeem_report_access_code (SECURITY DEFINER). No client policies by design.';
comment on table public.edge_function_rate_limits is 'Internal: edge function rate limiter. No client policies by design.';
comment on table public.driver_slot_claim_attempts is 'Internal: written by claim_driver_slot (SECURITY DEFINER). No client policies by design.';

-- spatial_ref_sys belongs to PostGIS (owner supabase_admin): RLS can't be
-- enabled and its grants can't be revoked from the postgres role (the
-- revoke below is a no-op in practice, kept to document the intent).
revoke insert, update, delete, truncate on table public.spatial_ref_sys from anon, authenticated;
