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

## Backend — 2026-10-20 (no app release)

- Driving school phase 2 (used by ControlMiles Fleet and the web):
  migration `20261019150000_driving_school_phase2.sql` (applied): programs,
  instructor availability and time off, portal booking and cancellation,
  package balance, state certificate fields, SMS consent, freed-time
  notices. `send-class-reminders` now also emails freed times (deployed).
- Driving school cars use the monthly odometer cycle, existing and new
  (migration `20261020100000_driving_school_monthly_odometer.sql`, applied).

## Backend — 2026-10-19 (no app release)

- Driving school students, phase 1 (used by ControlMiles Fleet and the web):
  migration `20261019120000_driving_school_students.sql` (applied),
  edge function `send-class-reminders` (new) with the hourly cron
  `class-reminders-hourly` (migration `20261019130000_class_reminders_cron.sql`),
  Enterprise tier in `create-checkout-session` and `stripe-webhook`, and
  `send-fuel-alerts` skipping fleets without fuel alerts -- all deployed.

## 1.3.29+69 — 2026-11-09

- New notification icon: the pin with a steering wheel on a full disc, filling the whole icon space. It replaces the old
  one everywhere (`ic_stat_tracking`, all five densities).
- When Android refuses the drive check in the background the app no longer closes (two crashes seen 2026-11-09 at
  5:59); the refusal goes to the diagnostic log. That one drive check is still lost.
- A trip closing while the app opens no longer leaves the GPS and its notice on: the recoveries share one run and do
  not restart the GPS during a close.

## 1.3.28+68 — 2026-11-09

- A trip now closes after 5 minutes without movement (it was 10), still ending when the car stopped. The automatic
  restart wait after such a close counts from when the car stopped, so the next drive keeps its first minutes.
- Only 2.5 m/s or faster (or a jump of 25 m) now counts as movement for that clock; GPS noise at 1.5 m/s while parked
  kept restarting it.

## 1.3.27/2 — 2026-11-09 (built, not uploaded; included in 1.3.28+68)

- My Trips shows each trip's whole route: the map keeps its own shape instead of a short band that cut off the top
  and bottom. New start (blue arrow) and arrival (gold) icons replace the green and red ones on the trip card; the
  maps themselves are drawn by the website (controlmiles-web, `src/lib/trip-map/markers.ts`).

## 1.3.27/1 — 2026-11-09 (built, not uploaded; included in 1.3.28+68)

- Reports: "Generate report" now asks PDF or CSV. The CSV (Excel, Google Sheets) has one line per segment, oldest
  first, with date, times, category, app, addresses, miles, rate, value, vehicle, odometer and notes. It reads the
  same rows as the PDF, and counts toward the same monthly export limit on Basic. New package: share_plus.
- Gig segments closed by an app switch now get their start and end addresses, and old ones fill in when the app opens.

## 1.3.27+67 — 2026-11-07 (built, for Play)

- One Flutter engine (Android), modelled on MileIQ's single drive service: the screen and the trips share the app's
  only engine (SharedEngine). DriveWakeService starts it with the app closed and keeps it while a trip or a drive
  check needs it; opening the app attaches the screen to it. The message channel between two engines (trip_link.dart)
  is gone, and Tracelet's headless engine only restarts the service.

## 1.3.26+66 — 2026-11-07 (built, for Play)

- The GPS no longer switches itself off during a trip after 5 minutes parked. That stop never undid itself, so trips
  lost most of their miles (2026-11-07: about 53 of 111 miles, measured against another tracker on the same phone).
- A trip the phone starts with the app closed stays alive until it ends, instead of losing its GPS seconds later.
- A trip still for 10 minutes ends by itself, at the moment the car stopped, with a notice. No question first, on every
  plan. A trip left open (app closed, or forced to stop) is closed the same way when the app opens.
- Diagnostic log: no more cut lines, and one upload per tap.
- One trip engine (Android): a single background engine owns every trip -- GPS, start, gig-app switch, pause, end and
  the 10-minute close. The open app only sends commands and shows what the engine reports, and Tracelet's headless
  engine only wakes it. Before, up to three engines held their own copy of the same trip.
