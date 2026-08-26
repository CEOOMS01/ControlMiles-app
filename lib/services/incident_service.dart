// Olympus Mont Systems LLC - ControlMiles
// lib/services/incident_service.dart
//
// Mid-trip incident reports (breakdown/accident/delay/other) -- a driver
// reporting something going wrong DURING an active trip, distinct from
// the DVIR checklist's own defect notes (which only cover the pre/post
// trip inspection moment). Fleet-only, same boundary as inspections.

import 'package:supabase_flutter/supabase_flutter.dart';

class IncidentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> reportIncident({
    required String organizationId,
    required String category,
    required String description,
    String? sessionId,
    String? vehicleId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _supabase.from('trip_incidents').insert({
      'user_id': user.id,
      'organization_id': organizationId,
      'category': category,
      'description': description,
      'session_id': sessionId,
      'vehicle_id': vehicleId,
    });
  }
}
