// Olympus Mont Systems LLC - ControlMiles
// lib/models/vehicle_geofence.dart
//
// Fleet Phase 5: v1 geofence is a circle (center + radius), not a polygon --
// no PostGIS needed, matches the plain Haversine math already used in
// tracking_controller.dart. Violation detection happens server-side in
// update_vehicle_location, never in this model.

class VehicleGeofence {
  final String id;
  final String vehicleId;
  final String organizationId;
  final String name;
  final double centerLatitude;
  final double centerLongitude;
  final double radiusMeters;
  final bool isActive;
  final DateTime? createdAt;

  const VehicleGeofence({
    required this.id,
    required this.vehicleId,
    required this.organizationId,
    required this.name,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusMeters,
    this.isActive = true,
    this.createdAt,
  });

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory VehicleGeofence.fromMap(Map<String, dynamic> map) {
    return VehicleGeofence(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      organizationId: map['organization_id'] as String,
      name: map['name'] as String? ?? '',
      centerLatitude: _toDouble(map['center_latitude']),
      centerLongitude: _toDouble(map['center_longitude']),
      radiusMeters: _toDouble(map['radius_meters']),
      isActive: map['is_active'] == true,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
    );
  }
}

class GeofenceAlert {
  final String id;
  final String vehicleId;
  final String geofenceId;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final DateTime createdAt;

  const GeofenceAlert({
    required this.id,
    required this.vehicleId,
    required this.geofenceId,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.createdAt,
  });

  factory GeofenceAlert.fromMap(Map<String, dynamic> map) {
    return GeofenceAlert(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      geofenceId: map['geofence_id'] as String,
      latitude: VehicleGeofence._toDouble(map['latitude']),
      longitude: VehicleGeofence._toDouble(map['longitude']),
      distanceMeters: VehicleGeofence._toDouble(map['distance_meters']),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