- Removed dead code: the 30-second gig-app poll, the catalog pre-warm and the headless engine's own trip recording.
- Basic: with no signal, the phone's last known plan decides; automatic trips stay Premium only.

## 1.3.25+65 — 2026-11-07 (built, for Play)

- Odometer: two photos a year is the rule on every plan. Premium can choose weekly or monthly in the vehicle's odometer
  cycle; twice a month is gone. Losing Premium returns the vehicle to two photos a year.
- A General trip the phone closes asks its category on the Dashboard right away, also when the trip was picked up after
  the app restarted.
- Automatic start in General mode now checks that the car is really moving before it starts a trip. Android's "in a
  vehicle" signal also fires while you sit in a parked car, which started empty trips (five in ten minutes on
  2026-11-07, and "you can't change vehicle while a trip is in progress" with no trip). The vehicle and the
  parking-fence wake-ups both wait for real driving speed; only one check runs at a time.
- Gig apps: the automatic switch now also works with the app closed (it follows the GPS, not a timer in the open app),
  and only ever reacts to the apps the driver selected from the integrated list; with none selected nothing starts.
- Gig apps: a trip still starts when the selected app is behind Maps or a call, for up to 15 minutes after leaving it.
- A wake-up that found no trip of its own no longer turns off the GPS of a trip another engine started, and an engine
  that loses the race to start a trip joins the real one instead of stopping it.
- A trip left open with no running segment is closed at the next start, so it can no longer block new trips.
- Automatic trips check the account's plan in the database, so a lapsed Premium turns detection off even if the app
  stayed closed. Opening the app also re-checks an owned subscription, in case Google's renewal notice was lost.
- A trip under 1 mile is not saved, in General and Apps mode. Needs the database rule applied first.
- On a gig trip only the address where the trip ended can be corrected; miles are never edited and trips can still be
  deleted. Dead `history_screen.dart` and
  `trip_address_editor.dart` removed (My Trips replaced them).

## 1.3.24+64 — 2026-11-06 (built, for Play)

- My Trips: the three filter buttons (No category, All trips, Summary) are centered and stay pinned at the top while the
  trips scroll, like the buttons in Reports (shared PinnedBar widget).
- PDF report: one row per segment (a trip that switched gig app shows each segment with its own addresses, miles, category and value). The odometer reading appears only on the first row (start) and the last row (end), not on every trip. The closing notes no longer spill onto a page of their own.
- My Trips: a trip that switched gig app now shows one card per segment, each with its own times, addresses, miles,
  category, value and route map. Deleting a segment card removes only that segment (new database function
  delete_trip_section keeps the trip totals in line; the whole trip goes when its last segment goes).

## 1.3.23+63 — 2026-11-06 (built, for Play)

(1.3.22+62 was already published on Play when this was built; the list below covers the 1.3.22 work plus what came after it.)

- Notifications cut to four: the trip-recording notice, "Checking your drive...", "Did you finish your trip?" and
  "Trip finished". Removed: forgotten-trip and pause reminders, the paused notice, the weekly summary, work-hours
  and work-place reminders (and the work places feature), GPS alerts, auto-start / app-switch / failed notices,
  the categorize-your-trip notice, the per-type switches in Settings and the exact-alarm permission. Alarms and
  channels from older versions are cancelled on first start.
- The trip notification is now fixed and minimal ("ControlMiles is recording your trip"): no live miles, no
  ticking timer, and the Android 16 Live Update promotion is removed. Opening the app no longer flashes
  the tracking notification (the engine is only stopped when it is really running).
- The version number no longer shows a leading "v" (Settings and the menu).
- Reports: the three buttons (This month, Total trips, Generate report) stay pinned at the top while the trips scroll.
- PDF report redone in landscape (A4), in the style of the reports drivers already know: header with
  date range and business rate on every page, summary tiles (estimated deduction, business and
  non-business miles, business use, distance, drives), a per-vehicle table (miles by category and
  estimated deduction), and the trip log with category, app, full start and end addresses, rate,
  value and odometer start/end per trip, page numbers and report totals. No maps and no photos in
  the PDF any more (they stay in the app and on controlmiles.com), so it is made much faster.
