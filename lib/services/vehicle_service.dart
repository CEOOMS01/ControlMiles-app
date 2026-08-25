// Olympus Mont Systems LLC - ControlMiles
// lib/services/vehicle_service.dart
//
// Fuente única de verdad para CRUD de `vehicles`. Antes de este archivo,
// Dashboard y Profile tenían cada uno su propia copia de insert/delete con
// reglas distintas (Dashboard validaba todos los campos, Profile no
// validaba nada) — mismo problema de "consistencia en la base de datos"
// que este servicio resuelve al ser el único punto de escritura.
//
// También centraliza el manejo de is_active/is_primary: solo puede haber
// un vehículo activo por usuario a la vez. Ambas columnas se mantienen
// sincronizadas (no se les da un significado distinto todavía porque
// ningún código previo las usaba con una semántica separada).
//
// BUG FIX (pedido explícito, verificado en DB): "eliminar" un vehículo
// nunca hace un DELETE físico. sessions.vehicle_id referencia vehicles(id)
// con ON DELETE SET NULL — un DELETE real dejaba sin vehículo asociado a
// TODO el historial de viajes que lo usó, dato perdido para siempre en
// reportes de 3+ años ante el IRS. "Eliminar" ahora es un UPDATE
// (is_archived = true); la fila y el historial que la referencia quedan
// intactos. listVehicles()/getActiveVehicle() excluyen archivados.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vehicle.dart';

class VehicleService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Vehicle>> listVehicles(String userId) async {
    final data = await _supabase
        .from('vehicles')
        .select()
        .eq('owner_user_id', userId)
        .eq('is_archived', false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data)
        .map(Vehicle.fromMap)
        .toList();
  }

  /// Vehículo marcado como activo (is_active = true). Si por alguna
  /// inconsistencia histórica hay más de uno, se toma el más reciente.
  Future<Vehicle?> getActiveVehicle(String userId) async {
    final data = await _supabase
        .from('vehicles')
        .select()
        .eq('owner_user_id', userId)
        .eq('is_active', true)
        .eq('is_archived', false)
        .order('created_at', ascending: false)
        .limit(1);
    final list = List<Map<String, dynamic>>.from(data);
    return list.isNotEmpty ? Vehicle.fromMap(list.first) : null;
  }

  /// Lanza Exception con mensaje en español listo para mostrar en un
  /// SnackBar — mismo patrón usado en odometer_capture_service.dart.
  void _validate({
    required String make,
    required String model,
    required String color,
    required int? year,
    required double? odometer,
  }) {
    if (make.trim().isEmpty || model.trim().isEmpty || color.trim().isEmpty) {
      throw Exception('Todos los campos son obligatorios.');
    }
    final currentYear = DateTime.now().year;
    if (year == null || year < 1980 || year > currentYear + 1) {
      throw Exception('Año de vehículo inválido.');
    }
    if (odometer == null || odometer < 0) {
      throw Exception('El odómetro no puede ser negativo o estar vacío.');
    }
  }

  Future<void> addVehicle({
    required String userId,
    required String make,
    required String model,
    required String color,
    required int? year,
    required double? odometer,
    required bool setAsActive,
  }) async {
    _validate(make: make, model: model, color: color, year: year, odometer: odometer);

    if (setAsActive) {
      await _clearActiveFlags(userId);
    }

    await _supabase.from('vehicles').insert({
      'owner_user_id': userId,
      'make': make.trim(),
      'model': model.trim(),
      'color': color.trim(),
      'year': year,
      'odometer': odometer,
      'is_active': setAsActive,
      'is_primary': setAsActive,
    });
  }

  // BUG FIX (pedido explícito, hallazgo encontrado al implementar la
  // regla de "no cambiar de auto con sesión activa"): antes esto hacía
  // dos updates secuenciales desde el cliente (desactivar todos, luego
  // activar el nuevo) sin transacción -- si la conexión se caía justo
  // entre los dos pasos, el usuario se quedaba sin NINGÚN vehículo
  // activo. Ahora es un solo RPC atómico (set_active_vehicle en
  // Postgres, ambos updates en una transacción). El mismo RPC además
  // queda protegido automáticamente por el trigger
  // tr_vehicles_block_switch_during_session -- lanza excepción si el
  // usuario tiene una sesión sin cerrar, sin que este archivo tenga que
  // duplicar ese chequeo.
  Future<void> setActiveVehicle(String userId, String vehicleId) async {
    await _supabase.rpc('set_active_vehicle', params: {'p_vehicle_id': vehicleId});
  }

  Future<void> _clearActiveFlags(String userId) async {
    await _supabase
        .from('vehicles')
        .update({'is_active': false, 'is_primary': false})
        .eq('owner_user_id', userId)
        .eq('is_archived', false);
  }

  /// "Eliminar" un vehículo desde la UI. Ya NO hace DELETE — archiva (ver
  /// comentario de cabecera). Al archivar el vehículo activo, si quedan
  /// otros no archivados, promueve el más reciente a activo automáticamente
  /// — así Dashboard no vuelve a mostrar "Add Vehicle" teniendo el usuario
  /// otros vehículos guardados.
  Future<void> deleteVehicle(String userId, String vehicleId) async {
    await _supabase
        .from('vehicles')
        .update({'is_archived': true, 'is_active': false, 'is_primary': false})
        .eq('id', vehicleId);

    final remaining = await listVehicles(userId);
    if (remaining.isNotEmpty && !remaining.any((v) => v.isActive)) {
      await setActiveVehicle(userId, remaining.first.id);
    }
  }
}
