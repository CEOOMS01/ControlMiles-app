import 'package:controlmiles/tracking/trip_start_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Real case, 2026-11-10 5:55 AM: parked at 219 Allendale, first GPS point 162 m away.
  const parked = (39.2908245, -76.6779515);
  const firstFix = (39.2893914, -76.6782316);

  test('an automatic trip starts where the car was parked', () {
    expect(TripStartPoint.choose(parking: parked, lat: firstFix.$1, lng: firstFix.$2), parked);
  });

  test('the parking spot wins over the fence centre', () {
    const fence = (39.2900, -76.6790);
    expect(TripStartPoint.choose(parking: parked, fence: fence, lat: firstFix.$1, lng: firstFix.$2), parked);
  });

  test('the fence centre is used when there is no parking spot', () {
    expect(TripStartPoint.choose(fence: parked, lat: firstFix.$1, lng: firstFix.$2), parked);
  });

  test('the same place keeps the first GPS point', () {
    expect(TripStartPoint.choose(parking: parked, lat: 39.29085, lng: -76.67796), isNull);
  });

  test('a parking spot far away is not used', () {
    // About 50 km: the car was not where the phone last left it.
    expect(TripStartPoint.choose(parking: (39.124, -76.934), lat: firstFix.$1, lng: firstFix.$2), isNull);
  });

  test('a far parking spot falls back to a fence centre in range', () {
    expect(TripStartPoint.choose(parking: (39.124, -76.934), fence: parked, lat: firstFix.$1, lng: firstFix.$2), parked);
  });

  test('saved text reads back', () {
    expect(TripStartPoint.parse('39.2908245,-76.6779515,1762770000000'), parked);
    expect(TripStartPoint.parse('bad'), isNull);
    expect(TripStartPoint.parse(null), isNull);
  });
}
