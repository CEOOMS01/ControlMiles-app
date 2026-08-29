// Olympus Mont Systems LLC - ControlMiles
// lib/models/vehicle.dart
//
// Modelo tipado para la tabla `vehicles`. Antes VehicleService/ProfileScreen/
// DashboardScreen pasaban `Map<String, dynamic>` crudo a mano (v['make'],
// v['id'], etc.) — mismo problema de tipado débil que se resolvió para gig
// apps en gig_app.dart.

class Vehicle {
  final String id;
  // CM-T#### -- added to the DB this same session (web admin panel work),
  // auto-generated on insert, null for any vehicle created before that
  // migration until it's touched again.
  final String? displayId;
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

  // Fleet Phase 5 -- live map. Written by update_vehicle_location (RPC),
  // never by the client directly. All null until the vehicle's first
  // fleet-trip GPS tick; a Gig vehicle never gets these written at all
  // (live location is fleet-only by design).
  final double? lastLatitude;
  final double? lastLongitude;
  final double? lastSpeed;
  final DateTime? lastLocationAt;

  // IRS Fase 3 (2026-08-28): "date vehicle placed in service" -- one of
  // the annual-summary fields the IRS recommends recording, per the
  // audit in [[project_controlmiles]]. Nullable, no backfill -- shown
  // in the exportable report when set, omitted when not.
  final DateTime? placedInServiceDate;

  // BUG FIX (2026-08-29): this column already existed in the DB (`vin
  // text`, nullable) but was never mapped or written by any Dart code --
  // confirmed via grep, zero references anywhere in lib/. Optional, not
  // required to add a vehicle. When set, the DB itself (see migration
  // 20260829010000) enforces that a new vehicle sharing this VIN can never
  // be added with an odometer lower than what ControlMiles already has on
  // record for that VIN -- fraud-prevention against deleting and
  // re-adding the same real car with an artificially low starting mileage.
  final String? vin;

  const Vehicle({
    required this.id,
    this.displayId,
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
    this.lastLatitude,
    this.lastLongitude,
    this.lastSpeed,
    this.lastLocationAt,
    this.placedInServiceDate,
    this.vin,
  });

  bool get isFleetVehicle => organizationId != null;
  bool get hasLiveLocation => lastLatitude != null && lastLongitude != null;

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
      displayId: map['display_id'] as String?,
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
      lastLatitude: _toDoubleOrNull(map['last_latitude']),
      lastLongitude: _toDoubleOrNull(map['last_longitude']),
      lastSpeed: _toDoubleOrNull(map['last_speed']),
      lastLocationAt: map['last_location_at'] != null
          ? DateTime.tryParse(map['last_location_at'] as String)
          : null,
      placedInServiceDate: map['placed_in_service_date'] != null
          ? DateTime.tryParse(map['placed_in_service_date'] as String)
          : null,
      vin: map['vin'] as String?,
    );
  }

  /// "Toyota Corolla" — usado en tarjetas/listas donde make+model van juntos.
  String get displayName => '$make $model'.trim();
}
