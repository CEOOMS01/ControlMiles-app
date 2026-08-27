-- Olympus Mont Systems LLC - ControlMiles
-- Real Stripe subscriptions for ControlMiles Premium (see [[project_controlmiles]]).
-- profiles.premium_entitled has always been enforcement-only, flipped
-- manually -- this is the durable, real backing for it: `subscriptions`
-- is the current-state record a webhook keeps in sync, `subscription_events`
-- is the append-only audit log + idempotency guard (Stripe redelivers
-- events, so stripe_event_id UNIQUE makes a duplicate delivery a no-op
-- instead of double-processing).

CREATE TABLE IF NOT EXISTS public.subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  stripe_customer_id text,
  stripe_subscription_id text UNIQUE,
  status text NOT NULL DEFAULT 'incomplete',
  price_id text,
  current_period_end timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON public.subscriptions(user_id);

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS subscriptions_select_own ON public.subscriptions;
CREATE POLICY subscriptions_select_own ON public.subscriptions
  FOR SELECT USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.subscription_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stripe_event_id text NOT NULL UNIQUE,
  event_type text NOT NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.subscription_events ENABLE ROW LEVEL SECURITY;
-- Deliberately no policies -- service_role bypasses RLS by default, and
-- this table has nothing an ordinary authenticated user should ever read
-- directly (raw Stripe event payloads).
