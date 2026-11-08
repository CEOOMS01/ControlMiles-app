import 'package:controlmiles/tracking/trip_inactivity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 7, 15, 30);

  test('a trip still for less than 10 minutes keeps going', () {
    expect(TripInactivity.endOfStillTrip(lastMotion: now.subtract(const Duration(minutes: 9)), now: now), isNull);
  });

  test('after 10 still minutes it ends when the car stopped', () {
    final stopped = now.subtract(const Duration(minutes: 10));
    expect(TripInactivity.endOfStillTrip(lastMotion: stopped, now: now), stopped);
  });

  test('a trip left open for hours ends at its last movement', () {
    final stopped = now.subtract(const Duration(hours: 3));
    expect(TripInactivity.endOfStillTrip(lastMotion: stopped, now: now), stopped);
  });
}
