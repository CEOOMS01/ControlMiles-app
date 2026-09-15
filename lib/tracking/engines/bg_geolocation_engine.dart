// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/engines/bg_geolocation_engine.dart
//
// The ORIGINAL flutter_background_geolocation integration, relocated
// here verbatim (2026-09-15) when BackgroundGpsService was split into
// pluggable engines -- see location_engine_config.dart. Requires a paid
// production license (~$300 one-time, transistorsoft.com) not yet
// purchased, so this engine is currently INACTIVE: nothing in this file
// runs unless useBackgroundGeolocationPaidEngine is flipped to true.
// Kept intact, not deleted, specifically so activating the paid plugin
// later is a one-line config flip, not a rebuild.
import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

import '../tracking_controller.dart';
import '../auto_trip_detection_service.dart';
import '../../services/local_storage_service.dart';

class BgGeolocationEngine {
  static final BgGeolocationEngine _instance = BgGeolocationEngine._internal();
  factory BgGeolocationEngine() => _instance;
  BgGeolocationEngine._internal();

  bool isTracking = false;
  static bool _isInitialized = false;

  static bool get isRunning => _instance.isTracking;

  // =========================================================
  // HEADLESS TASK (se ejecuta cuando la app está terminada)
  // =========================================================
  static void _headlessTask(bg.HeadlessEvent event) async {
    debugPrint('[BgGeolocationEngine] Headless: ${event.name}');

    if (event.name == bg.Event.LOCATION) {
      final location = event.event as bg.Location;
      final coords = location.coords;

      final safeSpeed = coords.speed < 0 ? 0.0 : coords.speed;
      bool isMock = false;
      try {
        isMock = location.mock;
      } catch (_) {}

      // Procesar ubicación incluso en modo headless
      await TrackingController.processGpsTick(
        latitude: coords.latitude,
        longitude: coords.longitude,
        speed: safeSpeed,
        accuracy: coords.accuracy,
        timestamp: DateTime.parse(location.timestamp),
        isMock: isMock,
      );
    }
    else if (event.name == bg.Event.TERMINATE) {
      // Guardar checkpoint al terminar la app
      await _saveTerminateCheckpoint();
    }
    // 2026-08-28: the headless MOTIONCHANGE branch used to fire a "Trip
    // detected -- tap to confirm" notification. Removed entirely -- motion
    // alone no longer prompts anywhere in the app (see
    // AutoTripDetectionService.handleMotionChange), so there is nothing
    // headless-safe left for this event to do.
  }

  // Helper para guardar checkpoint en caso de terminación
  static Future<void> _saveTerminateCheckpoint() async {
    try {
      final sessionId = TrackingController.activeSessionId;
      final section = TrackingController.activeSection;

      // BUG FIX: este callback puede correr en un isolate headless nuevo,
      // donde el estado static de TrackingController ya vino reseteado
      // (ver tracking_controller.dart::_recoverActiveState). Sin este
      // guard, se guardaría un checkpoint en blanco (ids '') que
      // sobreescribiría el último checkpoint bueno — justo el que la
      // recuperación 100% offline necesita para reconstruir la sección. Si
      // no hay estado cargado en este isolate, no se toca lo que ya había.
      if (sessionId == null || section == null) {
        debugPrint('[BgGeolocationEngine] No hay estado en memoria en este isolate — se conserva el último checkpoint bueno');
        return;
      }

      await LocalStorageService.saveTripCheckpoint(
        sessionId: sessionId,
        sectionId: section.id,
        userId: section.userId,
        gigApp: TrackingController.currentGigApp ?? section.gigApp,
        sectionStartTime: section.startTime,
        // Duración "en vivo" hasta este instante (base + tramo activo
        // corriendo), no solo la última base bancada — así no se pierde el
        // tiempo manejado justo antes de que el SO terminara la app.
        sectionDurationSeconds: TrackingController.elapsedSectionDuration.inSeconds,
        totalSessionMiles: TrackingController.activeDistance,
        totalSectionMiles: TrackingController.activeDistance,
        isPaused: true,
      );
      debugPrint('[BgGeolocationEngine] Terminate checkpoint saved');
    } catch (e) {
      debugPrint('[BgGeolocationEngine] Failed to save terminate checkpoint: $e');
    }
  }

