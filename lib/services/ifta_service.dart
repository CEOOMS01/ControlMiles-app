// Olympus Mont Systems LLC - ControlMiles
// lib/services/ifta_service.dart
//
// Fleet Phase 6, piece 1: miles-per-state, computed server-side by
// compute_state_mileage from the GPS breadcrumb trail (see
// tracking_controller.dart's _smartSync). This is NOT a fileable IFTA
// return -- a real tax-due calculation also needs fuel gallons purchased
// per jurisdiction, which this app has no infrastructure for and which
// (per the controlmiles.com web platform plan) is expected to come from
// CGC Core's TCO module via a future cross-project integration, not from
// here.

import 'package:supabase_flutter/supabase_flutter.dart';

class StateMileage {
  final String stateCode;
  final String stateName;
  final double miles;

  const StateMileage({required this.stateCode, required this.stateName, required this.miles});

  factory StateMileage.fromMap(Map<String, dynamic> map) {
    return StateMileage(
      stateCode: map['state_code'] as String,
      stateName: map['state_name'] as String,
      miles: (map['miles'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class IftaService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<StateMileage>> computeStateMileage({
    required String organizationId,
    required DateTime start,
    required DateTime end,
    String? vehicleId,
  }) async {
    final data = await _supabase.rpc('compute_state_mileage', params: {
      'p_organization_id': organizationId,
      'p_start_date': _dateOnly(start),
      'p_end_date': _dateOnly(end),
      'p_vehicle_id': vehicleId,
    });
    return List<Map<String, dynamic>>.from(data).map(StateMileage.fromMap).toList();
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
