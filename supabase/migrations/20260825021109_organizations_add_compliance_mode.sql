-- Fleet Phase 1: future-proofs the org row for the not-too-distant regulated
-- CMV/ELD tier, without building ELD support now. light_duty is every
-- organization created through Phase 1's UI (company vans/trucks under
-- 10,001lb GVWR, ELD-mandate-exempt). regulated_cmv is reserved for when
-- FMCSA-certified ELD hardware integration is actually built -- this column
-- existing now means that's an additive migration later, not a breaking one.
ALTER TABLE public.organizations
  ADD COLUMN compliance_mode text NOT NULL DEFAULT 'light_duty'
  CHECK (compliance_mode IN ('light_duty', 'regulated_cmv'));

COMMENT ON COLUMN public.organizations.compliance_mode IS
  'light_duty: phone-GPS fleet tracking (Phase 1-5 of the Fleet module). regulated_cmv: reserved for future FMCSA-certified ELD hardware integration, not yet built.';
