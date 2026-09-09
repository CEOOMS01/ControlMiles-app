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

import '../i18n/app_texts.dart';
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

  /// Fleet Phase 3: único punto de la decisión "qué vehículo usa este
  /// usuario para trackear ahora mismo" -- dashboard_screen.dart y
  /// tracking_controller.dart llaman ESTE método en vez de reimplementar
  /// la rama Gig/Fleet cada uno por su cuenta (exactamente el tipo de
  /// duplicidad de flujo que ya causó el bug de splash_page.dart en la
  /// Fase 2). organizationId != null (perfil fleet_driver) -> el vehículo
  /// asignado (assigned_driver_id), sin importar is_active (ese flag es
  /// un concepto puramente Gig -- un driver de flota no "cambia" entre
  /// autos propios, tiene el que su admin le asignó). organizationId ==
  /// null (Gig) -> el comportamiento existente de getActiveVehicle().
  /// Fleet Sprint 4 (open/rotating vehicle assignment, explicit user
  /// requirement, 2026-09-09): [preSelectedVehicleId] is only meaningful
  /// when organizationId's org has vehicle_assignment_mode='open' -- the
  /// driver picked it themselves this trip (FleetVehiclePickerScreen),
  /// it's not a standing assignment. Re-validated here (org match, not
  /// archived) rather than trusted blindly, since it crossed a whole UI
  /// screen before reaching this chokepoint.
  Future<Vehicle?> getActiveOrAssignedVehicle(
    String userId, {
    String? organizationId,
    String? preSelectedVehicleId,
  }) async {
    if (organizationId != null) {
      if (preSelectedVehicleId != null) {
        final data = await _supabase
            .from('vehicles')
            .select()
            .eq('id', preSelectedVehicleId)
            .eq('organization_id', organizationId)
            .eq('is_archived', false)
            .maybeSingle();
        return data != null ? Vehicle.fromMap(data) : null;
      }
      final data = await _supabase
          .from('vehicles')
          .select()
          .eq('assigned_driver_id', userId)
          .eq('organization_id', organizationId)
          .eq('is_archived', false)
          .maybeSingle();
      return data != null ? Vehicle.fromMap(data) : null;
    }
    return getActiveVehicle(userId);
  }

  /// 'fixed' (default) or 'open' -- admin-configured exclusively on the
  /// web dashboard (controlmiles-web /admin/settings), per the standing
  /// rule that heavy Fleet-admin configuration lives there, not in this
  /// app. Mobile only ever READS this value.
  Future<String> getVehicleAssignmentMode(String organizationId) async {
    final data = await _supabase
        .from('organizations')
        .select('vehicle_assignment_mode')
        .eq('id', organizationId)
        .maybeSingle();
    return (data?['vehicle_assignment_mode'] as String?) ?? 'fixed';
  }

  /// This org's vehicles a driver can pick from right now, in 'open'
  /// mode -- excludes anything currently claimed by another driver's
  /// still-open session, so two drivers never end up tracking the same
  /// vehicle at once. A vehicle the CALLER themselves has open stays
  /// excluded too (they'd resume via the normal in-progress-trip path,
  /// not by picking again).
  Future<List<Vehicle>> listAvailableFleetVehicles(String organizationId) async {
    final vehiclesData = await _supabase
        .from('vehicles')
        .select()
        .eq('organization_id', organizationId)
        .eq('is_archived', false)
        .order('display_id', ascending: true);

    final claimedData = await _supabase
        .from('sessions')
        .select('vehicle_id')
        .eq('organization_id', organizationId)
        .eq('is_closed', false);
    final claimedIds = List<Map<String, dynamic>>.from(claimedData)
        .map((s) => s['vehicle_id'] as String?)
        .whereType<String>()
        .toSet();

    return List<Map<String, dynamic>>.from(vehiclesData)
        .map(Vehicle.fromMap)
        .where((v) => !claimedIds.contains(v.id))
        .toList();
  }

  /// Lanza Exception con mensaje ya localizado -- mismo patrón usado en
  /// odometer_capture_service.dart (AppTexts.get(key, language.code)).
  /// BUG FIX (hardcoded-string audit): antes tiraba texto en español fijo,
  /// mostrado tal cual al usuario sin pasar por tr() -- un usuario en
  /// cualquier otro idioma veía estos 3 mensajes en español.
  void _validate({
    required String make,
    required String model,
    required String color,
    required int? year,
    required double? odometer,
    required AppLanguage language,
  }) {
    if (make.trim().isEmpty || model.trim().isEmpty || color.trim().isEmpty) {
      throw Exception(AppTexts.get('error_all_fields_required', language.code));
    }
    final currentYear = DateTime.now().year;
    if (year == null || year < 1980 || year > currentYear + 1) {
      throw Exception(AppTexts.get('error_invalid_vehicle_year', language.code));
    }
    if (odometer == null || odometer < 0) {
      throw Exception(AppTexts.get('error_odometer_negative_or_empty', language.code));
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
    required AppLanguage language,
    // IRS Fase 3 (2026-08-28): "date placed in service", one of the
    // annual-summary fields the IRS recommends recording. Optional --
    // there's no vehicle-edit flow (explicit user decision, see
    // vehicle_screen.dart's own header comment), so this can only ever
    // be set at creation time; the report shows it when present and
    // omits it otherwise.
    DateTime? placedInServiceDate,
    // Fraud-prevention (2026-08-29): optional. When set, the DB (trigger
    // fn_enforce_vehicle_odometer_floor, migration 20260829010000) blocks
    // this insert if `odometer` is below what ControlMiles already has on
    // record for another vehicle (active or archived) of this same user
    // sharing this VIN -- see that migration's own comment for why VIN is
    // required for this check and why there's no account-wide floor.
    String? vin,
  }) async {
    _validate(make: make, model: model, color: color, year: year, odometer: odometer, language: language);

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
      'placed_in_service_date': placedInServiceDate?.toIso8601String().split('T')[0],
      'vin': (vin == null || vin.trim().isEmpty) ? null : vin.trim().toUpperCase(),
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

  /// Suma de `sessions.total_miles` (GPS, ya cerradas) para este vehículo —
  /// usado por VehicleDetailScreen para mostrar "millas calculadas" junto
  /// a las lecturas de odómetro por foto (vehicle_odometer_checkpoints),
  /// sin mezclar ambas fuentes en una sola cifra (evidencia distinta, ver
  /// comentario de submit_vehicle_odometer_checkpoint).
  Future<double> totalTrackedMiles(String vehicleId) async {
    final data = await _supabase
        .from('sessions')
        .select('total_miles')
        .eq('vehicle_id', vehicleId)
        .eq('is_closed', true);
    return List<Map<String, dynamic>>.from(data).fold<double>(
      0.0,
      (sum, row) => sum + ((row['total_miles'] as num?)?.toDouble() ?? 0.0),
    );
  }
}
