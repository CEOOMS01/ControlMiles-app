// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/route_recorder.dart
//
// Trip route drawing (2026-10-04, user request): keeps each gig-app
// segment's driven path on the phone and uploads it ONCE, when the segment
// closes, as a simplified encoded polyline (session_sections.route_polyline,
// ~0.5-2 KB) -- the same approach Strava uses (encoded polyline per
// activity). The website turns it into a static route image
// (/api/trip-map/<session>/<token>, our own basemap), so no per-minute
// breadcrumb is needed to draw a gig trip.
//
// Points go to an append-only file per section, so the path survives
// Android killing the app mid-trip and is shared by the UI and headless
// isolates. A failed upload (offline) keeps the file; uploadPending() retries
// on the next start. The drawing never measures anything: miles stay what
// TrackingController measured.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RouteRecorder {
  RouteRecorder._();

  /// Points closer than this to the last stored one are skipped (GPS jitter,
  /// waiting at lights). Invisible on a trip-size map.
  static const double minStepMeters = 15;

  /// Douglas-Peucker tolerance; raised until the route fits [maxPoints].
  static const double simplifyMeters = 6;
  static const int maxPoints = 800;

  static String? _lastSectionId;
  static double? _lastLat;
  static double? _lastLng;

  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/routes');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _file(String sectionId) async =>
      File('${(await _dir()).path}/$sectionId.txt');

  /// Records one antifraud-validated GPS point of [sectionId]. Never throws.
  static Future<void> add(String sectionId, double lat, double lng) async {
    try {
      if (_lastSectionId == sectionId && _lastLat != null &&
          distanceMeters(_lastLat!, _lastLng!, lat, lng) < minStepMeters) {
        return;
      }
      _lastSectionId = sectionId;
      _lastLat = lat;
      _lastLng = lng;
      await (await _file(sectionId)).writeAsString(
        '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      debugPrint('[RouteRecorder] add failed: $e');
    }
  }

  /// Uploads [sectionId]'s route (write-once in the DB) and deletes the local
  /// file on success. Safe to call twice and for sections the DB dropped.
  static Future<bool> upload(String sectionId) async {
    try {
      final file = await _file(sectionId);
      if (!await file.exists()) return true;

      final points = _parse(await file.readAsString());
      if (points.length >= 2) {
        final polyline = encodePolyline(simplify(points));
        await Supabase.instance.client
            .from('session_sections')
            .update({'route_polyline': polyline})
            .eq('id', sectionId)
            .isFilter('route_polyline', null);
      }
      await file.delete();
      if (_lastSectionId == sectionId) _lastSectionId = null;
      return true;
    } catch (e) {
      debugPrint('[RouteRecorder] upload failed for $sectionId (kept for retry): $e');
      return false;
    }
  }

  /// Retries every finished section still on the phone (app start / recovery).
  static Future<void> uploadPending({String? exceptSectionId}) async {
    try {
      final files = (await _dir()).listSync().whereType<File>();
      for (final f in files) {
        final name = f.uri.pathSegments.last;
        if (!name.endsWith('.txt')) continue;
        final sectionId = name.substring(0, name.length - 4);
        if (sectionId == exceptSectionId) continue;
        await upload(sectionId);
      }
    } catch (e) {
      debugPrint('[RouteRecorder] uploadPending failed: $e');
    }
  }

  /// Drops a section's route without uploading (e.g. the trip was discarded).
  static Future<void> discard(String sectionId) async {
    try {
      final file = await _file(sectionId);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Leftover file: uploadPending() tries it later and the DB ignores it.
    }
  }

  static List<math.Point<double>> _parse(String text) {
    final out = <math.Point<double>>[];
    for (final line in text.split('\n')) {
      final parts = line.split(',');
      if (parts.length != 2) continue;
      final lat = double.tryParse(parts[0]);
      final lng = double.tryParse(parts[1]);
      if (lat == null || lng == null) continue;
      out.add(math.Point(lat, lng)); // x = lat, y = lng
    }
    return out;
  }

  // ---------------------------------------------------------------------
  // Geometry (public for tests)
  // ---------------------------------------------------------------------

  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  /// Douglas-Peucker in local meters; tolerance doubles until the result
  /// has at most [maxPoints] points. First and last points are always kept.
  static List<math.Point<double>> simplify(List<math.Point<double>> latLng) {
    if (latLng.length <= 2) return latLng;
    final lat0 = latLng.first.x * math.pi / 180;
    final mPerDegLat = 111320.0;
    final mPerDegLng = 111320.0 * math.cos(lat0);
    final xy = [
      for (final p in latLng) math.Point(p.y * mPerDegLng, p.x * mPerDegLat),
    ];

    var tolerance = simplifyMeters;
    while (true) {
      final keep = List<bool>.filled(xy.length, false);
      keep[0] = true;
      keep[xy.length - 1] = true;
      final stack = <(int, int)>[(0, xy.length - 1)];
      while (stack.isNotEmpty) {
        final (a, b) = stack.removeLast();
        var maxD = 0.0;
        var idx = -1;
        for (var i = a + 1; i < b; i++) {
          final d = _segmentDistance(xy[i], xy[a], xy[b]);
          if (d > maxD) {
            maxD = d;
            idx = i;
          }
        }
        if (idx != -1 && maxD > tolerance) {
          keep[idx] = true;
          stack.add((a, idx));
          stack.add((idx, b));
        }
      }
      final result = [
        for (var i = 0; i < latLng.length; i++)
          if (keep[i]) latLng[i],
      ];
      if (result.length <= maxPoints) return result;
      tolerance *= 2;
    }
  }

  static double _segmentDistance(math.Point<double> p, math.Point<double> a, math.Point<double> b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return p.distanceTo(a);
    final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / len2).clamp(0.0, 1.0);
    return p.distanceTo(math.Point(a.x + t * dx, a.y + t * dy));
  }

  /// Google encoded polyline, precision 1e-5 (x = lat, y = lng).
  static String encodePolyline(List<math.Point<double>> latLng) {
    final out = StringBuffer();
    var prevLat = 0;
    var prevLng = 0;
    for (final p in latLng) {
      final lat = (p.x * 1e5).round();
      final lng = (p.y * 1e5).round();
      _encodeValue(lat - prevLat, out);
      _encodeValue(lng - prevLng, out);
      prevLat = lat;
      prevLng = lng;
    }
    return out.toString();
  }

  static void _encodeValue(int value, StringBuffer out) {
    var v = value < 0 ? ~(value << 1) : (value << 1);
    while (v >= 0x20) {
      out.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    out.writeCharCode(v + 63);
  }
}
