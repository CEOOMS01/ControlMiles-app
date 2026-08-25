-- Fleet Phase 1: tracks whether this user has been shown (and completed) the
-- "ControlMiles Gig" vs "ControlMiles Fleet" choice, once, after the existing
-- permissions/welcome onboarding step. profiles.account_type already
-- defaults to 'gig' on signup (handle_new_user trigger) -- this flag is
-- separate from that value because 'gig' is also the correct default before
-- the user has ever been asked, so account_type alone can't distinguish
-- "chose Gig" from "hasn't chosen yet".
ALTER TABLE public.user_onboarding
  ADD COLUMN account_type_chosen boolean NOT NULL DEFAULT false;
