// Olympus Mont Systems LLC - ControlMiles
// lib/models/audit_event.dart - VERSIÓN MEJORADA

class AuditEvent {
  // ============================================================
  // FIELDS
  // ============================================================
  final String id;                    // UUID del evento
  final String userId;                // Usuario propietario del evento
  final String sessionId;             // ID de la sesión diaria
  final String? sectionId;            // ID de la sección (puede ser null)
  final String eventType;             // Tipo: SECTION_START, GPS_TICK, etc.
  final Map<String, dynamic> payload; // Datos adicionales (JSON)
  final String hash;                  // Hash SHA256 de este evento
  final String? prevHash;             // Hash del evento anterior (chain)
  final int eventIndex;               // Índice secuencial en la cadena
  final String? source;               // Fuente: 'app', 'api', 'system', etc.
  final DateTime createdAt;           // Timestamp de creación

  // ============================================================
  // CONSTRUCTOR
  // ============================================================
  AuditEvent({
    required this.id,
    required this.userId,
    required this.sessionId,
    this.sectionId,
    required this.eventType,
    required this.payload,
    required this.hash,
    this.prevHash,
    required this.eventIndex,
    this.source,
    required this.createdAt,
  });

  // ============================================================
  // FACTORY: FROM DATABASE MAP
  // ============================================================
  factory AuditEvent.fromMap(Map<String, dynamic> map) {
    return AuditEvent(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      sessionId: map['session_id'] as String,
      sectionId: map['section_id'] as String?,
      eventType: map['event_type'] as String,
      payload: Map<String, dynamic>.from(map['payload'] as Map),
      hash: map['hash'] as String,
      prevHash: map['prev_hash'] as String?,
      eventIndex: map['event_index'] as int,
      source: map['source'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // ============================================================
  // CONVERT TO MAP (para guardar en BD)
  // ============================================================
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'session_id': sessionId,
      'section_id': sectionId,
      'event_type': eventType,
      'payload': payload,
      'hash': hash,
      'prev_hash': prevHash,
      'event_index': eventIndex,
      'source': source,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // ============================================================
  // COPY WITH (para immutabilidad)
  // ============================================================
  AuditEvent copyWith({
    String? id,
    String? userId,
    String? sessionId,
    String? sectionId,
    String? eventType,
    Map<String, dynamic>? payload,
    String? hash,
    String? prevHash,
    int? eventIndex,
    String? source,
    DateTime? createdAt,
  }) {
    return AuditEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      sectionId: sectionId ?? this.sectionId,
      eventType: eventType ?? this.eventType,
      payload: payload ?? this.payload,
      hash: hash ?? this.hash,
      prevHash: prevHash ?? this.prevHash,
      eventIndex: eventIndex ?? this.eventIndex,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================
  
  /// Obtener descripción legible del tipo de evento
  String getEventTypeLabel() {
    final labels = {
      'SECTION_START': 'Sección Iniciada',
      'SECTION_PAUSE': 'Sección Pausada',
      'SECTION_RESUME': 'Sección Reanudada',
      'SECTION_END': 'Sección Finalizada',
      'GPS_TICK': 'Punto GPS Registrado',
      'GPS_REJECTED': 'GPS Rechazado',
      'EVIDENCE_START': 'Evidencia Inicial',
      'EVIDENCE_END': 'Evidencia Final',
      'HASH_CHAIN': 'Cadena de Hash',
      'ERROR': 'Error del Sistema',
    };
    return labels[eventType] ?? eventType;
  }

  /// Verificar integridad de la cadena (validar hash anterior)
  bool isChainValid(AuditEvent? previousEvent) {
    if (previousEvent == null) {
      // Primer evento no debe tener prevHash
      return prevHash == null;
    }
    // prevHash debe coincidir con hash del evento anterior
    return prevHash == previousEvent.hash;
  }

  @override
  String toString() {
    return 'AuditEvent('
        'id: $id, '
        'eventType: $eventType, '
        'index: $eventIndex, '
        'hash: ${hash.substring(0, 12)}..., '
        'createdAt: $createdAt'
        ')';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditEvent &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          hash == other.hash;

  @override
  int get hashCode => id.hashCode ^ hash.hashCode;
}