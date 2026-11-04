// Olympus Mont Systems LLC - ControlMiles
// lib/services/work_places.dart
//
// "My work places" (2026-11-01, Gig Premium): places where the driver usually
// starts working (an airport, a restaurant zone, a depot). Stored ONLY on the
// phone (SharedPreferences) -- the list of places is never uploaded.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WorkPlace {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // meters

  /// What trips to/at this place are (an IrsPurposeCatalog id: 'work',
  /// 'business', 'charitable'...). null = a gig-work place from before this
  /// existed: reminders only, as always.
  final String? purpose;

  const WorkPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.purpose,
  });

  /// Purposes the driver can pick for a place, in display order.
  static const List<String> purposes = [
    'work',
    'business',
    'charitable',
    'medical',
    'education',
    'moving',
    'personal',
  ];

  /// Below ~150 m the OS geofences are unreliable (GPS error, Wi-Fi/cell
  /// positioning) and would fire late or not at all.
  static const double minRadius = 150;
  static const double defaultRadius = 200;
  static const double maxRadius = 1000;

  /// iOS keeps ~20 regions per app; Android 100. 20 fits both.
  static const int maxPlaces = 20;

  /// Geofence identifier prefix, so these never mix with any other geofence.
  static const String idPrefix = 'wp:';

  String get geofenceId => '$idPrefix$id';

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'lat': latitude,
        'lng': longitude,
        'radius': radius,
        'purpose': purpose,
      };

  static WorkPlace? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final lat = raw['lat'];
    final lng = raw['lng'];
    final radius = raw['radius'];
    if (id is! String || name is! String || lat is! num || lng is! num) return null;
    return WorkPlace(
      id: id,
      name: name,
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      radius: radius is num ? radius.toDouble().clamp(minRadius, maxRadius) : defaultRadius,
      purpose: raw['purpose'] is String && purposes.contains(raw['purpose']) ? raw['purpose'] as String : null,
    );
  }
}

class WorkPlaceStore {
  static const _kPlaces = 'work_places_v1';

  static Future<List<WorkPlace>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPlaces);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list.map(WorkPlace.fromJson).whereType<WorkPlace>().toList();
    } catch (_) {
      return [];
    }
  }

  static const _kAutoStart = 'work_places_auto_start';

  /// Opt-in: start the trip by itself on arriving at a place that has a
  /// purpose. Off unless the driver turns it on.
  static Future<bool> autoStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAutoStart) ?? false;
  }

  static Future<void> setAutoStart(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoStart, on);
  }

  static Future<void> save(List<WorkPlace> places) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPlaces, jsonEncode(places.map((p) => p.toJson()).toList()));
  }
}