- PDF report: the deduction estimate now follows each trip's category (Personal/Work/Education add
  nothing, Medical and Moving use 20.5c/23.5c, Charitable 14c, business-group trips the business
  rate), the same way My Trips prices it. Before, every mile was priced at the business rate.
- Reports: the big red PDF button is now a row of three: This month, Total trips (whole history, from
  the first trip) and Generate report. The first two set the date range; the report uses the range
  shown. Trips are read in pages of 500 so long histories are not cut off.
- Dashboard: the day-by-day "Recent trips" list is gone; only the Summary card stays (one less query on
  every open). My Trips now loads the whole history (not just a year) and the month picker is an
  agenda icon that expands into a year + months grid; months without trips are dimmed.
- Languages cut from 11 to 5: English, Spanish, French, Chinese and Hindi. Portuguese,
  Arabic, Japanese, Korean, German and Amharic are out of the app (files kept in
  reference/i18n_removed_2026-11-06/); a driver whose saved language was one of them
  opens in English. The 258 texts that French, Chinese and Hindi were missing are now
  translated, so all five languages are complete.
- History is now "My Trips" ('Mis viajes'): the old list is replaced by the new trips list
  (month summary, tabs No category / All / Summary, one card per trip), where a closed
  trip can be categorized or re-categorized, its addresses fixed and a note added.
  Reports and the PDF do not change (the PDF already shows each trip's start and end
  address). The old history tour tip is not on the new list yet.
- Trip pop-up: when a trip ends (End trip, or the phone closed it) the pop-up over the
  Dashboard is now the trip card -- map, start and end addresses, what it is worth and
  the category as tap targets (Business, Personal, Medical, Charity, More) with Address
  and Note buttons. Picking a category saves it and the pop-up goes away; closing it
  ("Categorize later") changes nothing and the trip stays editable (category, addresses,
  note) later, also after it was categorized. Same card for a new trips list
  (lib/screens/trips_screen.dart: month summary, tabs No category / All / Summary), which
  is written but not wired to a screen yet; History is unchanged.
- Found in the 11:00-11:46 test (Samsung, 1.3.21): trips recorded about 25% of the
  miles MileIQ did, one automatic start created two trips at once (one left open
  for good), and a General trip was split by Roadie being open.
- General mode no longer switches section by app during a trip (that belongs to
  Apps mode).
- Every automatic start now checks, just before it begins, that no trip is already
  open (another isolate may have started it a second ago).
- Diagnostic log: every isolate (app, wake engine, background engine) appends short
  lines (wake source, each GPS fix with rounded coordinates, ticks rejected, miles
  added, trip start and stop). Settings has "Send diagnostic log" to upload it
  (`diagnostic_logs`, backend migration 20261106120000). Meant to find why miles are
  lost with the app closed.

## 1.3.21+61 — 2026-11-06 (built, not uploaded)

- Smarter drive detection, not tied to one Android signal. Besides Android's "entered
  a vehicle", the app now keeps a small fence (150 m) around where the phone was last
  parked and wakes when the phone leaves it (also with the app closed, no GPS or
  notification while it waits). A fence exit is only a hint, so it is checked with a
  light GPS burst of up to 2.5 minutes before it counts as a trip; if it was a walk,
  a bus or a taxi, the GPS goes back to sleep and the fence moves. The fence moves to
  the parking spot after every trip (and when Android says the driver left the
  vehicle) and is put back after a reboot or update.
- The parking spot is also the real start of the trip: the start point is saved
  there and the straight-line miles from it to the first GPS point (30 m to 2.5 km)
  are counted, so the first stretch before detection is no longer lost.
- A simulated (mock) position can never become the parking spot: the fence ignores
  positions Android flags as mock. Mock fixes were already rejected for recording and
  for starting a trip.
