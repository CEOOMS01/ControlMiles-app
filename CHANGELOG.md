# Changelog

All notable changes to the ControlMiles mobile app are recorded here, newest
first. Every app change bumps `version` in `pubspec.yaml`
(`MAJOR.MINOR.PATCH+BUILD`; the build number must always go up for Google
Play) and adds an entry below.

This is the changelog of **ControlMiles** (`com.olimsys.controlmiles`), the
personal app. Until 2026-10-19 the same project also built ControlMiles
Fleet; Fleet is now its own project (`../controlmiles-fleet`) with its own
changelog. Fleet management and billing live on the web (controlmiles.com).
The shared Supabase backend stays here (`supabase/`).

## Backend — 2026-10-19 (no app release)

- Driving school students, phase 1 (used by ControlMiles Fleet and the web):
  migration `20261019120000_driving_school_students.sql` (applied),
  edge function `send-class-reminders` (new, not deployed), Enterprise tier
  in `create-checkout-session` and `stripe-webhook` (not deployed).

## 1.3.6+43 — 2026-10-19

### Changed (Fleet split into its own project)
- ControlMiles Fleet moved to `controlmilesproject/controlmiles-fleet`.
  This project builds only the personal app: no more `--flavor`
  (`flutter build appbundle --release`).
- Removed everything fleet-only: fleet owner and team screens, school
  runs, classes, invites and driver-ID sign-in, fleet roles and plan
  features, the invite deep link and `app_links`. Sign-in is email /
  Google; the app opens on sign-in -> permissions -> personal dashboard.
- Tests: `app_routes_initial_route_test.dart` replaces the flavor test;
  fleet-only tests moved with Fleet.

## 1.3.5+42 — 2026-10-19

