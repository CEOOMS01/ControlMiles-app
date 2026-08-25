// Olympus Mont Systems LLC - ControlMiles
// lib/services/maintenance_service.dart
//
// CRUD de `vehicle_maintenance_records` (nuevo módulo de mantenimiento de
// vehículo — cambio de aceite, etc.). v1 = registro/historial, sin
// notificaciones automáticas (ver comentario de la migración
// create_vehicle_maintenance_records).

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/maintenance_record.dart';

class MaintenanceService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<MaintenanceRecord>> listRecords(String vehicleId) async {
    final data = await _supabase
        .from('vehicle_maintenance_records')
        .select()
        .eq('vehicle_id', vehicleId)
        .order('performed_at', ascending: false);
    return List<Map<String, dynamic>>.from(data)
        .map(MaintenanceRecord.fromMap)
        .toList();
  }

  void _validate({
    required String type,
    required DateTime? performedAt,
  }) {
    if (!MaintenanceType.all.any((t) => t.id == type)) {
      throw Exception('Tipo de mantenimiento inválido.');
    }
    if (performedAt == null) {
      throw Exception('La fecha de servicio es obligatoria.');
    }
  }

  Future<void> addRecord({
    required String userId,
    required String vehicleId,
    required String type,
    required DateTime performedAt,
    double? odometerAtService,
    double? nextDueOdometer,
    DateTime? nextDueDate,
    double? cost,
    String? notes,
  }) async {
    _validate(type: type, performedAt: performedAt);

    await _supabase.from('vehicle_maintenance_records').insert({
      'user_id': userId,
      'vehicle_id': vehicleId,
      'type': type,
      'performed_at': _dateOnly(performedAt),
      'odometer_at_service': odometerAtService,
      'next_due_odometer': nextDueOdometer,
      'next_due_date': nextDueDate != null ? _dateOnly(nextDueDate) : null,
      'cost': cost,
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
    });
  }

  Future<void> deleteRecord(String recordId) async {
    await _supabase.from('vehicle_maintenance_records').delete().eq('id', recordId);
  }

  /// Postgres `date` espera YYYY-MM-DD — sin hora/timezone, para no
  /// arrastrar el problema de "medianoche UTC cae en el día anterior en
  /// hora local" que ya se evitó en otras partes de la app.
  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