- Apps mode with no apps picked starts nothing; an abandoned open session older than
  24 h no longer blocks automatic trips.
- Not done: iOS (it keeps the previous engine).

## 1.3.20+60 — 2026-11-06 (uploaded)

- Permissions page: new step "Alarms and reminders" (Android 12+, skippable) so exact
  alarms are asked there, with an explanation; the notification service no longer
  opens Android's notification and alarm dialogs by itself at start-up (they came up
  over the start-up screen). The "Physical activity" step now explains that it is
  what lets trips start by themselves and the app sleep between drives. The camera
  stays out of the first-time steps: it is asked when the first odometer photo of a
  cycle is needed.
- "Ready to track" card (Premium): the line under it says "You don't need to do
  anything. ControlMiles tracks automatically." instead of "Pick your activity and
  start your trip" (Basic keeps the old line); the "ControlMiles is ready" status card
  keeps "Recording starts when you drive."
- One start-up screen: the Android launch screen shows the ControlMiles circle logo at
  192 dp, centered, and the app's own screen draws the very same logo in the very same
  place and adds the small steering wheel spinning under it, then goes straight to
  the Dashboard without a slide. The tagline text under the wheel is gone.
- Faster cold start: the app now draws its first screen right away. The GPS engine,
  notifications, detection re-arm and work places start just after the first frame
  (they used to run before it), the plan and account data are read from the phone
  instead of waiting for two server calls, the date names load in parallel, the
  start-up screen stays 0.4 s instead of 0.9 s, and the Dashboard's first loads run
  together instead of one after the other. Measured on a Motorola (profile build):
  Dashboard ready in about 1.4 s after launch (the same step took 5-7 s in a debug
  build before the change).
