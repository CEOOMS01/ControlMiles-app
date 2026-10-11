-- Product tour (2026-10-11): which tour steps an account has already seen
-- (lib/onboarding/product_tour.dart, TourIds), so reinstalling the app or a
-- new phone doesn't replay them. Covered by the existing owner-only
-- user_onboarding RLS policies (select/insert/update/delete own row).

alter table public.user_onboarding
  add column if not exists tour_seen text[] not null default '{}';
