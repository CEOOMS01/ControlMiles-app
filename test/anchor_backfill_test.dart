import 'package:controlmiles/tracking/tracking_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 0.001 degrees of latitude is about 111 m.
  const lat = 39.2908;
  const lng = -76.6779;

  test('a first fix next to the parking spot adds nothing', () {
    expect(TrackingController.anchorBackfillMeters(lat, lng, lat + 0.0001, lng), isNull); // ~11 m
  });

  test('a first fix a few hundred meters away adds the straight-line distance', () {
    final m = TrackingController.anchorBackfillMeters(lat, lng, lat + 0.005, lng)!; // ~555 m
    expect(m, inInclusiveRange(540, 570));
  });

  test('a first fix far away is not the same drive', () {
    expect(TrackingController.anchorBackfillMeters(lat, lng, lat + 0.05, lng), isNull); // ~5.5 km
  });
}
