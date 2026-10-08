# Changelog

All notable changes to the ControlMiles mobile app are recorded here, newest
first. Every app change bumps `version` in `pubspec.yaml`
(`MAJOR.MINOR.PATCH+BUILD`; the build number must always go up for Google
Play) and adds an entry below.

Fleet features and fleet billing live on the web (controlmiles.com, Stripe):
changes there are not app releases and are not recorded here.

## 1.1.25+27 — 2026-10-08

### Fixed
- **Sign-up showed "Authentication error"** although the account was
  created and the confirmation email sent (found live with a closed-testing
  account). With email confirmation on, `signUp` returns no session and the
  post-auth step treated that as a failure. The app now switches to the
  sign-in form (email kept, password cleared) with "Account created. Confirm
  your email, then sign in here." (new key `signup_check_email`, 11
  languages).

## 1.1.24+26 — 2026-10-07

### Fixed
- **Subscription screen with the Play free-trial offers.** Play Console now
  has `controlmiles_basic_monthly` ($5.99) and `controlmiles_premium_monthly`
  ($9.99), base plan `monthly`, each with offer `free-trial-15d` (15 days
  free, new subscribers who never had any ControlMiles subscription). Play
  returns the trial offer and the base plan as separate entries in no fixed
  order: the app could buy the base plan (no trial), and the trial entry's
  price is its first phase, so the card would read "Free/mo". The app now
  buys the trial offer when the user is eligible and always shows the
  monthly price after the trial.

## 1.1.23+25 — 2026-10-06

### Changed
- Removed the `RECORD_AUDIO` permission that the camera plugin merged into
  the manifest. The app only takes photos (`enableAudio: false`), and the
  Play Data safety form declares no audio collected; Play Console flagged it
  as an undeclared sensitive permission on the first closed-testing release.

## 1.1.22+24 — 2026-10-05

### Fixed
- **PDF odometer numbers contradicted each other.** The vehicle line said
  "Starting odometer: 209,354" while ODOMETER EVIDENCE started at 206,637:
  it showed the vehicle's `odometer` column, which is updated with every
  reading (the CURRENT odometer). It now shows the first reading ever
  captured in ControlMiles, with its date, and the current one, each
  labeled. ODOMETER EVIDENCE's third box showed the tracked trip miles as
  "TOTAL units"; it now shows **ODOMETER MILES** (END - START, in mi);
  tracked miles stay in the Total Miles and business-use summaries.

### Changed
- Subscription screen: Basic and Premium both say "Includes a 15-day free
  trial" (Premium said 5 days), in all 11 languages. The 15-day trial
  offers must be set on both base plans in Play Console.

## 1.1.21+23 — 2026-10-05

### Fixed
- **Reports and the PDF listed legacy 0.00 mi trips** (from before the
  no-miles-no-trip rule), with empty route maps. Trips under 0.05 mi are now
  left out of the Reports list, the trip count, the totals and the PDF --
  the same filter the web Report Portal already applies.

## 1.1.20+22 — 2026-10-04

### Fixed
- **PDF report showed Business-use over 100%** (102.8%, and a business-use
  total of 1621.63 mi against a report total of 1578.02 mi). The report
  total used each trip's stored miles while the business-use summary added
  its gig-app segments, and some legacy trips had stored only their last
  segment's miles (the background-checkpoint bug fixed in 1.1.16) or 0. A
  trip's miles are now the sum of its segments everywhere in the PDF
  (totals, deduction, trip log, route pages); the percentage is clamped to
  100%.
- End Trip now saves the trip's miles as the sum of its segments.
- Backend (live): the database sets a trip's miles to the sum of its
  segments when it closes (`trg_session_miles_from_sections`), whatever
  app version closed it; the 6 inconsistent stored trips were repaired.

## 1.1.19+21 — 2026-10-04

### Added
- **Reports screen: "Route map" button on each trip.** Shows the trip's map
  (every gig app in its color, names in the legend) and, when the trip
  tracked more than one gig app, one map per gig app (two per row; segments
  with no miles get none). Loaded only when tapped. `flutter_svg` is back
  for this screen (History still shows no maps).

### Fixed
- PDF **Trip routes**: a trip's title could stay at the bottom of one page
  while its map moved to the next. Title and map are now one unbreakable
  block (`pw.Stack`).

## 1.1.18+20 — 2026-10-04

### Changed
- **Route maps live only in reports** (user rule), not in History. The PDF
  report (Reports → Generate) gets **Trip routes** pages: each trip's map
  and, when the trip tracked more than one gig app, one map per gig app
  (two per row; a segment with no miles gets none). Images come from
  controlmiles.com/api/trip-map, 6 downloads at a time, capped at 60 per
  report (newest trips first; a note counts the rest). Own `MultiPage`, so
  the main report's page limit is untouched.
- History no longer shows the route image added in 1.1.17; `flutter_svg`
  removed (the PDF uses the `pdf` package's own SVG support).

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
