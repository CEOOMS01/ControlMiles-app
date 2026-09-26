// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/tracking_notification.dart
//
// Pure rules for the persistent "tracking is running" notification, kept free
// of Flutter and of the tracking plugin so they can be tested on their own.
//
// The notification is the driver's at-a-glance "card" on a long trip. The
// tracking plugin's native notification only supports a title, one line of
// text and a chronometer (no expanded styles, no custom layout), so the card is
// laid out like this:
//   * CHRONOMETER (header): a SELF-TICKING timer drawn by Android itself,
//     counting the ACTIVE driving time -- the same figure as the dashboard
//     card. It needs no Dart wake-ups, so it keeps counting even while the app
//     is suspended or the phone is in Doze.
//   * TITLE: "ControlMiles - 12.4 mi", the distance recorded so far. A timer
//     alone only proves the notification is alive; distance that keeps growing
//     proves GPS is still being recorded.
//   * TEXT: the gig app being tracked.

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

/// "ControlMiles \u00b7 12.4 mi" -- brand name plus digits and a unit, nothing
/// to translate.
String trackingNotificationTitle({required double miles, required bool metric}) =>
    'ControlMiles \u00b7 ${trackingNotificationText(miles: miles, metric: metric)}';

/// The gig app being tracked ("Uber"), or the neutral default when unknown.
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

  /// Only a real trip shows the chronometer (and is worth promoting to a Live
  /// Update). Waiting for a gig app must never look like a running trip.
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
///  * a TRIP is in progress: distance in the title, gig app in the text and the
///    chronometer counting active driving time;
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
}) {
  if (!hasActiveTrip) {
    return TrackingNotificationLabels(
      title: idleTitle.trim().isEmpty ? kDefaultNotificationTitle : idleTitle.trim(),
      body: idleBody.trim().isEmpty ? kDefaultNotificationText : idleBody.trim(),
      showTimer: false,
    );
  }
  return TrackingNotificationLabels(
    title: trackingNotificationTitle(miles: miles, metric: metric),
    body: trackingNotificationBody(gigAppName),
    showTimer: true,
  );
}
