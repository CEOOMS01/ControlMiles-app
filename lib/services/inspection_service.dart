// Olympus Mont Systems LLC - ControlMiles
// lib/services/inspection_service.dart
//
// Fleet Phase 4: DVIR-style pre/post-trip inspections. Submission goes
// exclusively through submit_vehicle_inspection (SECURITY DEFINER) -- there
// is no direct INSERT policy on vehicle_inspections, so the auto-created
// maintenance record on a failed inspection can never be skipped by a
// direct table write. Reuses the same evidence bucket + file-size/extension
// validation as odometer_capture_service.dart, since these are the same
// class of "photo evidence attached to a vehicle event".

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/vehicle_inspection.dart';

class InspectionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> uploadDefectPhoto({required File file, required String category}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('No hay sesión activa.');
    }

    if (!AppConfig.isValidFileSize(file)) {
      throw Exception(
        'La foto pesa fuera de rango permitido (entre ${AppConfig.minPhotoSizeKb}KB y ${AppConfig.maxPhotoSizeMb}MB). Intenta tomarla de nuevo.',
      );
    }
    if (!AppConfig.isValidExtension(file.path)) {
      throw Exception(
        'Formato de imagen no soportado. Formatos permitidos: ${AppConfig.allowedImageFormats.join(', ')}.',
      );
    }

    final bytes = await file.readAsBytes();
    final fileName = 'inspection_${category}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = '${user.id}/$fileName';

    await _supabase.storage.from(AppConfig.evidenceBucket).uploadBinary(storagePath, bytes, retryAttempts: 3);

    return _supabase.storage.from(AppConfig.evidenceBucket).getPublicUrl(storagePath);
  }

  /// Envía la inspección completa. overall_status (pass/fail) se calcula
  /// server-side a partir de items -- ver submit_vehicle_inspection -- así
  /// que el cliente nunca decide ese veredicto por su cuenta.
  Future<VehicleInspection> submitInspection({
    required String vehicleId,
    required String inspectionType,
    required List<InspectionItem> items,
    double? odometer,
  }) async {
    final result = await _supabase.rpc('submit_vehicle_inspection', params: {
      'p_vehicle_id': vehicleId,
      'p_inspection_type': inspectionType,
      'p_items': items.map((i) => i.toJson()).toList(),
      'p_odometer': odometer,
    });
    return VehicleInspection.fromMap(Map<String, dynamic>.from(result as Map));
  }

  Future<List<VehicleInspection>> listInspections(String vehicleId) async {
    final data = await _supabase
        .from('vehicle_inspections')
        .select()
        .eq('vehicle_id', vehicleId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data).map(VehicleInspection.fromMap).toList();
  }
}
