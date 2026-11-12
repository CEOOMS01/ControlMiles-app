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

Only two plans exist: **Basic** and **Premium**. The automatic 15-day free trial
stays, shown as one line of text.

- **Basic**: manual trips, gig-app tagging, reports.
- **Premium**: everything in Basic plus automatic trips, My work (work type,
  automatic tracking hours) and Regular Trips (General trips only).

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
