// Olympus Mont Systems LLC - ControlMiles
// lib/models/vehicle.dart
//
// Modelo tipado para la tabla `vehicles`. Antes VehicleService/ProfileScreen/
// DashboardScreen pasaban `Map<String, dynamic>` crudo a mano (v['make'],
// v['id'], etc.) — mismo problema de tipado débil que se resolvió para gig
// apps en gig_app.dart.

class Vehicle {
  final String id;
  final String ownerUserId;
  final String make;
  final String model;
  final String? color;
  final int? year;
  final double? odometer;
  final bool isActive;
  final bool isArchived;
  final DateTime? createdAt;
  // Fleet Phase 2 -- both null for every Gig-mode vehicle (owner_user_id is
  // the relevant column there instead).
  final String? organizationId;
  final String? assignedDriverId;

  const Vehicle({
    required this.id,
    required this.ownerUserId,
    required this.make,
    required this.model,
    this.color,
    this.year,
    this.odometer,
    this.isActive = false,
    this.isArchived = false,
    this.createdAt,
    this.organizationId,
    this.assignedDriverId,
  });

  bool get isFleetVehicle => organizationId != null;

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'] as String,
      ownerUserId: map['owner_user_id'] as String? ?? '',
      make: map['make'] as String? ?? '',
      model: map['model'] as String? ?? '',
      color: map['color'] as String?,
      year: map['year'] as int?,
      odometer: _toDoubleOrNull(map['odometer']),
      isActive: map['is_active'] == true,
      isArchived: map['is_archived'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      organizationId: map['organization_id'] as String?,
      assignedDriverId: map['assigned_driver_id'] as String?,
    );
  }

  /// "Toyota Corolla" — usado en tarjetas/listas donde make+model van juntos.
  String get displayName => '$make $model'.trim();
}
