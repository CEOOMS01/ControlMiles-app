// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/background_gps_service.dart
//
// PUBLIC FACADE (2026-09-15) -- delegates to whichever engine
// location_engine_config.dart selects: TraceletEngine (free, active by
// default) or BgGeolocationEngine (paid, kept intact but inactive until
// the license is purchased). Every existing caller in this codebase
// (main.dart, auto_trip_detection_service.dart, tracking_controller.dart)
// keeps calling BackgroundGpsService.initialize()/.startTracking()/
// .stopTracking()/.isRunning exactly as before -- this split is invisible
// to them, by design, so flipping the config flag later needs no other
// file touched.
import 'engines/location_engine_config.dart';
import 'engines/bg_geolocation_engine.dart';
import 'engines/tracelet_engine.dart';

class BackgroundGpsService {
  static Future<void> initialize() {
    return useBackgroundGeolocationPaidEngine
        ? BgGeolocationEngine.initialize()
        : TraceletEngine.initialize();
  }

  static Future<bool> startTracking() {
    return useBackgroundGeolocationPaidEngine
        ? BgGeolocationEngine.startTracking()
        : TraceletEngine.startTracking();
  }

  static Future<void> stopTracking() {
    return useBackgroundGeolocationPaidEngine
        ? BgGeolocationEngine.stopTracking()
        : TraceletEngine.stopTracking();
  }

  static bool get isRunning => useBackgroundGeolocationPaidEngine
      ? BgGeolocationEngine.isRunning
      : TraceletEngine.isRunning;
}
