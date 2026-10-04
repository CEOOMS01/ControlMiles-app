# Changelog

All notable changes to the ControlMiles mobile app are recorded here, newest
first. Every app change bumps `version` in `pubspec.yaml`
(`MAJOR.MINOR.PATCH+BUILD`; the build number must always go up for Google
Play) and adds an entry below.

Fleet features and fleet billing live on the web (controlmiles.com, Stripe):
changes there are not app releases and are not recorded here.

## 1.1.17+19 — 2026-10-04

### Added
- **Trip route drawing.** New `RouteRecorder` (`lib/tracking/route_recorder.dart`)
  keeps each gig-app segment's validated GPS path in an append-only file on
  the phone (survives Android killing the app; shared by the UI and
  headless isolates). When the segment closes (switch or End Trip) it is
  simplified (Douglas-Peucker, 6 m, max 800 points), encoded as a Google
  polyline and uploaded once to `session_sections.route_polyline`
  (~0.5-2 KB per trip). Failed uploads stay on the phone and are retried on
  the next start. A discarded trip's route is deleted.
- **History:** expanding a closed trip shows its route image (streets +
  route, one color per gig app) from controlmiles.com. New dependency
  `flutter_svg`.

### Changed
- Gig trips send a GPS breadcrumb every 5 minutes instead of every minute
  (the route now comes from the polyline; the breadcrumb only feeds the
  12-hour abandoned-trip check). Fleet trips keep 1 per minute for IFTA,
  idle time and fuel checks.

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
- **Create company** has no preselected fleet type and asks the owner to
  confirm it (the type is locked server-side after creation). Error
  messages 423 `FLEET_TYPE_LOCKED` and 424 `FLEET_TYPE_OWNER_ONLY` added in
  all 11 languages. (`46ec394`)
- Removed unused, contradictory plan helpers from `app_config.dart` (a "PRO"
  tier and session limits that never existed). (`303bd3d`)
