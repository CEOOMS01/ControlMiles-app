// Olympus Mont Systems LLC - ControlMiles
// lib/services/school_route_service.dart
//
// School transportation (2026-10-09). The driver's school routes for today
// and the daily run: start (tied to the open trip), arrive at stops, mark
// students on/off, finish with the "no child left on board" check. All
// rules live in the database (migration 20261009100000_school_transportation);
// this is a thin client over its RPCs. Stop arrivals are also marked by the
// server from the bus's live location, so they happen with the phone locked.

import 'package:supabase_flutter/supabase_flutter.dart';

class SchoolStudent {
  final String id;
  final String name;
  final String? grade;
  final String action; // board | alight
  final bool done;

  /// Day status computed by the server (migration 20261009130000):
  /// blue = on track; red = alert (rode this morning but hasn't come out,
  /// or not dropped off); yellow = didn't ride this morning / absent;
  /// gray = red resolved with a reason; expected | pending | on_board =
  /// not decided yet.
  final String status;
  final String? releaseReason; // parent_pickup | early_dismissal | activity | other
  final String? releaseNote;

  const SchoolStudent({
    required this.id,
    required this.name,
    this.grade,
    required this.action,
    required this.done,
    required this.status,
    this.releaseReason,
    this.releaseNote,
  });

  bool get settled => status == 'yellow' || status == 'gray';

  factory SchoolStudent.fromJson(Map<String, dynamic> j) => SchoolStudent(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        grade: j['grade'] as String?,
        action: (j['action'] as String?) ?? 'board',
        done: (j['done'] as bool?) ?? false,
        status: (j['status'] as String?) ?? (((j['done'] as bool?) ?? false) ? 'blue' : 'pending'),
        releaseReason: j['release_reason'] as String?,
        releaseNote: j['release_note'] as String?,
      );
}

class SchoolStop {
  final String id;
  final int seq;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final String? scheduledTime; // HH:MM:SS fleet local time
  final String kind; // pickup | school | dropoff
  final DateTime? arrivedAt;
  final List<SchoolStudent> students;

  const SchoolStop({
    required this.id,
    required this.seq,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.scheduledTime,
    required this.kind,
    this.arrivedAt,
    required this.students,
  });

  bool get arrived => arrivedAt != null;

  /// Nobody to pick up or drop off here today (every rider absent or
  /// released): the driver can go straight past it.
  bool get skippable => students.isNotEmpty && students.every((st) => st.settled);

  factory SchoolStop.fromJson(Map<String, dynamic> j) => SchoolStop(
        id: j['id'] as String,
        seq: (j['seq'] as num).toInt(),
        name: (j['name'] as String?) ?? '',
        address: j['address'] as String?,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        radiusMeters: (j['radius_meters'] as num?)?.toInt() ?? 80,
        scheduledTime: j['scheduled_time'] as String?,
        kind: (j['stop_kind'] as String?) ?? 'pickup',
        arrivedAt: j['arrived_at'] == null ? null : DateTime.parse(j['arrived_at'] as String),
        students: ((j['students'] as List?) ?? const [])
            .map((s) => SchoolStudent.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList(),
      );
}

class SchoolRoute {
  final String id;
  final String name;
  final String routeType; // school_am | school_pm
  final String? school;
  final String? scheduledStartTime;
  final String? runId;
  final String? runStatus; // in_progress | completed
  final List<SchoolStop> stops;

  const SchoolRoute({
    required this.id,
    required this.name,
    required this.routeType,
    this.school,
    this.scheduledStartTime,
    this.runId,
    this.runStatus,
    required this.stops,
  });

  bool get inProgress => runStatus == 'in_progress';
  bool get completed => runStatus == 'completed';

  /// First stop the bus hasn't reached yet (skippable stops passed over).
  SchoolStop? get nextStop {
    for (final s in stops) {
      if (!s.arrived && !s.skippable) return s;
    }
    return null;
  }

  /// Students currently on board (marked on minus marked off).
  int get onBoard {
    var n = 0;
    for (final s in stops) {
      for (final st in s.students) {
        if (st.done) n += st.action == 'board' ? 1 : -1;
      }
    }
    return n < 0 ? 0 : n;
  }

  /// Red alerts the driver must clear before finishing (board them or give
  /// a reason). A PM rider still "expected" counts too: finishing would turn
  /// them red (the server refuses with UNRESOLVED_STUDENTS).
  int get unresolved {
    var n = 0;
    for (final s in stops) {
      n += s.students
          .where((st) => st.action == 'board' && (st.status == 'red' || st.status == 'expected'))
          .length;
    }
    return n;
  }

  factory SchoolRoute.fromJson(Map<String, dynamic> j) {
    final run = j['run'] as Map?;
    return SchoolRoute(
      id: j['id'] as String,
      name: (j['name'] as String?) ?? '',
      routeType: (j['route_type'] as String?) ?? 'school_am',
      school: j['school'] as String?,
      scheduledStartTime: j['scheduled_start_time'] as String?,
      runId: run?['id'] as String?,
      runStatus: run?['status'] as String?,
      stops: ((j['stops'] as List?) ?? const [])
          .map((s) => SchoolStop.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }
}

class SchoolRouteService {
  final _db = Supabase.instance.client;

  Future<List<SchoolRoute>> myRoutesToday(String organizationId) async {
    final res = await _db.rpc('my_school_routes_today', params: {'p_organization_id': organizationId});
    if (res is! List) return const [];
    return res.map((r) => SchoolRoute.fromJson(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<String> startRun(String routeId, String sessionId) async {
    final id = await _db.rpc('start_route_run', params: {'p_route_id': routeId, 'p_session_id': sessionId});
    return id as String;
  }

  Future<void> markArrived(String runId, String stopId) =>
      _db.rpc('mark_stop_arrived', params: {'p_run_id': runId, 'p_stop_id': stopId});

  /// [action] board | alight | released (released needs a [reason]).
  Future<void> setRider(String runId, String stopId, String studentId, String action, bool done,
          {String? reason, String? note}) =>
      _db.rpc('record_ridership', params: {
        'p_run_id': runId,
        'p_stop_id': stopId,
        'p_student_id': studentId,
        'p_action': action,
        'p_done': done,
        'p_reason': reason,
        'p_note': note,
      });

  Future<void> complete(String runId, {double? latitude, double? longitude}) =>
      _db.rpc('complete_route_run', params: {
        'p_run_id': runId,
        'p_child_check': true,
        'p_latitude': latitude,
        'p_longitude': longitude,
      });
}
