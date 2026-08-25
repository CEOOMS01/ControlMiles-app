// Olympus Mont Systems LLC - ControlMiles
// lib/services/geofence_service.dart
//
// Fleet Phase 5: CRUD for vehicle_geofences (direct table RLS, admin/owner
// only -- same pattern as OrganizationService's own writes) + read-only
// access to vehicle_geofence_alerts (admin-only SELECT policy, no direct
// writer at all -- only update_vehicle_location's RPC can insert one).

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vehicle_geofence.dart';

class GeofenceService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<VehicleGeofence>> listForVehicle(String vehicleId) async {
    final data = await _supabase
        .from('vehicle_geofences')
        .select()
        .eq('vehicle_id', vehicleId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data).map(VehicleGeofence.fromMap).toList();
  }

  Future<VehicleGeofence> createGeofence({
    required String vehicleId,
    required String organizationId,
    required String name,
    required double centerLatitude,
    required double centerLongitude,
    required double radiusMeters,
  }) async {
    final data = await _supabase
        .from('vehicle_geofences')
        .insert({
          'vehicle_id': vehicleId,
          'organization_id': organizationId,
          'name': name,
          'center_latitude': centerLatitude,
          'center_longitude': centerLongitude,
          'radius_meters': radiusMeters,
          'created_by': _supabase.auth.currentUser?.id,
        })
        .select()
        .single();
    return VehicleGeofence.fromMap(data);
  }

  Future<void> setActive(String geofenceId, bool isActive) async {
    await _supabase.from('vehicle_geofences').update({'is_active': isActive}).eq('id', geofenceId);
  }

  Future<void> deleteGeofence(String geofenceId) async {
    await _supabase.from('vehicle_geofences').delete().eq('id', geofenceId);
  }

  Future<List<GeofenceAlert>> listRecentAlerts(String organizationId, {int limit = 50}) async {
    final data = await _supabase
        .from('vehicle_geofence_alerts')
        .select()
        .eq('organization_id', organizationId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data).map(GeofenceAlert.fromMap).toList();
  }
}
