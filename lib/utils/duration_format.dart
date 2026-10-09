// Olympus Mont Systems LLC - ControlMiles
// lib/utils/duration_format.dart
//
// Trip durations with seconds (2026-10-09, owner's request): "2h 17m 05s",
// "17m 05s", "45s". Used by the History and Reports cards and summaries.

String formatHms(int seconds) {
  if (seconds < 0) seconds = 0;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  if (h > 0) return '${h}h ${two(m)}m ${two(s)}s';
  if (m > 0) return '${m}m ${two(s)}s';
  return '${s}s';
}