- Sleeping detection (Android): while nothing is happening the app holds no GPS
  and no notification. It subscribes to Android Activity Recognition (IN_VEHICLE
  enter/exit, from the phone's own sensors); entering a vehicle wakes the app, also
  when it is closed, through a short-lived service that starts the trip. Only then
  the tracking service and its notification appear. New local plugin
  `packages/cm_drive_wake` (receiver, wake service, boot/update re-registration) and
  `lib/tracking/drive_wake.dart`. Also fixes the listening gap after the first trip
  (the old engine stopped with the trip and never listened again). iOS keeps the
  previous behavior.
  The 30-second health check and the "stationary" restart no longer bring the idle
  tracking service (and its notification) back on Android.
- Automatic detection has no button any more. Premium accounts keep it on, asleep,
  and it wakes when the phone moves (General: any drive; Apps: after opening one
  of the driver's apps). Ending a trip never turns it off; only the switch in
  Settings does (`controlmiles_auto_detect_off_by_user`). The Dashboard arms it by
  itself when location, the app-detection permission (Apps mode only) and this
  cycle's odometer photo are in place. General mode no longer asks for the
  app-detection permission. The carousel stays visible while detection is on.
- Dashboard (Premium only; Basic is unchanged): a General / Gig apps switch above
  the carousel (and "Edit apps" in Gig apps mode) lets the driver change how
  they work and which apps count without opening Settings; detection follows the
  choice. The "Automatic tracking hours" row in Settings is Premium only too.
- General mode notification: while waiting it says "ControlMiles is ready"; only
  a drive the phone detected says "Your drives are recorded automatically" (with
  the distance). (Android needs some notification while the background service
  runs, so the idle one stays, just neutral.)
- The category question is asked on the Dashboard first, for any trip the phone or
  the driver closes (End trip, or the phone closing it after no answer), in every
  work mode; the notification only covers a trip closed while the app is shut.
- Parked GPS jitter no longer adds miles: with speed near zero, a step inside the
  accuracy radius (up to 10 m) is ignored (a stationary test showed 0.02 mi in
  12 minutes).
- Tracking card shows GENERAL instead of CUSTOM; the waiting-status card is hidden
  during a trip.
- Premium, General mode, waiting: the status card "ControlMiles is ready" says "You don't need to do anything. ControlMiles tracks automatically."; the "Ready to track" card keeps its title with an empty line below.
- Background-service card moved to a new quiet channel (low importance): no sound or
  pop-up each time the app opens (the old channel had default importance).
- Fixes the 58 report "it did not track by itself": Finalizar viaje had turned
  detection off.

## 1.3.18+58 — 2026-11-05 (uploaded)

- General mode, End trip: the app asks the trip's category right away, with
  "Edit address" and "Categorize later". History shows a banner "N trips need a
  category" that walks through all of them.
- Settings → "Automatic tracking hours" (General mode): the driver can pick the
  days and hours when the phone may start trips by itself. Nothing chosen =
  tracks whenever there is movement. A running trip is never cut off; gig-app
  mode ignores it. Stored per account (`controlmiles_auto_schedule`).
- "Don't see your app? Suggest it" at the end of both gig-app pickers; names go
  to `gig_app_suggestions` (backend, applied 2026-11-05).

## 1.3.17+57 — 2026-11-05 (uploaded)

- **Update notice**: the app asks the server (`app_versions`, row `gig`) for the
  newest and the minimum build. Older than newest → "New version available"
  once per build; older than minimum → required update. Only versions that
  already contain this code can show it (56 and older cannot).
- Unused `logo_olympus.png` removed.
- General mode: the always-on notification and the Dashboard card say
  "ControlMiles is tracking" instead of "listening for a gig app". Gig mode keeps
  its text.

- **"How do you work?" for everyone**: Premium accounts now answer it too (and
  can change it in Settings). "Apps" shows only the apps they pick plus
  General; "General" shows only General.
- **General trips start by themselves**: in General mode, two GPS fixes at
  driving speed (about 10 mph) start a trip, whatever app is open; a trip that
  just ended waits 5 minutes before another can start. In Apps mode only the
  apps the driver marked start a trip, as before.
- **"What was this trip for?"**: asked only for General trips, after they end
  (notification + sheet on the dashboard; "Later" skips it). Gig-app trips stay
  Business.
- **Apps mode starts only when the driver moves**: opening a gig app is no
  longer enough; the trip starts when the driver then drives (one fix at ~15
  mph or two at ~10 mph) and the last app opened is one they marked.
- **Works with the app closed**: the GPS callback that Android runs while the
  app is closed (headless isolate) now starts these trips too. For that, the
  Usage Access detection moved from `MainActivity` to the local plugin
  `packages/cm_usage_access` (registered in every engine), and Supabase is
  initialised there through `SupabaseBootstrap` (also used by `main()`).
  A trip can start without a screen; it needs one only to ask for an
  odometer photo, and then it does not start. NOT yet verified on a phone.
- **The purpose of a closed trip can be changed** (History: tap the purpose of a
  General trip). Migrations `20261105120000` (editable purpose after close).
- Inactivity rules (5 min ask, 5 more min close) already applied to both modes
  for Premium; unchanged.
- **Rates screen** (Settings → Rates): the IRS rate per mile by purpose
  (Business, Medical, Charitable, Moving, Personal) for today's date.
  `ratePerMileCentsForPurpose` in `lib/data/irs_rates.dart`; the dollar
  estimates in reports still use the business rate.

## 1.3.16+56 — 2026-11-04 (uploaded)

- Fix: "I cannot track" when the phone's permissions are gone (found on a real
  phone: every permission denied, the Start button did nothing). Start now asks
  for location first, with the same explanation page as the first launch, and
  says what to change if it is denied or only approximate. After a reinstall or
  an Android reset, an account that already saw the welcome no longer skips the
  permissions: it gets the short steps (location, all the time, notifications)
  and no terms sentence. The 1.3.14 fix that skipped them is corrected.
- Fix: a double start. On a real phone two trips were created 0.9 s apart and the
  second wiped the first one's state, leaving a trip open on the server. Only one
  start runs at a time now (in the Start button and in the trip controller).
- Every place that needs location now asks first with the explanation page
  (Start, turning on automatic detection, adding a work place) through one
  shared PermissionGate, and points to Settings only if that is not enough.
- Where a trip started and ended: street addresses ("219 Allendale St,
  Baltimore, MD"), looked up on the phone once when the trip closes and again
  for recent trips that missed it. Shown in History (tap to correct them, the
  recorded coordinates and miles never change) and in the PDF trip log as a new
  "From / To" column. The start and end points themselves are now always
  saved: the first valid fix of a section sets the start, and the end falls back
  to the last valid fix any isolate saved (about 1 trip in 5 had none).
  History also gets "Route map" on each trip (the same image the PDF uses,
  loaded only when tapped). The privacy policy says the addresses are saved.
  Needs migration `20261104220000_section_addresses` (applied).
- The accountant portal's trip log also shows From / To (migration
  `20261104230000_report_portal_trip_addresses`, applied; website change in the
  web repo, to be deployed).
- Lighter route maps: the PDF, the Reports preview and History ask for the map
  with `?lite=1` (no tiny roads or patches, coarser lines, only the roads that
  matter at that scale). A long trip goes from about 280 KB to 47 KB, a short one
  from 33 KB to 18 KB, and the picture stays clear. Needs the website deployed;
  until then the full image comes back and everything still works.
- "Started" is gone: there are two plans, Basic and Premium. The automatic
  15-day free trial stays, but it is not a plan any more -- the Subscription
  screen shows it as one line ("Free trial: N days left") above the two plans.
- New "How do you work?" screen for Started / Basic accounts, asked once: with
  apps (pick which ones; only those show in the carousel, next to General, and
  the trip is saved as Business) or with general trips (only General shows).
  "Show me everything" keeps all buttons. Changeable in Settings > How I work.
  Premium keeps its shift selector and always sees every button it chose.
- A personal trip that stops moving: after 5 minutes without movement Started /
  Basic pauses it; Premium asks "Did you end your trip?" with Keep going / End
  trip, and closes it for good after 5 more minutes without an answer. Moving
  again cancels the question. Fleet trips are untouched.
- Odometer cycle by plan: annual (two photos a year, the default) is for every
  account; monthly and every-15-days are Premium and optional. Vehicles already
  on a monthly cycle keep it until the driver changes it. Needs migration
  `20261104200000_odometer_cycle_tiers` (applied).

## 1.3.15+55 — 2026-11-04

- Fix: on the Vehicle page the Model field overflowed its box by 8 px on narrow
  phones ("Choose a make first" did not fit). The model, make and maintenance
  vehicle pickers now fill their column and cut long text with an ellipsis.
- Your carousel setup (which gig apps are shown and their order) is no longer
  lost: it is kept per account on the phone, so signing out and back in, or
  an update that restarts the app, puts it back. Another account on the same
  phone still starts clean.
- The system launch screen no longer shows a logo (it was not the official one):
  its image is now fully transparent, on the same background the start-up
  screen paints, so the steering wheel appears with no jump.
- The steering wheel was redrawn: thick rim, wide hub with a horn pad, three
  spokes that flare at the rim and hub, and a lighter centre mark at 12 o'clock
  so the turn is visible.
- New start-up screen: a steering wheel in the logo blue (#0275F4) that turns without
  stopping (`lib/widgets/brand_loader.dart`), drawn in code so it needs no image.
  Under it the line "Track your journey" ("Registra tu camino"); it stays up at least 0.9 s so the turn is seen. It also replaces the stock spinner
  on the permission steps and the Allow button. It stays still when the phone
  has animations turned off.
- Business now also lists Delivery, Errands and supplies, Client visit and
  Airport and travel (they count as business miles in reports). Needs the
  `20261104180000_irs_purpose_business_subtypes` migration -- applied.
- Trip purpose menu simplified, in the way MileIQ groups it: Recent (the last
  two used), Business, and Personal (work commute, medical, charitable, moving,
  education, other). Text only, no icons; "$" marks the purposes with their own
  rate. "Work commute" stays under Personal.
- Settings simplified: icons only on the three main sections (Language,
  Automatic trips, Report); every other row is text only. "Background
  reliability" lists only what is off, with a fix button; everything that is
  already on folds into one "Active (n)" group.
- The camera and Usage Access are now asked on their own page, in the moment
  they are needed: the same "why / what stops working" page as the first launch,
  with just that one step -- before the first odometer photo, and when
  gig-app auto-detection is turned on (replaces the plain text dialog).
- First-time permission steps no longer include Usage Access: it is asked when
  the driver turns on gig-app auto-detection (Premium), which already asks for
  it and explains why. Settings still lists it.

## 1.3.14+54 — 2026-11-04

(Builds 52 and 54-56 were never uploaded to Play; 53 is the last one sent, so
everything since then ships together as 54.)

- Onboarding like MileIQ: after signing in the driver lands straight on the
  permission steps, one page per permission (progress bar, why it is asked,
  "your data is safe", what stops working without it, one Allow button). The
  welcome screen with its permission list and checkbox are gone; the 18+ /
  Terms sentence sits under the first Allow button and the acceptance is
  recorded when it is tapped. Colors come from `CmColors`.
- Camera is no longer asked at the start (it is asked when the first odometer
  photo is needed). The Settings permission status still lists it.
- Fix: a returning user was sent through the welcome and permission steps again
  after signing out and back in. Login and the start-up check now trust the
  account's `welcome_seen` (server) and restore this device's flag.
- No more splash page: the "Olympus Mont Systems" view is gone and the page
  file with it. The system launch screen is the only splash; the first route is
  decided by `lib/services/startup_router.dart`.

## 1.3.13+53 — 2026-11-03

- Permissions steps: the "allowed" check is now the Olimsys brand blue.
- The app reports which permissions are on/off (plus app version, OS version and
  phone model) to `device_permission_status`, one row per user, so support can
  see why a phone loses miles. No location, no identifiers; the privacy policy
  now says so. Needs migration `20261104120000_device_permission_status` (the
  app ignores a missing function and shows nothing to the driver).

## 1.3.12+52 — 2026-11-03

- Permissions, one step at a time: location, location "all the time",
  notifications, physical activity, battery, camera and (Android) Usage Access,
  each with the reason it is needed and what stops working at 100% without it.
  The icon turns into a check when allowed and the next step slides in. Only
  location is required; every other step can be skipped. Already-granted steps
  are skipped. New `lib/views/permissions_flow_screen.dart` and
  `lib/utils/permission_status.dart`.
- Approximate-only location (Android 12+) is now detected and the driver is told
  to turn on "precise"; the recovery dialog says so instead of "all the time".
- Settings > background reliability now lists location, location all the time,
  notifications, activity and camera with a status colour; tapping reopens the
  permissions steps.
- Critical permissions for the recovery alert are now location + all the time +
  precise (camera and activity no longer trigger a location-only message).
- Manifest: removed READ_EXTERNAL_STORAGE (added by the camera plugin, unused).

## 1.3.11+51 — 2026-11-03

- Work places: each place can have a trip type (work commute, business,
  charitable, medical, education, moving, personal) or stay gig-only
  (reminders). New opt-in switch "Start tracking automatically": at a place with
  a type, inside work hours, the trip starts by itself (only when this week's
  odometer photo exists and the app is running). A purpose trip (never a
  gig-app trip) that stays ~3 minutes inside a place with a type is closed and
  the driver is told. Arrival dwell is now 3 minutes (was 2.5). Leaving a place
  with a type no longer shows the "stop tracking?" reminder. Gig only.

## 1.3.10+50 — 2026-11-03

- Vehicle screen: trips driven before the user had a car (no vehicle) can now
  be assigned to a car ("N trips without a vehicle" card, with confirmation).
  Server side: `assign_trips_to_vehicle` (migration
  `20261103150000_assign_orphan_trips_to_vehicle`). It only fills a blank
  vehicle on the user's own closed, unsealed personal trips; closed trips stay
  frozen for everything else, and each assignment is logged in
  `trip_vehicle_assignments`. Gig only (Fleet trips always have a vehicle).

## 1.3.10+49 — 2026-11-03

- Vehicles: the add-vehicle and maintenance screens no longer show raw
  database text; errors go through the shared error registry (code + safe
  message). The server-side cause of "permission denied for function
  fn_display_id_blocked" is fixed by migration
  `20261103120000_display_id_generators_security_definer`.
- Vehicle list: ~95 newer models (2023-2027) so more cars are found without
  "Other": Mazda CX-50/CX-70/CX-90/MX-30, Toyota Corolla Cross/Crown/Grand
  Highlander, Hyundai Ioniq 5/6/9, Kia EV6/EV9/K4, Ford Mustang Mach-E, and more.
- Errors that were silently ignored in a few places are now logged.

## 1.3.10+48 — 2026-11-02

- Fix: the live map was blank because the basemap pointed to the disabled
  `r2.dev` public URL; it now uses the `controlmiles-tiles` Worker.
  (+47 was already on Play without this fix, so the build number went up.)

## 1.3.10+47 — 2026-11-01

- Work hours reminder (Settings, below Auto-detect): pick the days and the
  start and end time, and the phone reminds you to start and stop tracking.
  Nothing starts on its own and your location is not used. Local
  notifications only, English and Spanish; it can also be muted from the
  notification types sheet.
- My work places (Premium, same sheet): save places with "Add my current
  location". Staying about 2 minutes at one during your work hours shows
  "You arrived at X -- start tracking?", and leaving one with a trip running
  shows "Stop tracking?". Reminders only. Places stay on the phone. Needs
  location "all the time".
- Odometer photos: new default cycle "Once a year" (two photos: start and end
  of the year) for every new vehicle; monthly stays free and twice a month is
  Premium. Existing vehicles keep their cycle. In the annual cycle any photo
  already taken this year counts, so the app never asks twice. Server side:
  migration `20261101120000_odometer_annual_cycle.sql` (applied); weekly and
  daily cycles exist there but are not offered in the app yet.

## 1.3.9+46 — 2026-10-31

- Reports: the Summary card is now a full-width band (like the Dashboard),
  stays on screen while the trips scroll, and Today's miles and time are
  always side by side.
- Reports: the "Trip details" brown label now covers only its text.
- History: the "Last 12 months" card has the brown title strip.

## 1.3.8+45 — 2026-10-30

- The "Custom/Truck" card is now **General**, with a new icon, and it is the
  first card in the list.
- Drag & drop: press and hold a card, then drag to reorder (Basic and Premium).
- Premium: choose which apps appear in the list; only those are shown and
  watched by automatic detection (General always shows).
- Odometer photos now follow the calendar: **monthly** (the 1st) for everyone,
  **twice a month** (the 1st and the 15th) for Premium. The weekly option is
  gone and ending a trip no longer forces a closing photo; starting a trip
  still needs the photo of the current period. Migration
  `20261030024841_odometer_two_cycles.sql` (applied).
- Odometer reader: ignores the trip meter, fixes O/I read as digits, prefers
  numbers at or above the vehicle's last odometer, and logs what it read vs.
  what the driver confirmed (numbers only) to improve it.

## 1.3.7+44 — 2026-10-28

### Added
- GPS watchdog during a trip. If the phone's GPS (or the app's location
  permission) is switched off, the trip pauses after a few seconds: no time
  and no miles are counted while it is off, and the driver gets a
  notification and a dashboard banner asking to turn it back on. When GPS
  returns the banner asks to tap Resume (it never resumes by itself). Resume
  is blocked while GPS is still off.
- "No GPS signal" notice when GPS is on but the phone cannot get a position
  for 3+ minutes (tunnel, garage). The trip keeps running; miles are not
  counted until the signal returns. A parked vehicle is not flagged.
- Audit events `GPS_OFF_PAUSE` and `LOCATION_PERMISSION_OFF_PAUSE`.
  A paused trip keeps the existing reminders (1, 2, 4 h) and the server
  closes it after 12 h without activity.
- Tests: `gps_watchdog_test.dart`. Texts in English and Spanish.

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
