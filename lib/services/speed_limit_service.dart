// Olympus Mont Systems LLC - ControlMiles
// lib/services/speed_limit_service.dart
//
// Real fix, not a caveat left in place (explicit user request, 2026-09-18):
// driver_safety_monitor.dart's "speeding" event used a single fixed
// ~75mph/120km/h ceiling, documented in its own header comment as "not
// road-aware... a known, documented simplification". This service looks
// up the REAL posted speed limit near a GPS point via OpenStreetMap's
// Overpass API -- free, keyless, same "no external Google Cloud
// credential" reasoning that already drove flutter_map's own selection
// for the live map (see pubspec.yaml).
//
// Deliberately NOT called on every GPS tick: Overpass is a shared public
// service with real rate limits, and a live network round-trip on every
// tick (multiple per minute, for every active fleet trip) would both be
// slow and risk the whole account getting throttled. The caller
// (DriverSafetyMonitor via tracking_controller.dart) only invokes this
// AFTER its own cheap, local fixed-threshold check already flagged a
// tick as a speeding CANDIDATE -- this service then either confirms it
// against the real limit (precise) or, if no tagged road data exists for
// that point (common -- most of the world's roads aren't maxspeed-tagged
// in OSM) or the network call fails/times out, falls back to treating
// the original fixed-threshold candidate as real. A missing/failed
// lookup never suppresses a real event, it only ever removes false
// positives when a confirmed real limit says the driver wasn't actually
// speeding relative to the posted sign.
//
// Grid-cell cache: speed limits don't change minute to minute, and a
// vehicle sitting in traffic or driving a straight road repeatedly
// re-queries the same few hundred meters. Caching by a coarse rounded
// lat/lng cell (~0.002 degrees, ~200m) avoids re-hitting Overpass for
// every tick on the same stretch of road, with a real TTL and a cap so a
// long trip's cache doesn't grow unbounded.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SpeedLimitResult {
  /// Posted limit in meters/second, or null if no tagged road was found
  /// nearby (the caller should then fall back to its own fixed ceiling).
  final double? limitMps;
  final String source; // 'osm' | 'unavailable'

  const SpeedLimitResult(this.limitMps, this.source);

  static const unavailable = SpeedLimitResult(null, 'unavailable');
}

class SpeedLimitService {
  static const _overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const _searchRadiusMeters = 40;
  static const _requestTimeout = Duration(seconds: 3);
  static const _cacheTtl = Duration(minutes: 30);
  static const _cacheMaxEntries = 500;
  // ~0.002 degrees of latitude is ~220m -- coarse enough that a real
  // stretch of road shares one cache cell, fine enough it doesn't blur
  // together genuinely different roads (e.g. a highway next to a parallel
  // side street).
  static const _gridPrecision = 0.002;

  static final Map<String, _CacheEntry> _cache = {};

  static String _gridKey(double lat, double lng) {
    final gLat = (lat / _gridPrecision).round() * _gridPrecision;
    final gLng = (lng / _gridPrecision).round() * _gridPrecision;
    return '${gLat.toStringAsFixed(3)},${gLng.toStringAsFixed(3)}';
  }

  /// Looks up the real posted speed limit near (latitude, longitude).
  /// Never throws -- any failure (timeout, network, parse, no tagged
  /// road nearby) resolves to [SpeedLimitResult.unavailable], which the
  /// caller treats as "keep the fixed-threshold candidate", not as "not
  /// speeding".
  static Future<SpeedLimitResult> lookup({
    required double latitude,
    required double longitude,
  }) async {
    final key = _gridKey(latitude, longitude);
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.cachedAt) < _cacheTtl) {
      return cached.result;
    }

    final result = await _fetch(latitude, longitude);

    if (_cache.length >= _cacheMaxEntries) {
      // Simple eviction: this is a bounded-size convenience cache, not a
      // correctness-critical one -- dropping the oldest entry on overflow
      // is enough to keep memory flat on a long shift without the
      // complexity of a real LRU.
      final oldestKey = _cache.entries
          .reduce((a, b) => a.value.cachedAt.isBefore(b.value.cachedAt) ? a : b)
          .key;
      _cache.remove(oldestKey);
    }
    _cache[key] = _CacheEntry(result, DateTime.now());
    return result;
  }

  static Future<SpeedLimitResult> _fetch(double lat, double lng) async {
    final query =
        '[out:json][timeout:3];way(around:$_searchRadiusMeters,$lat,$lng)[highway][maxspeed];out tags 1;';

    try {
      // Real bug caught live before shipping (verified with a raw curl
      // repro, not assumed): Overpass's Apache front-end returns 406 Not
      // Acceptable for a request with no/generic User-Agent -- would have
      // meant this ALWAYS silently fell back to 'unavailable' in
      // production, defeating the entire feature with no visible error
      // anywhere (the catch-all below is intentionally silent-fallback by
      // design, so this specific failure mode would never have surfaced
      // on its own). A real User-Agent is also Overpass's own documented
      // usage policy, not just a workaround.
      final response = await http
          .post(
            Uri.parse(_overpassUrl),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent': 'ControlMiles/1.0 (+https://controlmiles.com)',
            },
            body: {'data': query},
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return SpeedLimitResult.unavailable;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = body['elements'] as List<dynamic>?;
      if (elements == null || elements.isEmpty) {
        return SpeedLimitResult.unavailable;
      }

      final tags = elements.first['tags'] as Map<String, dynamic>?;
      final maxspeed = tags?['maxspeed'] as String?;
      final limitMps = _parseMaxspeed(maxspeed);
      if (limitMps == null) {
        return SpeedLimitResult.unavailable;
      }

      return SpeedLimitResult(limitMps, 'osm');
    } catch (_) {
      // Timeout, no connectivity, malformed response -- all resolve the
      // same way: no real limit available this tick, caller falls back.
      return SpeedLimitResult.unavailable;
    }
  }

  /// OSM's maxspeed tag convention: a bare number is km/h; an explicit
  /// "N mph" suffix means miles/hour (used on US/UK-tagged ways).
  /// Non-numeric values ("national", "none", "walk", advisory ranges like
  /// "50-60") are real OSM values but not a single usable ceiling here --
  /// treated as unavailable rather than guessed at.
  static double? _parseMaxspeed(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim().toLowerCase();

    final mphMatch = RegExp(r'^(\d+(\.\d+)?)\s*mph$').firstMatch(trimmed);
    if (mphMatch != null) {
      final mph = double.tryParse(mphMatch.group(1)!);
      return mph == null ? null : mph * 0.44704;
    }

    final kmhMatch = RegExp(r'^(\d+(\.\d+)?)$').firstMatch(trimmed);
    if (kmhMatch != null) {
      final kmh = double.tryParse(kmhMatch.group(1)!);
      return kmh == null ? null : kmh / 3.6;
    }

    return null;
  }

  /// Test/session-boundary hook -- mirrors the reset() pattern every
  /// other tracking-state class in this codebase already uses (e.g.
  /// AntifraudEngine, DriverSafetyMonitor), even though this cache is
  /// safe to keep warm across trips (speed limits don't change per
  /// trip) -- exposed for tests, not called from real tracking code.
  static void clearCache() => _cache.clear();
}

class _CacheEntry {
  final SpeedLimitResult result;
  final DateTime cachedAt;
  const _CacheEntry(this.result, this.cachedAt);
}
