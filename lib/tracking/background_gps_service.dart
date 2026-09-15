// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/background_gps_service.dart
//
// PUBLIC FACADE -- delegates to TraceletEngine (free, active by default).
// Every existing caller in this codebase
// (main.dart, auto_trip_detection_service.dart, tracking_controller.dart)
// keeps calling BackgroundGpsService.initialize()/.startTracking()/
// .stopTracking()/.isRunning exactly as before -- unchanged since this
// facade existed, so nothing else needed touching.
//
// 2026-09-15: the BgGeolocationEngine branch that used to live here was
// removed, not just disabled -- flutter_background_geolocation shows its
// "LICENSE VALIDATION FAILURE" toast on every launch purely from being a
// dependency (confirmed by the plugin author himself, see pubspec.yaml's
// own comment on the removed dependency line for the full story and the
// exact steps to bring this branch back once the license is purchased).
// The original engine's source is preserved, untouched, at
// reference/bg_geolocation_engine.dart.txt.
import 'engines/tracelet_engine.dart';

class BackgroundGpsService {
  static Future<void> initialize() => TraceletEngine.initialize();

  static Future<bool> startTracking() => TraceletEngine.startTracking();

  static Future<void> stopTracking() => TraceletEngine.stopTracking();

  static bool get isRunning => TraceletEngine.isRunning;
}
