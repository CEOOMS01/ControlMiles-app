// After the driver swipes the app away, the duration must come back where it
// was and match the notification's clock. These pin the rules that decide it.

import 'package:flutter_test/flutter_test.dart';
import 'package:controlmiles/tracking/run_segment_anchor.dart';

void main() {
  final now = DateTime.utc(2026, 9, 26, 18, 0, 0);
  int ms(DateTime d) => d.millisecondsSinceEpoch;

  test('uses the segment start saved with the checkpoint', () {
    final started = now.subtract(const Duration(hours: 3));
    final got = restoreRunSegmentStart(now: now, persistedMs: ms(started), baseSeconds: 600);
    expect(got.isAtSameMomentAs(started), isTrue);
    // duration = base + (now - start): the 3 h driven are NOT lost
    expect(now.difference(got), const Duration(hours: 3));
  });

  test('a never-paused trip keeps its full duration through a swipe-away', () {
    final tripStart = now.subtract(const Duration(hours: 9));
    final got = restoreRunSegmentStart(now: now, persistedMs: ms(tripStart), baseSeconds: 0);
    expect(now.difference(got), const Duration(hours: 9));
  });

  test('without a saved value, a never-paused section falls back to its own start', () {
    final sectionStart = now.subtract(const Duration(hours: 2, minutes: 30));
    final got = restoreRunSegmentStart(now: now, sectionStart: sectionStart, baseSeconds: 0);
    expect(got.isAtSameMomentAs(sectionStart), isTrue);
  });

  test('without a saved value, a section that was paused before cannot be rebuilt: restarts from now', () {
    final sectionStart = now.subtract(const Duration(hours: 5));
    final got = restoreRunSegmentStart(now: now, sectionStart: sectionStart, baseSeconds: 1800);
    expect(got.isAtSameMomentAs(now), isTrue);
  });

  test('a stale checkpoint older than 36 h is not believed', () {
    final old = now.subtract(const Duration(hours: 40));
    expect(restoreRunSegmentStart(now: now, persistedMs: ms(old), baseSeconds: 60).isAtSameMomentAs(now), isTrue);
    expect(restoreRunSegmentStart(now: now, sectionStart: old, baseSeconds: 0).isAtSameMomentAs(now), isTrue);
  });

  test('a start in the future (clock change) is never used', () {
    final future = now.add(const Duration(hours: 1));
    expect(restoreRunSegmentStart(now: now, persistedMs: ms(future)).isAtSameMomentAs(now), isTrue);
  });

  test('a start a few seconds ahead is clamped to now, never negative', () {
    final slightlyAhead = now.add(const Duration(seconds: 30));
    final got = restoreRunSegmentStart(now: now, persistedMs: ms(slightlyAhead));
    expect(got.isAfter(now), isFalse);
  });

  test('a just-started segment is accepted', () {
    final justNow = now.subtract(const Duration(seconds: 5));
    expect(restoreRunSegmentStart(now: now, persistedMs: ms(justNow)).isAtSameMomentAs(justNow), isTrue);
  });
}
