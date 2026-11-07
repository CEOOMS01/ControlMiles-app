import 'package:controlmiles/tracking/tracking_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 12);

  bool interrupted(List<String> statuses, Duration age) => TrackingController.isInterruptedTrip(
        sectionStatuses: statuses,
        startTime: now.subtract(age),
        now: now,
      );

  test('a trip with an open section is running, however old', () {
    expect(interrupted(['active'], const Duration(hours: 5)), isFalse);
    expect(interrupted(['paused'], const Duration(hours: 5)), isFalse);
    expect(interrupted(['switched', 'active'], const Duration(hours: 5)), isFalse);
  });

  test('every section ended: the trip was left open', () {
    expect(interrupted(['closed'], const Duration(seconds: 5)), isTrue);
    expect(interrupted(['switched', 'closed'], const Duration(seconds: 5)), isTrue);
  });

  test('no section yet: still starting until 15 minutes pass', () {
    expect(interrupted([], const Duration(minutes: 14)), isFalse);
    expect(interrupted([], const Duration(minutes: 16)), isTrue);
  });
}
