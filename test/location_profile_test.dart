// A trip must never run on the battery-saving profile: mileage accuracy is the
// product. These pin which profile applies when, and what each one contains.

import 'package:flutter_test/flutter_test.dart';
import 'package:controlmiles/tracking/location_profile.dart';

void main() {
  const defaultInterval = 1000;
  const defaultFastest = 500;

  LocationProfile forState({required bool trip}) => locationProfileFor(
        hasActiveTrip: trip,
        defaultIntervalMs: defaultInterval,
        defaultFastestIntervalMs: defaultFastest,
      );

  test('a trip uses the engine original settings: high accuracy, 10 m, default intervals', () {
    final p = forState(trip: true);
    expect(p.accuracy, LocationAccuracy.high);
    expect(p.distanceFilterMeters, 10.0);
    expect(p.intervalMs, defaultInterval);
    expect(p.fastestIntervalMs, defaultFastest);
    expect(p.isTrip, isTrue);
  });

  test('listening (armed, no trip) is balanced, sparse and coarse', () {
    final p = forState(trip: false);
    expect(p.accuracy, LocationAccuracy.medium);
    expect(p.distanceFilterMeters, 100.0);
    expect(p.intervalMs, 30000);
    expect(p.fastestIntervalMs, 15000);
    expect(p.isTrip, isFalse);
  });

  test('the listening profile asks for far less than a trip on every axis', () {
    final trip = forState(trip: true);
    final idle = forState(trip: false);
    expect(idle.intervalMs, greaterThan(trip.intervalMs));
    expect(idle.fastestIntervalMs, greaterThan(trip.fastestIntervalMs));
    expect(idle.distanceFilterMeters, greaterThan(trip.distanceFilterMeters));
  });

  test('trip settings follow the plugin defaults it is given, never hard-coded drift', () {
    final p = locationProfileFor(
      hasActiveTrip: true,
      defaultIntervalMs: 2500,
      defaultFastestIntervalMs: 1200,
    );
    expect(p.intervalMs, 2500);
    expect(p.fastestIntervalMs, 1200);
  });
}
