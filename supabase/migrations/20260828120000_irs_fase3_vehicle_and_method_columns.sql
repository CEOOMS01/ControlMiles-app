-- Olympus Mont Systems LLC - ControlMiles
-- IRS Fase 3 (2026-08-28): two of the IRS-recommended annual-summary
-- fields that ControlMiles didn't capture at all -- when the vehicle was
-- first placed in business service, and which deduction method the
-- driver is actually using. Both nullable/additive, no backfill needed.

ALTER TABLE public.vehicles
  ADD COLUMN IF NOT EXISTS placed_in_service_date date;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS mileage_method text DEFAULT 'standard'
    CHECK (mileage_method IN ('standard', 'actual'));
