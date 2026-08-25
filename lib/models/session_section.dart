// Olympus Mont Systems LLC - ControlMiles
// lib/models/session_section.dart - VERSIÓN ALINEADA CON BASE DE DATOS v3

class SessionSection {
  final String id;
  final String sessionId;
  final String userId;
  final String gigApp;
  final String status;                    // 'active', 'paused', 'closed', 'switched'

  final DateTime startTime;
  final DateTime? endTime;

  // Millas y duración
  final double totalMiles;
  final int? totalDurationSeconds;

  // Coordenadas GPS
  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;

  // Imágenes de odómetro (campos que SÍ existen en la DB)
  final String? startOdometerImageUrl;
  final String? endOdometerImageUrl;

  // Valores numéricos de odómetro (útiles para reportes)
  final double? startOdometerValue;
  final double? endOdometerValue;

  // IRS (solo para gig_app = 'custom')
  final String? irsPurpose;

  // Campos opcionales para futuro / auditoría
  final String? sectionHash;

  // BUG FIX (pedido explícito): las millas trackeadas jamás se editan
  // directamente -- máxima seguridad del dato GPS. Si algo salió mal
  // (ej. "faltaron 5 millas"), el usuario deja una nota de texto libre acá
  // en vez de tocar totalMiles. Ver migración session_sections_add_notes.
  final String? notes;

  SessionSection({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.gigApp,
    this.status = 'active',
    required this.startTime,
    this.endTime,
    required this.totalMiles,
    this.totalDurationSeconds,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    this.startOdometerImageUrl,
    this.endOdometerImageUrl,
    this.startOdometerValue,
    this.endOdometerValue,
    this.irsPurpose,
    this.sectionHash,
    this.notes,
  });

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  /// BUG FIX: a missing lat/lng/odometer value must stay null, not become 0.0
  /// (0.0, 0.0) is a real coordinate (Null Island) — silently turning "no data"
  /// into a fake real-looking value corrupts any report/map that reads it.
  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  factory SessionSection.fromMap(Map<String, dynamic> map) {
    final gigAppValue = map['gig_app'];
    if (gigAppValue == null || gigAppValue.toString().isEmpty) {
      throw Exception('SessionSection ERROR: gig_app no puede ser null o vacío.');
    }

    final sectionStatus = map['section_status'] ?? 'active';
    final isPaused = sectionStatus == 'paused';
    final isClosed = sectionStatus == 'closed' || sectionStatus == 'switched';

    return SessionSection(
      id: map['id'] ?? '',
      sessionId: map['session_id'] ?? '',
      userId: map['user_id'] ?? '',
      gigApp: gigAppValue.toString(),
      status: sectionStatus,
      startTime: map['start_time'] != null
          ? DateTime.parse(map['start_time']).toLocal()
          : DateTime.now(),
      endTime: map['end_time'] != null
          ? DateTime.parse(map['end_time']).toLocal()
          : null,
      totalMiles: _toDouble(map['total_miles']),
      totalDurationSeconds: map['total_duration_seconds'] as int?,
      startLatitude: _toDoubleOrNull(map['start_latitude']),
      startLongitude: _toDoubleOrNull(map['start_longitude']),
      endLatitude: _toDoubleOrNull(map['end_latitude']),
      endLongitude: _toDoubleOrNull(map['end_longitude']),
      startOdometerImageUrl: map['start_odometer_image_url'],
      endOdometerImageUrl: map['end_odometer_image_url'],
      startOdometerValue: _toDoubleOrNull(map['start_odometer_value']),
      endOdometerValue: _toDoubleOrNull(map['end_odometer_value']),
      irsPurpose: map['irs_purpose'],
      sectionHash: map['section_hash'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'user_id': userId,
      'gig_app': gigApp,
      'section_status': status,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'total_miles': totalMiles,
      'total_duration_seconds': totalDurationSeconds,
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'end_latitude': endLatitude,
      'end_longitude': endLongitude,
      'start_odometer_image_url': startOdometerImageUrl,
      'end_odometer_image_url': endOdometerImageUrl,
      'irs_purpose': irsPurpose,
      'section_hash': sectionHash,
      'notes': notes,
    };
  }

  SessionSection copyWith({
    String? status,
    DateTime? endTime,
    double? totalMiles,
    int? totalDurationSeconds,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
    String? startOdometerImageUrl,
    String? endOdometerImageUrl,
    String? irsPurpose,
    String? sectionHash,
    String? gigApp,
    String? notes,
    bool clearNotes = false,
  }) {
    return SessionSection(
      id: id,
      sessionId: sessionId,
      userId: userId,
      gigApp: gigApp ?? this.gigApp,
      status: status ?? this.status,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      totalMiles: totalMiles ?? this.totalMiles,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      // BUG FIX: startLatitude/startLongitude were never real copyWith params
      // before — the bare identifiers just silently resolved to `this.x`,
      // so callers had no way to ever set them. Now they're real params.
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      startOdometerImageUrl: startOdometerImageUrl ?? this.startOdometerImageUrl,
      endOdometerImageUrl: endOdometerImageUrl ?? this.endOdometerImageUrl,
      irsPurpose: irsPurpose ?? this.irsPurpose,
      sectionHash: sectionHash ?? this.sectionHash,
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  // Getters útiles
  double get miles => totalMiles;
  String get appGig => gigApp;

  /// Duración en segundos de esta sección (funciona tanto activa como cerrada)
  int get durationSeconds {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inSeconds;
  }

  bool get isPaused => status == 'paused';
  bool get isClosed => status == 'closed' || status == 'switched';

  /// Net duration in seconds, excluding paused time when available.
  /// Sections closed before pause-aware total_duration_seconds was
  /// persisted are stuck at 0 despite having a real trip length — 0 is
  /// treated the same as "not set" and falls back to durationSeconds
  /// (raw start→end wall-clock difference) for those legacy rows.
  int get effectiveDurationSeconds {
    if (totalDurationSeconds != null && totalDurationSeconds! > 0) {
      return totalDurationSeconds!;
    }
    return durationSeconds;
  }
}