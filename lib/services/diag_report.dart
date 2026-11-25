// Olympus Mont Systems LLC - ControlMiles
// lib/services/diag_report.dart
//
// Turns the raw diagnostic log (diag_log.dart: one line per GPS fix, per mile step,
// per engine start...) into a short report a person can read (2026-11-24). The raw
// file stays on the phone; this is what Settings sends.
//
// One block per trip: when, how far, the route thinned to about one point a minute,
// every GPS gap while moving (with the place's name when it falls inside a known zone,
// assets/map/gps_zones.json), rejected ticks and how the trip ended. Lines that are
// only noise (every fix, every mile step, engine start/stop, wake-ups) become counts.
// Lines the report does not know are kept as they are: they are the ones worth reading.
//
// Gaps that match no zone are listed at the end with their coordinates: that list is
// how the map's zone list grows with each diagnostic.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

class GpsZone {
  final String name;
  final String kind;
  final double lat;
  final double lng;
  final double radiusM;
  const GpsZone({
    required this.name,
    required this.kind,
    required this.lat,
    required this.lng,
    required this.radiusM,
  });

  factory GpsZone.fromJson(Map<String, dynamic> j) => GpsZone(
    name: j['name'] as String,
    kind: (j['kind'] as String?) ?? 'zone',
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    radiusM: (j['radius_m'] as num).toDouble(),
  );
}

class _Fix {
  final DateTime t;
  final double lat, lng, speed;
  final bool running;
  _Fix(this.t, this.lat, this.lng, this.speed, this.running);
}

class _Gap {
  final _Fix from, to;
  final double straightMiles;
  double? countedMiles;
  String? zone;
  _Gap(this.from, this.to, this.straightMiles);
}

class _Trip {
  final String session, app;
  final bool auto;
  final DateTime start;
  DateTime? end;
  double? miles;
  bool discarded = false;
  String startFrom = '';
  String? endReason;
  int wakeIgnored = 0;
  final List<_Fix> fixes = [];
  final List<_Gap> gaps = [];
  final Map<String, int> rejects = {};
  _Trip(this.session, this.app, this.auto, this.start);
}

class DiagReport {
  DiagReport._();

  /// A gap counts when the phone was silent this long AND had moved at least this far.
  /// A red light has the first without the second.
  static const gapSeconds = 120;
  static const gapMiles = 0.25;

  static final _line = RegExp(
    r'^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}:\d{2})(?:\.\d+)? \[\w+:\w+\] (.*)$',
  );
  static final _fix = RegExp(
    r'^fix lat=(-?[\d.]+) lng=(-?[\d.]+) v=([\d.]+) acc=[\d.]+ mock=\w+ state=(\w+)',
  );
  static final _start = RegExp(
    r'^trip started session=(\w+) app=(\S+) auto=(\w+)',
  );
  static final _stop = RegExp(r'^trip stopped discarded=(\w+) miles=([\d.]+)');
  static final _reject = RegExp(r'^tick rejected why=(.*)$');
  static final _milesAdd = RegExp(r'^miles add=([\d.]+)');
  static final _startPoint = RegExp(r'^trip start point from=(\w+)');

  // Lines that carry no news on their own: counted, never listed.
  static const _noisePrefixes = [
    'engine ',
    'startup ',
    'dashboard ',
    'wake ',
    'auto-start',
    'trip start point',
    'trip still for',
    'miles add=',
    'fix lat=',
  ];

