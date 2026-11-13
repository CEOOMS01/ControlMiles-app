// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/trip_start_point.dart
//
// Where an automatic trip really started (2026-11-10, as MileIQ does): the place the
// car was parked, that is, where the previous trip ended. The phone only notices the
// drive once it has left its 150 m parking fence, so the first GPS point was about
// 160 m away and the address read "100 Allendale" instead of "219 Allendale".
//
// The parking spot saved when a trip closes comes first (it does not depend on when
// Android wakes the app); the fence centre saved at wake-up is the fallback. Either
// one only counts between 30 m and 2.5 km from the first GPS point: closer is the
// same place, farther means the car was not where the phone last left it.

import 'dart:math' as math;

class TripStartPoint {
  TripStartPoint._();

  static const double minMeters = 30;
  static const double maxMeters = 2500;

  /// The point to use as the trip's start, or null to keep the first GPS point.
  static (double, double)? choose({
    (double, double)? parking,
    (double, double)? fence,
    required double lat,
    required double lng,
  }) {
    for (final p in [parking, fence]) {
      if (p == null) continue;
      final m = meters(p.$1, p.$2, lat, lng);
      if (m >= minMeters && m <= maxMeters) return p;
    }
    return null;
  }

  static double meters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(a)));
  }

  /// "lat,lng,epochMs" as saved in the phone's preferences, or null.
  static (double, double)? parse(String? raw) {
    if (raw == null) return null;
    final p = raw.split(',');
    if (p.length < 2) return null;
    final lat = double.tryParse(p[0]);
    final lng = double.tryParse(p[1]);
    if (lat == null || lng == null) return null;
    return (lat, lng);
  }
}
