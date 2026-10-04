# Changelog

All notable changes to the ControlMiles app (and the Supabase backend in
`supabase/`) are recorded here, newest first. Every app change bumps
`version` in `pubspec.yaml` (`MAJOR.MINOR.PATCH+BUILD`; the build number must
always go up for Google Play) and adds an entry below.

## 1.1.16+18 — 2026-10-03

### Fixed
- **Trip timer reset when the app went to the background.** A trip of
  15.7 mi (about 2 h) was saved with a 7-second duration. `AppLifecycleObserver`
  wrote its own trip checkpoint without the running segment's start time,
  which erased the saved start; every later recovery restarted the clock
  from "now". Swiping the app away also saved the trip as *paused*. Both
  paths now call `TrackingController.saveCheckpoint()` (confirmed duration +
  segment start + real running/paused state). (`dfb3bd2`)
- **Google Play upgrade could double-charge.** After an app restart, a Basic
  subscriber tapping Premium bought a second subscription instead of
  upgrading. The owned subscription is now loaded from Play on start and on
  the Subscription screen, and any purchase the server never confirmed is
  verified before Google auto-refunds it. (`303bd3d`)
- **Create company screen** overflowed on small phones (8 fleet types, no
  scroll). It now scrolls. (`46ec394`)
- **Started (free) trial message** said 30 days; the real trial is 15 days.
  Fixed in all 11 languages. (`46ec394`)

### Changed
- **Fleet type is chosen once and locked.** Create company has no
  preselected type and asks for confirmation; after that only support can
  change it (`support_change_fleet_type`). New errors 423
  `FLEET_TYPE_LOCKED` and 424 `FLEET_TYPE_OWNER_ONLY`. (`46ec394`)
- **Fleet free trial is 15 days** (was 5). (`46ec394`)
- Removed unused, contradictory plan helpers from `app_config.dart` (a "PRO"
  tier and session limits that never existed). (`303bd3d`)

### Backend (already live in Supabase)
- Org billing columns, `tier_enforcement_exempt`, `industry_template` and
  `fleet_type_confirmed_at` can no longer be written directly by clients
  (an org admin could give the fleet free Growth). Reports can only be created
  by `generate_report_access_code` (users could forge a "verified" report).
  Fleet-wide export is gated to Growth server-side; `past_due` keeps the plan
  during Stripe retries; anonymous write grants revoked.
- Stripe: `stripe-webhook` re-reads each subscription from Stripe, retries on
  failure instead of dropping the event, never switches off a Google Play
  plan, takes the fleet tier from the price, and syncs seats (vehicle count)
  before each renewal. `create-checkout-session` is fleet-only and computes
  seats server-side; checkout/portal return to `/admin/settings`.
- New table `fleet_type_changes` (who set or changed a fleet's type, and why).
