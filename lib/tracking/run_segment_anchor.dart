// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/run_segment_anchor.dart
//
// Where the ACTIVE driving clock restarts from after the app's memory is lost
// (the driver swipes the app away, Android kills the process, a headless
// isolate wakes up). Kept free of Flutter and of the tracker so it can be
// tested on its own.
//
// The duration shown to the driver is
//     confirmed base  +  (now - start of the current running segment)
// The base is saved at every pause/resume, but the segment start used to live
// only in memory and was reset to "now" on recovery. Everything driven since
// the last start/resume was therefore lost: a 3-hour trip that was never
// paused came back as 00:00:00, while the notification's own clock (drawn by
// Android from the original start) kept counting -- the two disagreed.
// The segment start is now saved with the checkpoint and restored here, so the
// app and the notification are computed from the same instant.

/// A running segment older than this is not believed (a stale checkpoint, not
/// a real trip) and the clock restarts from [now] instead of showing days.
const Duration kMaxTrustedSegmentAge = Duration(hours: 36);

/// A start "in the future" beyond this is a clock problem, not a real segment.
const Duration _kFutureTolerance = Duration(minutes: 2);

/// The start of the running segment to use after recovery.
///
/// 1. the value saved with the checkpoint, when it is believable;
/// 2. otherwise, for a section that was never paused ([baseSeconds] == 0),
///    the section's own start time -- exactly right for that case;
/// 3. otherwise [now] (the previous behaviour: nothing to reconstruct from).
DateTime restoreRunSegmentStart({
  required DateTime now,
  int? persistedMs,
  DateTime? sectionStart,
  int baseSeconds = 0,
}) {
  bool believable(DateTime t) =>
      !t.isAfter(now.add(_kFutureTolerance)) &&
      now.difference(t) <= kMaxTrustedSegmentAge;

  if (persistedMs != null) {
    final saved = DateTime.fromMillisecondsSinceEpoch(persistedMs);
    if (believable(saved)) return saved.isAfter(now) ? now : saved;
  }
  if (baseSeconds == 0 && sectionStart != null && believable(sectionStart)) {
    return sectionStart.isAfter(now) ? now : sectionStart;
  }
  return now;
}
