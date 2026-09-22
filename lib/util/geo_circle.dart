// Olympus Mont Systems LLC - ControlMiles
// lib/util/geo_circle.dart
//
// MapLibre's circle-radius (both the runtime style layer and the
// CircleOptions annotation) is in SCREEN PIXELS, not meters -- it would
// visually shrink/grow as the admin zooms instead of representing a
// fixed real-world geofence radius. Generates the actual geodesic
// polygon instead (standard destination-point-given-bearing-and-distance
// formula, walked around 360 degrees), rendered via controller.addFill,
// which draws real geographic coordinates. Dart port of the identical
// technique in controlmiles-web's src/lib/geo-circle.ts, so a geofence
// looks the same size on the web dashboard and in this app.

import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

const double _earthRadiusM = 6371000;

List<LatLng> circlePolygon(
  double centerLat,
  double centerLng,
  double radiusMeters, {
  int points = 64,
}) {
  final centerLatRad = centerLat * math.pi / 180;
  final centerLngRad = centerLng * math.pi / 180;
  final angularDistance = radiusMeters / _earthRadiusM;

  final coords = <LatLng>[];
  for (var i = 0; i <= points; i++) {
    final bearing = (i / points) * 2 * math.pi;
    final lat = math.asin(
      math.sin(centerLatRad) * math.cos(angularDistance) +
          math.cos(centerLatRad) * math.sin(angularDistance) * math.cos(bearing),
    );
    final lng = centerLngRad +
        math.atan2(
          math.sin(bearing) * math.sin(angularDistance) * math.cos(centerLatRad),
          math.cos(angularDistance) - math.sin(centerLatRad) * math.sin(lat),
        );
    coords.add(LatLng(lat * 180 / math.pi, lng * 180 / math.pi));
  }
  return coords;
}
