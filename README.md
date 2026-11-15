# ControlMiles (Android / iOS app)

The personal mileage app for gig drivers: GPS trips, odometer photos,
gig-app tagging, automatic trips (Premium), IRS-ready reports and
Google Play plans. Package `com.olimsys.controlmiles`.

Its siblings in `controlmilesproject/`:

| Folder | What |
|---|---|
| `controlmiles` | This app, plus the shared Supabase backend (`supabase/`: migrations and edge functions). |
| `controlmiles-fleet` | ControlMiles Fleet, the fleet team's app (`com.olimsys.controlmiles.fleet`). Its own project since 2026-10-19. |
| `controlmiles-web` | controlmiles.com: landing, pricing and the fleet admin dashboard. |

All three use the same Supabase project.

## Plans

One plan is sold (decided 2026-11-13): **ControlMiles at $9.99 a month or a yearly
price** (about $79.99), through Google Play. It includes everything: automatic
trips, up to 5 vehicles, My work (work type, automatic tracking hours), Regular
Trips and the odometer cycle choice. The automatic 15-day free trial stays, shown
as one line of text; once it ends without a plan, starting a new trip is blocked.

**Basic is no longer sold.** Its product (`controlmiles_basic_monthly`) stays in Play
Console and in the server's product table so a purchase made before keeps
verifying. The yearly price is a second base plan of `controlmiles_premium_monthly`
(or its own product `controlmiles_premium_annual`; both work: the app tells monthly
from yearly by billing period). See `docs/play-store-listing.md`.

The database decides the plan, not the phone's saved copy.

## Rules worth knowing

- **Odometer photo**: once per cycle of the vehicle, never per trip. The cycle is
  **annual** for every account; **Premium** may choose **every 15 days** or
  **monthly**. The server enforces the plan for the cycle
  (`fn_enforce_odometer_cycle_tier`).
- **Trip length**: a trip closes by itself after 5 minutes without movement; moving
  again starts a new one. Trips under 1 mile are discarded.
- **Gig-app trips** are saved as Business. General trips are classified by the
  driver.
- **Languages**: English, Spanish, French, Chinese and Hindi.

## Diagnostics

Settings can send the on-device diagnostic log to the `diagnostic_logs` table
(times, rounded coordinates, counts and reasons; no personal text). The log also
records cold-start timings (`startup` lines), so a log sent from a release build
shows how long the app took to open.

## Build

Play bundle, with the Dart code obfuscated:

```
powershell -ExecutionPolicy Bypass -File tool\build_release.ps1
```

It reads the version from `pubspec.yaml`, builds the signed `.aab` and copies it
to the Desktop as `ControlMiles-gig-<version>-<build>.aab`. The symbol files
needed to read a stack trace of that build stay in `release-symbols/<version>/`
on the build PC and are not committed; keep a version's folder while that version
is in use. The script refuses to run twice for the same version, so bump `version`
in `pubspec.yaml` first.

Release signing needs `android/key.properties` (not in git; see
`android/key.properties.example`).

Every app change bumps `version` in `pubspec.yaml` and adds a `CHANGELOG.md`
entry.

## Tests

```
flutter analyze lib
flutter test
```
