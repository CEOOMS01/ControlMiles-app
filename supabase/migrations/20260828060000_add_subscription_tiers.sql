-- Olympus Mont Systems LLC - ControlMiles
-- Two real paid tiers, not one: Base ($5.99, core app usage --
-- enforcement not built yet, this is prep only) and Premium ($9.99,
-- adds Automatic Detection on top of everything Base has). See
-- [[project_controlmiles]].
--
-- subscriptions.tier is a snapshot written by stripe-webhook from the
-- Checkout Session's own subscription_data.metadata.tier, not derived
-- by reverse-mapping price_id -> tier at read time (avoids drift if
-- Stripe price ids ever change).

ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS tier text;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS base_entitled boolean NOT NULL DEFAULT false;