  // =========================================================
  // INITIALIZE
  // =========================================================
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      bg.BackgroundGeolocation.registerHeadlessTask(_headlessTask);

      await bg.BackgroundGeolocation.ready(
        bg.Config(
          desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
          distanceFilter: 10.0,                    // cada 10 metros
          stopOnTerminate: false,
          startOnBoot: true,
          enableHeadless: true,
          foregroundService: true,

          // Optimizaciones de batería
          pausesLocationUpdatesAutomatically: true,
          activityRecognitionInterval: 20000,
          stationaryRadius: 30.0,
          disableElasticity: true,

          // Notificación
          notification: bg.Notification(
            title: "ControlMiles Tracking",
            text: "Recording miles securely",
            color: "#2196F3",
            channelId: "controlmiles_tracking",
            smallIcon: "drawable/ic_stat_tracking",
          ),

          debug: false,
          logLevel: bg.Config.LOG_LEVEL_OFF,
        ),
      );

      // Callback principal cuando la app está en foreground/background
      bg.BackgroundGeolocation.onLocation(
        (bg.Location location) async {
          final coords = location.coords;
          final safeSpeed = coords.speed < 0 ? 0.0 : coords.speed;

          bool isMock = false;
          try {
            isMock = location.mock;
          } catch (_) {}

          await TrackingController.processGpsTick(
            latitude: coords.latitude,
            longitude: coords.longitude,
            speed: safeSpeed,
            accuracy: coords.accuracy,
            timestamp: DateTime.parse(location.timestamp),
            isMock: isMock,
          );
        },
        (bg.LocationError error) {
          debugPrint('[GPS ERROR] ${error.code} - ${error.message}');
        },
      );

      // Premium auto-detect (foreground/background, app process alive):
      // registered unconditionally, same as onLocation above -- the
      // single gate for whether this matters right now lives inside
      // AutoTripDetectionService.handleMotionChange itself (armed?
      // already mid-trip?), not here.
      bg.BackgroundGeolocation.onMotionChange((bg.Location location) {
        AutoTripDetectionService.instance.handleMotionChange(location.isMoving);
      });

      _isInitialized = true;
      debugPrint('[BgGeolocationEngine] Initialized successfully (Optimized)');
    } catch (e) {
      _isInitialized = false;
      debugPrint('[BgGeolocationEngine ERROR] Initialization failed: $e');
    }
  }

  // =========================================================
  // START TRACKING
  // =========================================================
  static Future<bool> startTracking() async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) return false;
    }

    try {
      var state = await bg.BackgroundGeolocation.state;
      if (!state.enabled) {
        await bg.BackgroundGeolocation.start();
        state = await bg.BackgroundGeolocation.state;
      }
      _instance.isTracking = state.enabled;
      if (state.enabled) {
        debugPrint('[BgGeolocationEngine] GPS Tracking Started');
      } else {
        debugPrint('[BgGeolocationEngine ERROR] start() returned without throwing, but the engine is not enabled');
      }
      return state.enabled;
    } catch (e) {
      debugPrint('[BgGeolocationEngine ERROR] Start failed: $e');
      _instance.isTracking = false;
      return false;
    }
  }

  // =========================================================
  // STOP TRACKING
  // =========================================================
  static Future<void> stopTracking() async {
    try {
      await bg.BackgroundGeolocation.stop();
      _instance.isTracking = false;
      debugPrint('[BgGeolocationEngine] GPS Tracking Stopped');
    } catch (e) {
      debugPrint('[BgGeolocationEngine ERROR] Stop failed: $e');
    }
  }
}
