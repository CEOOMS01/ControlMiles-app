// Olympus Mont Systems LLC - ControlMiles
// lib/models/tracking_session.dart - PRODUCTION MODEL

class TrackingSession {
  final String id;
  final String? userId;
  final DateTime? startTime;
  final DateTime? endTime;
  final double totalMiles;
  final int? totalDurationSeconds;
  final String? vehicleId;
  final String? sessionHash;
  final bool isClosed;
  final String? dateKey;
  // CGC Core governance sealing (see cgc_governance_service.dart): set
  // once /governance/decision returns a real decision_id for this trip's
  // antifraud verdict -- an independent, cryptographically-sealed proof
  // this codebase's own client-side hash chain can't provide by itself.
  final String? cgcDecisionId;

  TrackingSession({
    required this.id,
    this.userId,
    this.startTime,
    this.endTime,
    required this.totalMiles,
    this.totalDurationSeconds,
    this.vehicleId,
    this.sessionHash,
    required this.isClosed,
    this.dateKey,
    this.cgcDecisionId,
  });

  /// Crea una sesión vacía para inicialización de UI
  factory TrackingSession.empty() {
    return TrackingSession(
      id: "none",
      userId: null,
      startTime: null,
      endTime: null,
      totalMiles: 0.0,
      totalDurationSeconds: null,
      vehicleId: null,
      sessionHash: null,
      isClosed: true,
      dateKey: null,
    );
  }

  /// Manejo seguro de tipos numéricos desde Supabase
  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory TrackingSession.fromMap(Map<String, dynamic> map) {
    return TrackingSession(
      id: map['id'],
      userId: map['user_id'],
      startTime: map['start_time'] != null
          ? DateTime.parse(map['start_time'])
          : null,
      endTime: map['end_time'] != null
          ? DateTime.parse(map['end_time'])
          : null,
      totalMiles: _toDouble(map['total_miles']),
      // BUG FIX: this column existed in `sessions` and is correctly persisted
      // by TrackingController.stopTracking() (pause-excluded net duration),
      // but the model never mapped it — every screen fell back to raw
      // endTime-startTime (which counts paused time as active) instead.
      totalDurationSeconds: map['total_duration_seconds'] as int?,
      // BUG FIX: sessions.vehicle_id existía en la DB pero ni el modelo lo
      // mapeaba ni ningún código lo escribía (0 de 7 sesiones lo tenían
      // seteado). Ahora TrackingController.startTripFlow() lo persiste al
      // crear la sesión, y el modelo lo mapea para que cualquier pantalla
      // pueda mostrarlo.
      vehicleId: map['vehicle_id'],
      sessionHash: map['session_hash'],
      isClosed: map['is_closed'] ?? false,
      dateKey: map['date_key'],
      cgcDecisionId: map['cgc_decision_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'total_miles': totalMiles,
      'total_duration_seconds': totalDurationSeconds,
      'vehicle_id': vehicleId,
      'session_hash': sessionHash,
      'is_closed': isClosed,
      'date_key': dateKey,
      'cgc_decision_id': cgcDecisionId,
    };
  }

  /// Útil para operaciones de UPDATE donde no queremos enviar el ID
  Map<String, dynamic> toUpdateMap() {
    final map = toMap();
    map.remove('id');
    return map;
  }

  TrackingSession copyWith({
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    double? totalMiles,
    int? totalDurationSeconds,
    String? vehicleId,
    String? sessionHash,
    bool? isClosed,
    String? dateKey,
    String? cgcDecisionId,
  }) {
    return TrackingSession(
      id: id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalMiles: totalMiles ?? this.totalMiles,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      vehicleId: vehicleId ?? this.vehicleId,
      sessionHash: sessionHash ?? this.sessionHash,
      isClosed: isClosed ?? this.isClosed,
      dateKey: dateKey ?? this.dateKey,
      cgcDecisionId: cgcDecisionId ?? this.cgcDecisionId,
    );
  }

  /// Net duration in seconds, excluding paused time when available.
  /// Some sessions were closed before pause-aware total_duration_seconds
  /// was persisted and are stuck at 0 despite having a real trip length —
  /// 0 is treated the same as "not set" and falls back to the raw
  /// start→end wall-clock difference for those legacy rows.
  int? get effectiveDurationSeconds {
    if (totalDurationSeconds != null && totalDurationSeconds! > 0) {
      return totalDurationSeconds;
    }
    if (startTime != null && endTime != null) {
      return endTime!.difference(startTime!).inSeconds;
    }
    return null;
  }
}