// Olympus Mont Systems LLC - ControlMiles
// lib/models/maintenance_record.dart
//
// Modelo tipado para `vehicle_maintenance_records` (nuevo módulo de
// mantenimiento — cambio de aceite, etc.). v1 = registro/historial +
// cálculo de "próximo" mostrado en pantalla, sin notificaciones automáticas
// (ver comentario en la migración create_vehicle_maintenance_records).

import 'package:flutter/material.dart';

class MaintenanceType {
  final String id;
  // Clave de i18n (appState.tr(labelKey)), no el texto — a diferencia de
  // GigAppCatalog (nombres de marca como "Uber" que no se traducen), estos
  // son términos genéricos ("Cambio de aceite") que sí deben localizarse.
  final String labelKey;
  final IconData icon;
  // Intervalo "de experto" (millas), usado como umbral por defecto para
  // el próximo servicio cuando el usuario no definió uno propio en
  // nextDueOdometer — explicit user requirement: "el cambio del auto sea
  // en base a lo que dice un experto o en base a la necesidad del
  // cliente". null para tipos cuyo vencimiento típico es por fecha, no
  // por millaje (inspection/registration), donde un número inventado
  // sería más engañoso que útil.
  final int? defaultIntervalMiles;

  const MaintenanceType({
    required this.id,
    required this.labelKey,
    required this.icon,
    this.defaultIntervalMiles,
  });

  // Íconos elegidos de forma conservadora — solo de los muy comunes/estables
  // de Material Icons (no de las series "oil_barrel"/"tire_repair"/
  // "disc_full", más nuevas y no confirmadas en todas las variantes
  // _rounded, para no repetir el problema de lucide_icons de esta sesión).
  //
  // defaultIntervalMiles: cifras genéricas de industria (no específicas de
  // marca/modelo, ControlMiles no tiene esa data) — 5,000 mi para aceite
  // convencional, 6,000-8,000 rotación de llantas, 12,000-15,000 frenos,
  // 30,000 batería. Puramente informativo, nunca bloquea nada.
  static const List<MaintenanceType> all = [
    MaintenanceType(id: 'oil_change', labelKey: 'maintenance_type_oil_change', icon: Icons.opacity_rounded, defaultIntervalMiles: 5000),
    MaintenanceType(id: 'tire_rotation', labelKey: 'maintenance_type_tire_rotation', icon: Icons.autorenew_rounded, defaultIntervalMiles: 6000),
    MaintenanceType(id: 'brake_service', labelKey: 'maintenance_type_brake_service', icon: Icons.stop_circle_rounded, defaultIntervalMiles: 12000),
    MaintenanceType(id: 'inspection', labelKey: 'maintenance_type_inspection', icon: Icons.checklist_rounded),
    MaintenanceType(id: 'registration', labelKey: 'maintenance_type_registration', icon: Icons.assignment_rounded),
    MaintenanceType(id: 'battery', labelKey: 'maintenance_type_battery', icon: Icons.battery_charging_full_rounded, defaultIntervalMiles: 30000),
    MaintenanceType(id: 'other', labelKey: 'maintenance_type_other', icon: Icons.build_rounded),
  ];

  static const MaintenanceType _fallback = MaintenanceType(
      id: 'other', labelKey: 'maintenance_type_other', icon: Icons.build_rounded);

  static MaintenanceType byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return _fallback;
  }
}

class MaintenanceRecord {
  final String id;
  final String vehicleId;
  final String userId;
  final String type;
  final DateTime performedAt;
  final double? odometerAtService;
  final double? nextDueOdometer;
  final DateTime? nextDueDate;
  final double? cost;
  final String? notes;
  final DateTime? createdAt;

  const MaintenanceRecord({
    required this.id,
    required this.vehicleId,
    required this.userId,
    required this.type,
    required this.performedAt,
    this.odometerAtService,
    this.nextDueOdometer,
    this.nextDueDate,
    this.cost,
    this.notes,
    this.createdAt,
  });

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static DateTime? _toDateOrNull(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v as String);
  }

  factory MaintenanceRecord.fromMap(Map<String, dynamic> map) {
    return MaintenanceRecord(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      userId: map['user_id'] as String? ?? '',
      type: map['type'] as String? ?? 'other',
      performedAt: DateTime.tryParse(map['performed_at'] as String? ?? '') ?? DateTime.now(),
      odometerAtService: _toDoubleOrNull(map['odometer_at_service']),
      nextDueOdometer: _toDoubleOrNull(map['next_due_odometer']),
      nextDueDate: _toDateOrNull(map['next_due_date']),
      cost: _toDoubleOrNull(map['cost']),
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
    );
  }

  MaintenanceType get typeMeta => MaintenanceType.byId(type);

  /// Umbral de millaje para el "próximo servicio" — explicit user
  /// requirement: usa el propio umbral del cliente si lo definió al
  /// registrar el servicio (nextDueOdometer), y si no, cae al intervalo
  /// "de experto" del tipo (MaintenanceType.defaultIntervalMiles) sumado
  /// al odómetro en que se hizo ESTE servicio. Null si no hay ninguno de
  /// los dos datos (tipo sin intervalo por defecto y sin odómetro
  /// registrado, o el tipo vence por fecha, no por millaje).
  double? get dueThresholdOdometer {
    if (nextDueOdometer != null) return nextDueOdometer;
    final base = odometerAtService;
    final interval = typeMeta.defaultIntervalMiles;
    if (base == null || interval == null) return null;
    return base + interval;
  }

  /// True cuando el umbral vino del cliente (nextDueOdometer explícito) en
  /// vez de calculado desde el intervalo de experto — usado por la UI para
  /// distinguir "tu umbral" de "recomendado" en el panel de mantenimiento.
  bool get dueThresholdIsCustom => nextDueOdometer != null;

  /// True si hay un umbral de millaje definido y el odómetro actual ya lo
  /// alcanzó o superó. Puramente informativo en v1 (no dispara nada).
  bool isDueByOdometer(double currentOdometer) {
    if (nextDueOdometer == null) return false;
    return currentOdometer >= nextDueOdometer!;
  }

  bool isDueByDate(DateTime now) {
    if (nextDueDate == null) return false;
    return !now.isBefore(nextDueDate!);
  }
}
