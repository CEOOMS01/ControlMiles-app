import 'package:controlmiles/tracking/trip_inactivity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 7, 15, 30);

  test('a trip still for less than 5 minutes keeps going', () {
    expect(TripInactivity.endOfStillTrip(lastMotion: now.subtract(const Duration(minutes: 4, seconds: 59)), now: now), isNull);
  });

  test('after 5 still minutes it ends when the car stopped', () {
    final stopped = now.subtract(const Duration(minutes: 5));
    expect(TripInactivity.endOfStillTrip(lastMotion: stopped, now: now), stopped);
  });

  test('a trip left open for hours ends at its last movement', () {
    final stopped = now.subtract(const Duration(hours: 3));
    expect(TripInactivity.endOfStillTrip(lastMotion: stopped, now: now), stopped);
  });
}
