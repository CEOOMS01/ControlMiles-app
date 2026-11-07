// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/tracking_notification.dart
//
// Pure rules for the persistent "tracking is running" notification, kept free
// of Flutter and of the tracking plugin so they can be tested on their own.
//
// 2026-11-06: the notification is fixed and minimal. Android requires one while
// a trip records, but it no longer shows live miles or a ticking timer (they
// cost constant updates and battery, and the dashboard already shows them).
// A trip says "ControlMiles is recording your trip"; auto-detect that is armed
// but has no trip says it is ready.

/// Epoch milliseconds the notification's count-up clock should start from, so
/// that it reads [activeElapsed] right now. Using the ACTIVE time (not "since
/// the trip was created") is what keeps time spent paused out of the count.
int notificationStartedAtMs(DateTime now, Duration activeElapsed) {
  final elapsed = activeElapsed.isNegative ? Duration.zero : activeElapsed;
  return now.subtract(elapsed).millisecondsSinceEpoch;
}

const double _kmPerMile = 1.60934;

/// "12.4 mi" / "20.0 km". Digits and a unit only, so it needs no translation
/// and cannot show a wrong-language sentence.
String trackingNotificationText({required double miles, required bool metric}) {
  final safe = miles.isNaN || miles < 0 ? 0.0 : miles;
  final value = metric ? safe * _kmPerMile : safe;
  return '${value.toStringAsFixed(1)} ${metric ? 'km' : 'mi'}';
}

/// What the plugin shows when nothing live is available (and what is put back
/// when tracking stops, so a later automatic restart never shows old numbers).
const String kDefaultNotificationTitle = 'ControlMiles Tracking';
const String kDefaultNotificationText = 'Recording miles securely';

/// What a trip in progress says (the app passes it translated).
const String kTripNotificationBody = 'ControlMiles is recording your trip';

/// "ControlMiles \u00b7 12.4 mi" -- brand name plus digits and a unit, nothing
/// to translate.
String trackingNotificationTitle({required double miles, required bool metric}) =>
    'ControlMiles \u00b7 ${trackingNotificationText(miles: miles, metric: metric)}';

/// The gig app being tracked ("Uber"), or the neutral default when unknown.
/// (No longer shown while a trip records; kept for other uses.)
String trackingNotificationBody(String? gigAppName) {
  final name = (gigAppName ?? '').trim();
  return name.isEmpty ? kDefaultNotificationText : name;
}

/// Re-posting the notification wakes the plugin and the notification shade, so
/// it is refreshed at most once per [minGap], and only when what it shows would
/// actually read differently. At highway speed the distance changes about every
/// 10-20 seconds, so 15 s keeps it feeling live without waking things up
/// constantly.
bool shouldRefreshNotification({
  required DateTime? lastRefreshAt,
  required DateTime now,
  required String? lastText,
  required String newText,
  Duration minGap = const Duration(seconds: 15),
}) {
  if (lastText == newText) return false;
  if (lastRefreshAt == null) return true;
  return now.difference(lastRefreshAt) >= minGap;
}

/// What the persistent notification says and whether it counts time.
class TrackingNotificationLabels {
  final String title;
  final String body;

  /// Kept for the plugin's setting; always false now (no ticking timer).
  final bool showTimer;

  const TrackingNotificationLabels({
    required this.title,
    required this.body,
    required this.showTimer,
  });
}

/// Two very different situations share the same foreground-service
/// notification, because Android requires one whenever the background service
/// runs:
///  * a TRIP is in progress: "ControlMiles" and "ControlMiles is recording your
///    trip", fixed (no distance, no timer);
///  * auto-detect is ARMED but no trip has started: the driver must not be
///    told a trip is being recorded. It says auto-detect is listening, with no
///    timer and no distance.
/// [idleTitle] / [idleBody] come already translated (the app's own
/// "Automatic Detection" / "Listening for a gig app to open..." strings).
TrackingNotificationLabels trackingNotificationLabels({
  required bool hasActiveTrip,
  required double miles,
  required bool metric,
  required String? gigAppName,
  required String idleTitle,
  required String idleBody,
  String tripBody = kTripNotificationBody,
}) {
  if (!hasActiveTrip) {
    return TrackingNotificationLabels(
      title: idleTitle.trim().isEmpty ? kDefaultNotificationTitle : idleTitle.trim(),
      body: idleBody.trim().isEmpty ? kDefaultNotificationText : idleBody.trim(),
      showTimer: false,
    );
  }
  return TrackingNotificationLabels(
    title: 'ControlMiles',
    body: tripBody.trim().isEmpty ? kTripNotificationBody : tripBody.trim(),
    showTimer: false,
  );
}