### Changed (Fleet app: one way in)
- The Fleet app's sign-in asks once **"Admin"** or **"Team fleet"** and
  remembers it on the phone. Admin = the company's owner and admins (email
  or Google). Team fleet = everyone else -- drivers, operators, bus aides --
  with their user ID (CM-D####); a "?" explains it. The old "sign in with
  email / with your driver ID" toggle is gone.
- Asked again only when a team member is made an admin (at sign-in with
  their ID, or on the next app start when no trip is running). An admin
  moved back to the team just signs in as Team fleet.
- Operators now use the team side of the app (they were on the owner's
  screen).
- The app shows only what the fleet's service and plan include
  (`fn_org_features`): live map and fuel alerts on the owner's screen,
  safety score, own-vehicle registration, open vehicle pick, IFTA state on
  fuel receipts.
- "Bus monitor" -> "Bus aide"; "Driver ID" -> "User ID".
- New test `test/fleet_entry_prefs_test.dart`.

## 1.3.4+41 — 2026-10-18

### Fixed (product tour never showed)
- The product tour (welcome -> dashboard spotlights, and the "?" in History,
  Reports and Settings) never appeared on any phone since 1.3.0:
  `ProductTour.run` looked for targets with `key.currentContext`, which
  showcaseview 5.x never sets (it keeps the key only as a registry id), so
  every tour stopped with "no targets". It now asks
  `ShowcaseView.isTargetRendered`.
- New test `test/product_tour_test.dart`: the "?" replay puts the tour card
  on screen (fails on the old code).

## 1.3.3+40 — 2026-10-18

### Fixed (screens too big on testers' phones)
- Phones at the factory display size (360-412 dp wide; a Galaxy S23+ is
  384 dp) showed every screen ~25-30% too big: the layouts were tuned on a
  phone set to a smaller display size (~500 dp).
- The whole app now lays out on a canvas at least 480 dp wide and is scaled
  down to the screen (`ScreenFitScope`, `lib/theme/screen_fit.dart`): 0.80x
  on a 384 dp phone, never below 0.75x; tablets and wide phones unchanged.
  Done in the binding (`ScreenFitBinding`, a larger device pixel ratio), not
  with a Transform, so the product tour's coach marks, maps and touches stay
  aligned; dialogs, sheets and snackbars scale with everything else.
- The system font size is kept within 0.85x-1.3x; it used to grow every
  fixed-height card, button and carousel without a ceiling.
- The tour's welcome sheet scrolls instead of clipping on short screens.
- New test `test/screen_fit_layout_test.dart`: the scale per screen width,
  the text clamp, and sign-in / carousel / trip row without overflow at
  360x640, 384x832, 412x915 and the 480 dp canvas with text 1.0-2.0x.

## 1.3.2+39 — 2026-10-12

### Fixed (gig product tour review)
- The tour names the trip button as the app shows it in each language
  (`{start}` / `{end}` from the button's own texts): Spanish said
  "START / END" while the button reads "INICIAR / FIN", and the other 9
  languages fell back to English names.
- "Your miles" says the period the person chose (week, month or year)
  instead of always "this week".
- A single tip (History, first trip) ends with "Got it" ("Entendido"), not
  "Get started"; new `tour_got_it` in 11 languages.
- "Trip saved -- your first trip is in History" shows only on the real first
  trip; accounts that already had trips before the tour don't get it.
- Settings -> "App tour" during a trip now says to end the trip first (it
  used to do nothing).
- Spanish: Reports' date tip reads naturally.

## 1.3.1+38 — 2026-10-12

### Fixed (Gig / Fleet separation review)
- **Fleet app no longer asks for Usage Access**: the onboarding permission
  list and the one-time Usage Access prompt are gig-only (they power the
  gig-app auto-detect, which the Fleet app doesn't have).
- **Fleet app no longer declares gig-only permissions**:
  `PACKAGE_USAGE_STATS` (a sensitive permission in Play review) and
  `com.android.vending.BILLING` are removed in the fleet manifest; personal
  plans are sold in the gig app only and fleets pay on controlmiles.com.
- **Weekly summary notification is gig-only**: it opens the personal
  Reports, which the Fleet app doesn't use; the toggle is hidden there.

### Changed
- The Fleet app reports errors to CGC Core as `controlmiles-fleet`, and
  each app seals trips with its own CGC key (df382b8; backend applied).

## 1.3.0+37 — 2026-10-11

### Fixed
- Settings -> "App tour" pops back to the dashboard that's already open and
  plays the tour on top of it; on 1.3.0+36 the replaced dashboard
  unregistered the new tour scope and rendered blank. The old 4-card tour /
  "What's new" is gone from both apps (c16324b).

## 1.3.0+36 — 2026-10-10

### Added
- **Gig product tour** with spotlight coach marks (showcaseview): a welcome
  sheet once per account, 6 spotlights on the dashboard, first-visit tips on
  Reports, History and Settings with a "?" to replay, "App tour" in
  Settings; seen tours saved per account (user_onboarding.tour_seen)
  (66767cf).

### Changed
- Report header: ControlMiles logo, "ControlMiles Reports" and the app
  slogan (8e8cd01).
- **Fleet app branding**: its own launcher icon, "ControlMiles Fleet" sign-in
  with the "Keep control of your fleet." slogan; fleet drivers and bus
  monitors sign in with their driver ID, owners/admins with email
  (3f1e1cc, 4b49cc8, 1692f46).
- Sign-in footer "Powered by Olimsys Development"; the gig app's Fleet
  download link stays hidden until Fleet is on Google Play (82e37f2).

## 1.2.0+35 — 2026-10-10

### Changed
- **Two store apps from one codebase** (Android product flavors): **gig** =
  `com.olimsys.controlmiles` "ControlMiles" (personal trips, Google Play
  plans, auto-detect, IRS reports) and **fleet** =
  `com.olimsys.controlmiles.fleet` "ControlMiles Fleet" (fleet drivers, bus
  monitors and the owner's quick look; driver-ID login, no self sign-up, no
  Play plans). The mode comes from the flavor (and in Fleet, the member's
  role), not `profiles.account_type`. The `/invite` App Link moved to the
  Fleet app. Each app resumes only its own kind of open trip. Removed
  screens neither app reaches (role chooser, account type, create company,
  fleet roster, state mileage). Missing translations fall back to English
  (de8d9ff; backend applied).

### Fixed
- Live maps wait for the map style before adding annotations; GPS stream
  errors no longer crash (76252c8).

## 1.1.32+34 — 2026-10-09

### Fixed
- **History / Reports buttons hidden behind the navigation bar** on phones
  with the 3-button navigation bar (reported by the owner). Android 15+
  draws apps edge to edge; the fixed bottom bar now reserves exactly the
  system bar's height (`SafeArea(top: false)`), so the buttons stay fixed and
  sit above it. Gesture-navigation phones look the same as before.
- Dashboard Summary: the left column said "TOTAL MILES" but shows the
  current month (`_monthMiles`), so it didn't match the header's total; it
  now reads **"THIS MONTH"**.

### Changed
- Gig dashboard header: the miles moved to the right, level with the
  greeting (value in a serif, the period underneath), with a soft fading
  hairline between them; one compact band instead of two lines.

## 1.1.31+33 — 2026-10-09

### Changed
- **Warm, website-style look** (owner's request; competitor research:
  Gridwise and Samsara moved to warm off-white backgrounds, a warm near-black
  ink and one strong accent; the ControlMiles website already uses cream
  #FAF6EE, ink #211C14, blue #2C6C99, amber #BD5B26). New palette
  `lib/theme/cm_colors.dart`; the 435 hard-coded Tailwind "slate" colors in
  51 files were swapped 1:1 for warm equivalents (comments untouched).
  Global theme: cream background, white cards with sand borders, pill
  buttons, rounded dialogs/sheets, floating snack bars, warm charcoal dark
  mode.
- **Gig dashboard header**: the app's warm brown with a rounded bottom; the
  time-of-day greeting with a sun or moon icon and the user's name, and the
  miles of this week / month / year big in a serif. **Profile -> "Miles on
  the home header"** picks the period (saved on the device).
- **Card headers**: every card title ("ACTIVE ACTIVITY", "SUMMARY",
  "TRIP DETAILS", safety score, school routes, today's classes, live
  location...) is a solid brown strip with cream text (`CmCardHeader`) --
  they were faint gray labels. Settings and Profile section titles are
  brown with an amber underline.
- Dashboard: **RECENT TRIPS** moved into the Summary card header (left),
  with SUMMARY on the right; "See all" under the trip list. The tracking
  card has a **light blue** background; the **Start** button is bigger when
  idle so it stands out next to Premium auto-detect.
- Fleet driver, bus monitor and school run screens: brand-blue header with a
  rounded bottom.
- Side menu: cream background; the user ID tab sits flush on the bottom-left
  edge of the header (logo unchanged). The Language row left the menu list:
  a language button (flag + code) now sits in the header's bottom-right
  corner, mirroring the ID tab, and only opens the list of languages.
  Settings moved to the last place, under Profile.
- Dashboard: more space between the gig-app carousel and Recent trips.
- **History and Reports**: trip durations show seconds ("2h 17m 05s"),
  including the Reports summary, where the duration now sits beside the
  miles.
- **Vehicles**: only the selected car has a check mark (it used to show on
  the car that was NOT selected); its border and ACTIVE badge are blue
  instead of green. Tapping another car's card selects it; the chevron on
  each card (or tapping the selected car) opens the vehicle profile.

### Fixed
- Dark mode: History and Reports info chips (miles, times, durations), the
  trip icon and faint labels were almost invisible; Reports' blue is lighter
  in dark mode. Vehicle list icons readable in dark mode.

## 1.1.30+32 — 2026-10-09

### Added
- **First-run tour** (`lib/onboarding/app_tour.dart`): 4 short, always
  skippable cards with progress ("2 of 4") for the kind of account -- gig,
  fleet driver, fleet admin or bus monitor. Only NEW accounts (created in
  the last 14 days) see it, once per account on the device.
- **What's new**: every user-facing feature gets a `FeatureNote`; each note
  shows once (bottom sheet) to the accounts it applies to (school notes only
  in School transportation fleets). Settings -> **Tutorial & what's new**
  (gig/admin settings and the driver/monitor settings sheet) replays both.
- **Bus monitor home** (`MonitorHomeScreen`): a member with role `monitor`
  (invited only from the web, School transportation fleets) gets today's
  routes instead of the driver's trip screen; "Waiting for the driver to
  start" until the driver starts a route, then **Open route** to keep the
  student list. No trips, miles, Mark arrived or Finish route; no safety
  score in their settings.
- **Countdown at each stop**: after the bus arrives, the stop shows the
  5-minute grace time left ("4:12 to come out"); the screen refreshes when
  it ends (the server then decides red / absent).
- **Hands off while driving**: for the driver, the student list locks while
  the bus moves (over ~7 mph, from the GPS speed), with a banner; it
  unlocks when stopped. The monitor can always mark.

### Changed
- `AppState` loads the member role and the fleet type (`isMonitor`,
  `isSchoolFleet`); `SchoolRoute.myRole`, `SchoolStop.departedAt` /
  `graceLeft`. 54 new keys in 11 languages.
- Analyzer clean (0 issues): the odometer-cycle dialog uses `RadioGroup`
  instead of the deprecated `groupValue`/`onChanged` per tile; braces on a
  one-line `if` in `TrackingController.switchSection`.

## 1.1.29+31 — 2026-10-09

### Fixed
- **Finish route** dialog counts a PM student still "expected" (rode this
  morning, never boarded or resolved) as unresolved, matching the server.
  Found by the 5-stop route test; server side, starting a route now marks
  arrival at the stop the bus is already parked at (the PM school stop).

## 1.1.28+30 — 2026-10-09

### Changed
- **School day colors** (owner's rule + 4 adjustments), computed by the
  server for each student across the whole day:
  - **blue** = on track (picked up at home -> at school; picked up at
    school -> dropped at home);
  - **red** = rode the bus this morning but hasn't come out for the PM bus
    (the driver/monitor goes in and asks), or was not dropped off at their
    stop;
  - **yellow** = didn't ride this morning: not expected in the afternoon.
    Doesn't block -- the driver can still board them. A stop whose riders
    are all yellow/gray shows **"Skip · no one here today"** and isn't the
    next stop;
  - **gray** = a red resolved with **Resolve**: picked up by a parent,
    early dismissal, after-school activity, or other + note. Counts as
    attendance; **Undo** reverts it, and boarding the student (e.g. was in
    the bathroom) clears it.
- **Finish route** is blocked with a student still on board or an
  unresolved red; the dialog shows both counts.
- `SchoolRouteService.setRider` takes a release reason/note; 17 new keys in
  11 languages.

## 1.1.27+29 — 2026-10-09

### Added
- **School transportation (fleet drivers).** New fleet type `school_transport`
  (also in Create company). The fleet driver home shows today's school
  routes (`SchoolRoutesCard`); a route starts inside an open trip and opens
  `SchoolRunScreen`: stops in order with the next one highlighted, the
  students who get on/off at each stop (one tap each), manual "Mark
  arrived", and **Finish route** behind a mandatory "no child left on
  board" check (time and place recorded). Stop arrival is also marked by
  the server from the bus's live location (works with the phone locked) and
  by the screen every 15 s while open.
- **Attendance colors**: blue = picked up (counts as attendance) / dropped
  off; red = the bus reached the stop and the student wasn't marked
  (absent, or **not dropped off -- still on the bus?**). Not reached yet:
  neutral. Unmarked students on board are shown in the finish dialog.
- New service `SchoolRouteService`; 30 new keys in 11 languages
  (`school_*`, `fleet_profile_school*`).

## 1.1.26+28 — 2026-10-08

### Fixed
- **Sign-in screen said "Welcome back" to new users** (on first open and
  right after signing up). The header now depends on who is there:
  "Welcome back" only if someone has signed in on this phone before
  (new device flag set on every successful sign-in, `LoginPrefs`),
  "Check your email" right after a sign-up, and "Sign in" otherwise.
  New keys `login_sign_in_title`, `login_sign_in_sub`,
  `signup_confirm_title` in 11 languages.

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
