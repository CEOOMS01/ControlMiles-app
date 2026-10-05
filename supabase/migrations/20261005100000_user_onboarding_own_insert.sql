-- user_onboarding: let each user insert their OWN row (2026-10-05).
--
-- The app saves its onboarding flags (welcome_seen, account_type_chosen)
-- with an upsert (app_state.dart completeAccountTypeChoice, welcome_page.dart
-- _markWelcomeSeen). Postgres checks the INSERT policy for an upsert even when
-- the row already exists, and onboarding_insert_blocked was `with check
-- (false)`, so every save failed with 42501 ("new row violates row-level
-- security policy") -- the account-type chooser kept coming back. The flags
-- are UX-only and the row is keyed by user_id, so a user can only ever
-- create/update their own row. Fixes every installed app version at once.

drop policy if exists onboarding_insert_blocked on public.user_onboarding;
drop policy if exists onboarding_insert_own on public.user_onboarding;
create policy onboarding_insert_own on public.user_onboarding
  for insert to authenticated
  with check (user_id = auth.uid());
