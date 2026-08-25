// Olympus Mont Systems LLC - ControlMiles
// lib/models/vehicle_inspection.dart
//
// Fleet Phase 4: DVIR-style pre/post-trip inspection checklist. v1 = one
// submission per inspection (immutable, like audit_events), pass/fail per
// category with an optional defect photo. Does NOT block trip start yet --
// see tracking_controller.dart's own comment on that deliberate scope cut.

import 'package:flutter/material.dart';

class InspectionCategory {
  final String id;
  final String labelKey;
  final IconData icon;

  const InspectionCategory({required this.id, required this.labelKey, required this.icon});

  // Conservador, mismo criterio que MaintenanceType: solo íconos estables y
  // muy comunes de Material Icons (ver comentario en maintenance_record.dart).
  static const List<InspectionCategory> all = [
    InspectionCategory(id: 'tires_wheels', labelKey: 'inspection_category_tires_wheels', icon: Icons.album_rounded),
    InspectionCategory(id: 'brakes', labelKey: 'inspection_category_brakes', icon: Icons.stop_circle_rounded),
    InspectionCategory(id: 'lights_signals', labelKey: 'inspection_category_lights_signals', icon: Icons.lightbulb_rounded),
    InspectionCategory(id: 'mirrors', labelKey: 'inspection_category_mirrors', icon: Icons.visibility_rounded),
    InspectionCategory(id: 'windshield_wipers', labelKey: 'inspection_category_windshield_wipers', icon: Icons.grain_rounded),
    InspectionCategory(id: 'horn', labelKey: 'inspection_category_horn', icon: Icons.campaign_rounded),
    InspectionCategory(id: 'steering', labelKey: 'inspection_category_steering', icon: Icons.explore_rounded),
    InspectionCategory(id: 'fluid_leaks', labelKey: 'inspection_category_fluid_leaks', icon: Icons.opacity_rounded),
    InspectionCategory(id: 'seatbelts', labelKey: 'inspection_category_seatbelts', icon: Icons.airline_seat_recline_normal_rounded),
    InspectionCategory(id: 'body_damage', labelKey: 'inspection_category_body_damage', icon: Icons.report_problem_rounded),
    InspectionCategory(id: 'other', labelKey: 'inspection_category_other', icon: Icons.build_rounded),
  ];
}

enum InspectionItemStatus { ok, defect }

class InspectionItem {
  final String category;
  final InspectionItemStatus status;
  final String? note;
  final String? photoUrl;

  const InspectionItem({
    required this.category,
    required this.status,
    this.note,
    this.photoUrl,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'status': status == InspectionItemStatus.defect ? 'defect' : 'ok',
        if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
        if (photoUrl != null) 'photo_url': photoUrl,
      };

  factory InspectionItem.fromJson(Map<String, dynamic> json) {
    return InspectionItem(
      category: json['category'] as String? ?? 'other',
      status: json['status'] == 'defect' ? InspectionItemStatus.defect : InspectionItemStatus.ok,
      note: json['note'] as String?,
      photoUrl: json['photo_url'] as String?,
    );
  }
}

class VehicleInspection {
  final String id;
  final String vehicleId;
  final String userId;
  final String? organizationId;
  final String inspectionType; // 'pre_trip' | 'post_trip'
  final String overallStatus; // 'pass' | 'fail'
  final List<InspectionItem> items;
  final double? odometer;
  final DateTime createdAt;

  const VehicleInspection({
    required this.id,
    required this.vehicleId,
    required this.userId,
    this.organizationId,
    required this.inspectionType,
    required this.overallStatus,
    required this.items,
    this.odometer,
    required this.createdAt,
  });

  bool get isPass => overallStatus == 'pass';

  factory VehicleInspection.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    final itemsList = (rawItems is List)
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(InspectionItem.fromJson)
            .toList()
        : <InspectionItem>[];

    final rawOdometer = map['odometer'];
    return VehicleInspection(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      userId: map['user_id'] as String,
      organizationId: map['organization_id'] as String?,
      inspectionType: map['inspection_type'] as String? ?? 'pre_trip',
      overallStatus: map['overall_status'] as String? ?? 'pass',
      items: itemsList,
      odometer: rawOdometer == null
          ? null
          : (rawOdometer is num ? rawOdometer.toDouble() : double.tryParse(rawOdometer.toString())),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
