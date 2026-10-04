import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:controlmiles/tracking/route_recorder.dart';

void main() {
  test('encodes the Google reference polyline', () {
    final pts = [
      const math.Point(38.5, -120.2),
      const math.Point(40.7, -120.95),
      const math.Point(43.252, -126.453),
    ];
    expect(RouteRecorder.encodePolyline(pts), '_p~iF~ps|U_ulLnnqC_mqNvxq`@');
  });

  test('a straight line simplifies to its two ends', () {
    final pts = [for (var i = 0; i <= 100; i++) math.Point(39.0 + i * 0.0001, -76.6)];
    final out = RouteRecorder.simplify(pts);
    expect(out.length, 2);
    expect(out.first, pts.first);
    expect(out.last, pts.last);
  });

  test('a real turn is kept', () {
    final pts = [
      const math.Point(39.0, -76.6),
      const math.Point(39.001, -76.6),
      const math.Point(39.002, -76.6),
      const math.Point(39.002, -76.599),
      const math.Point(39.002, -76.598),
    ];
    final out = RouteRecorder.simplify(pts);
    expect(out, contains(const math.Point(39.002, -76.6)));
  });

  test('a very long route is capped', () {
    final rnd = math.Random(1);
    final pts = [
      for (var i = 0; i < 5000; i++)
        math.Point(39.0 + i * 0.0002 + rnd.nextDouble() * 0.0005, -76.6 + rnd.nextDouble() * 0.0005),
    ];
    expect(RouteRecorder.simplify(pts).length, lessThanOrEqualTo(RouteRecorder.maxPoints));
  });

  test('distance is in meters', () {
    // ~111 m per 0.001 degree of latitude
    expect(RouteRecorder.distanceMeters(39.0, -76.6, 39.001, -76.6), closeTo(111.2, 0.5));
  });
}