  static Future<List<GpsZone>> loadZones() async {
    try {
      final raw = await rootBundle.loadString('assets/map/gps_zones.json');
      final list = (jsonDecode(raw) as Map<String, dynamic>)['zones'] as List;
      return list
          .map((z) => GpsZone.fromJson(Map<String, dynamic>.from(z as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String build(
    String raw, {
    required String appVersion,
    required String device,
    List<GpsZone> zones = const [],
    int maxOtherLines = 40,
  }) {
    final trips = <_Trip>[];
    _Trip? open;
    var idleFixes = 0, wakes = 0, engineStarts = 0;
    final other = <String, int>{};
    DateTime? first, last;
    _Gap? pendingGap;

    for (final rawLine in const LineSplitter().convert(raw)) {
      final m = _line.firstMatch(rawLine);
      if (m == null) {
        if (rawLine.trim().isNotEmpty) {
          final key = '(unreadable) ${_cut(rawLine)}';
          other[key] = (other[key] ?? 0) + 1;
        }
        continue;
      }
      final t = DateTime.parse('${m.group(1)}T${m.group(2)}');
      first ??= t;
      last = t;
      final msg = m.group(3)!;

      final s = _start.firstMatch(msg);
      if (s != null) {
        open = _Trip(s.group(1)!, s.group(2)!, s.group(3) == 'true', t);
        trips.add(open);
        pendingGap = null;
        continue;
      }
      final e = _stop.firstMatch(msg);
      if (e != null) {
        if (open != null) {
          open.end = t;
          open.discarded = e.group(1) == 'true';
          open.miles = double.tryParse(e.group(2)!);
        }
        open = null;
        pendingGap = null;
        continue;
      }
      final f = _fix.firstMatch(msg);
      if (f != null) {
        final fix = _Fix(
          t,
          double.parse(f.group(1)!),
          double.parse(f.group(2)!),
          double.parse(f.group(3)!),
          f.group(4) == 'running',
        );
        if (open != null && fix.running) {
          if (open.fixes.isNotEmpty) {
            final prev = open.fixes.last;
            final secs = t.difference(prev.t).inSeconds;
            final miles = _miles(prev.lat, prev.lng, fix.lat, fix.lng);
            if (secs >= gapSeconds && miles >= gapMiles) {
              final gap = _Gap(prev, fix, miles)
                ..zone = _zoneFor(prev, fix, zones);
              open.gaps.add(gap);
              pendingGap = gap;
            }
          }
          open.fixes.add(fix);
        } else {
          idleFixes++;
        }
        continue;
      }
      final a = _milesAdd.firstMatch(msg);
      if (a != null) {
        // The step right after a gap is what the app really added for it.
        if (pendingGap != null) {
          pendingGap.countedMiles = double.tryParse(a.group(1)!);
          pendingGap = null;
        }
        continue;
      }
      final r = _reject.firstMatch(msg);
      if (r != null && open != null) {
        final why = r.group(1)!.trim();
        open.rejects[why] = (open.rejects[why] ?? 0) + 1;
        continue;
      }
      final sp = _startPoint.firstMatch(msg);
      if (sp != null && open != null) {
        open.startFrom = sp.group(1)!;
        continue;
      }
      if (msg.startsWith('trip still for') && open != null) {
        open.endReason = 'still for 5 minutes';
        continue;
      }
      if (msg.startsWith('wake ignored') && open != null) {
        open.wakeIgnored++;
        continue;
      }
      if (msg.startsWith('wake ')) {
        wakes++;
        continue;
      }
      if (msg.startsWith('engine start')) {
        engineStarts++;
        continue;
      }
      if (_noisePrefixes.any(msg.startsWith)) continue;

      // Not known: keep it (without the engine tag), counted if it repeats.
      final key = '${m.group(1)} ${_cut(msg)}';
      other[key] = (other[key] ?? 0) + 1;
    }

    final b = StringBuffer();
    final done = trips.where((t) => !t.discarded && t.miles != null).toList();
    final totalMiles = done.fold<double>(0, (sum, t) => sum + (t.miles ?? 0));
    final allGaps = trips.expand((t) => t.gaps).toList();
    final named = allGaps.where((g) => g.zone != null).length;
    final rejectTotals = <String, int>{};
    for (final t in trips) {
      t.rejects.forEach((k, v) => rejectTotals[k] = (rejectTotals[k] ?? 0) + v);
    }

    b.writeln('CONTROLMILES DIAGNOSTIC  app $appVersion  device $device');
    if (first != null && last != null) {
      b.writeln('Period (phone time): ${_stamp(first)} to ${_stamp(last)}');
    }
    b.writeln(
      'Trips: ${trips.length} (${done.length} saved, ${trips.length - done.length} discarded or unfinished), ${totalMiles.toStringAsFixed(1)} mi saved',
    );
    b.writeln(
      'GPS gaps while moving: ${allGaps.length} ($named in a known zone, ${allGaps.length - named} unnamed)',
    );
    if (rejectTotals.isNotEmpty) {
      b.writeln(
        'Rejected ticks: ${rejectTotals.entries.map((e) => '${e.value} ${e.key}').join(', ')}',
      );
    }
    b.writeln(
      'Background: $engineStarts GPS starts, $wakes wake-ups, $idleFixes fixes outside trips (not listed)',
    );

    var day = '';
    for (final t in trips) {
      final d = _date(t.start);
      if (d != day) {
        day = d;
        b.writeln();
        b.writeln('=== $d ===');
      }
      b.writeln(_tripHeader(t));
      final route = _thin(t.fixes);
      if (route.isNotEmpty) {
        b.writeln(
          '  route: ${route.map((x) => '${x.lat.toStringAsFixed(3)},${x.lng.toStringAsFixed(3)}').join(' > ')}',
        );
      }
      for (final g in t.gaps) {
        final secs = g.to.t.difference(g.from.t).inSeconds;
        final counted = g.countedMiles == null
            ? ''
            : ', ${g.countedMiles!.toStringAsFixed(2)} mi counted';
        b.writeln(
          '  GPS GAP ${_hm(g.from.t)}-${_hm(g.to.t)} (${_dur(secs)}): ${g.straightMiles.toStringAsFixed(2)} mi in a straight line$counted'
          ' | ${g.zone ?? 'unnamed place'}',
        );
      }
      if (t.rejects.isNotEmpty) {
        b.writeln(
          '  rejected: ${t.rejects.entries.map((e) => '${e.value} ${e.key}').join(', ')}',
        );
      }
      if (t.wakeIgnored > 0) {
        b.writeln('  wake-ups ignored (trip already open): ${t.wakeIgnored}');
      }
      if (t.endReason != null) b.writeln('  ended: ${t.endReason}');
    }

    final unnamed = allGaps.where((g) => g.zone == null).toList();
    if (unnamed.isNotEmpty) {
      b.writeln();
      b.writeln(
        '=== UNNAMED GPS GAPS (name them, then add them to assets/map/gps_zones.json) ===',
      );
      for (final g in unnamed) {
        b.writeln(
          '${_date(g.from.t)} ${_hm(g.from.t)}  ${_pt(g.from)} > ${_pt(g.to)}  ${g.straightMiles.toStringAsFixed(2)} mi',
        );
      }
    }

    if (other.isNotEmpty) {
      b.writeln();
      b.writeln('=== OTHER EVENTS (not recognised as routine) ===');
      var shown = 0;
      for (final e in other.entries) {
        if (shown++ >= maxOtherLines) {
          b.writeln('... ${other.length - maxOtherLines} more kinds not shown');
          break;
        }
        b.writeln('${e.value > 1 ? '${e.value}x ' : ''}${e.key}');
      }
    }
    return b.toString();
  }

  // ---- helpers ----

  static String _tripHeader(_Trip t) {
    final end = t.end;
    final span = end == null
        ? '${_hm(t.start)}-?'
        : '${_hm(t.start)}-${_hm(end)} (${end.difference(t.start).inMinutes} min)';
    final miles = t.miles == null
        ? 'open'
        : '${t.miles!.toStringAsFixed(1)} mi';
    final tags = [
      if (t.discarded) 'DISCARDED',
      t.app + (t.auto ? ' auto' : ' manual'),
      if (t.startFrom.isNotEmpty) 'start from ${t.startFrom}',
      'session ${t.session}',
    ].join(', ');
    return '$span  $miles  $tags';
  }

  /// About one point a minute, never more than 14 in a block.
  static List<_Fix> _thin(List<_Fix> fixes) {
    if (fixes.isEmpty) return const [];
    final out = <_Fix>[fixes.first];
    for (final f in fixes.skip(1)) {
      if (f.t.difference(out.last.t).inSeconds >= 60) out.add(f);
    }
    if (out.last != fixes.last) out.add(fixes.last);
    if (out.length <= 14) return out;
    final step = (out.length - 1) / 13;
    return [for (var i = 0; i < 14; i++) out[(i * step).round()]];
  }

  static String? _zoneFor(_Fix a, _Fix b, List<GpsZone> zones) {
    final midLat = (a.lat + b.lat) / 2, midLng = (a.lng + b.lng) / 2;
    for (final z in zones) {
      final r = z.radiusM / 1609.344;
      if (_miles(z.lat, z.lng, midLat, midLng) <= r ||
          _miles(z.lat, z.lng, a.lat, a.lng) <= r ||
          _miles(z.lat, z.lng, b.lat, b.lng) <= r) {
        return z.name;
      }
    }
    return null;
  }

  static double _miles(double lat1, double lng1, double lat2, double lng2) {
    const earth = 3958.8;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earth * math.asin(math.sqrt(h));
  }

  static String _pt(_Fix f) =>
      '${f.lat.toStringAsFixed(3)},${f.lng.toStringAsFixed(3)}';
  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _date(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)}';
  static String _hm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';
  static String _stamp(DateTime t) => '${_date(t)} ${_hm(t)}';
  static String _dur(int s) => s >= 60 ? '${s ~/ 60} min ${s % 60} s' : '$s s';
  static String _cut(String s) =>
      s.length > 160 ? '${s.substring(0, 160)}...' : s;
}
