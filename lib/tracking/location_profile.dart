// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/location_profile.dart
//
// Which location settings the tracking engine runs with. Kept free of Flutter
// and of the tracking plugin so the rule can be tested on its own.
//
// Measured on a real phone (2026-09-26): with auto-detect ARMED and no trip,
// the moment the phone moved ControlMiles asked Android for HIGH_ACCURACY GPS
// every 1 second -- and nothing used those fixes, because in that mode the
// trigger is the gig app in the foreground, not the location. It only stopped
// (GPS OFF) once the phone was stationary again. GPS is the largest battery
// cost in the app, so:
//   * LISTENING (armed, no trip): coarse and infrequent. Just enough for the
//     engine's motion tracking to keep the background service alive.
//   * TRIP (a real section is running or resuming): exactly the settings the
//     engine was always configured with -- 1 s, high accuracy, 10 m. Mileage
//     accuracy is the product, so a trip must NEVER run on the listening
//     profile.

enum LocationAccuracy { high, medium }

class LocationProfile {
  final LocationAccuracy accuracy;

  /// Metres the device must move between fixes.
  final double distanceFilterMeters;

  /// Requested interval between fixes, ms.
  final int intervalMs;

  /// Fastest interval the engine may receive fixes at, ms.
  final int fastestIntervalMs;

  const LocationProfile({
    required this.accuracy,
    required this.distanceFilterMeters,
    required this.intervalMs,
    required this.fastestIntervalMs,
  });

  bool get isTrip => accuracy == LocationAccuracy.high;
}

/// The engine's original settings (see TraceletEngine.initialize): high
/// accuracy, a fix every 10 m. The intervals are the plugin's own defaults,
/// passed in so this stays a single source of truth for what "trip" means.
LocationProfile tripLocationProfile({
  required int defaultIntervalMs,
  required int defaultFastestIntervalMs,
}) =>
    LocationProfile(
      accuracy: LocationAccuracy.high,
      distanceFilterMeters: 10.0,
      intervalMs: defaultIntervalMs,
      fastestIntervalMs: defaultFastestIntervalMs,
    );

/// Auto-detect armed, waiting for a gig app: balanced accuracy, a fix at most
/// every 30 s and only after 100 m of movement.
const LocationProfile listeningLocationProfile = LocationProfile(
  accuracy: LocationAccuracy.medium,
  distanceFilterMeters: 100.0,
  intervalMs: 30000,
  fastestIntervalMs: 15000,
);

/// A trip needs full accuracy whenever a section exists -- including a paused
/// trip that is about to resume.
LocationProfile locationProfileFor({
  required bool hasActiveTrip,
  required int defaultIntervalMs,
  required int defaultFastestIntervalMs,
}) =>
    hasActiveTrip
        ? tripLocationProfile(
            defaultIntervalMs: defaultIntervalMs,
            defaultFastestIntervalMs: defaultFastestIntervalMs,
          )
        : listeningLocationProfile;
