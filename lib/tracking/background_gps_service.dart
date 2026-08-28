// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/background_gps_service.dart
// VERSIÓN REVISADA Y ALINEADA - 2026

import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

import 'tracking_controller.dart';
import 'auto_trip_detection_service.dart';
import '../services/local_storage_service.dart';

class BackgroundGpsService {
  static final BackgroundGpsService _instance = BackgroundGpsService._internal();
  factory BackgroundGpsService() => _instance;
  BackgroundGpsService._internal();

  bool isTracking = false;
  static bool _isInitialized = false;

  static bool get isRunning => _instance.isTracking;

  // =========================================================
  // HEADLESS TASK (se ejecuta cuando la app está terminada)
  // =========================================================
  static void _headlessTask(bg.HeadlessEvent event) async {
    debugPrint('[BackgroundGpsService] Headless: ${event.name}');

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
        debugPrint('[BackgroundGpsService] No hay estado en memoria en este isolate — se conserva el último checkpoint bueno');
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
      debugPrint('[BackgroundGpsService] Terminate checkpoint saved');
    } catch (e) {
      debugPrint('[BackgroundGpsService] Failed to save terminate checkpoint: $e');
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
      debugPrint('[BackgroundGpsService] Initialized successfully (Optimized)');
    } catch (e) {
      _isInitialized = false;
      debugPrint('[BackgroundGpsService ERROR] Initialization failed: $e');
    }
  }

  // =========================================================
  // START TRACKING
  // =========================================================
  // REAL BUG FIX (2026-08-28, "bug silencioso en auto-detección"): this
  // used to return void and swallow every failure into a debugPrint --
  // AutoTripDetectionService.setEnabled(true) had no way to know the GPS
  // engine never actually started (e.g. background-location permission
  // revoked after the fact, which Android does on its own for
  // rarely-opened apps). The feature would arm itself, the UI would show
  // "Auto-Detection ON", the 30s gig-app poll would keep running (a
  // completely separate Android subsystem/permission from GPS), and any
  // auto-started trip would silently record zero real mileage forever --
  // no error anywhere. Now returns whether the engine is ACTUALLY
  // enabled after the attempt (re-checked, not just "no exception was
  // thrown"), so callers that need to know -- not the manual Start
  // button's own call sites, which don't check this return value and
  // keep working exactly as before -- can detect and surface a real
  // failure instead of silently no-op'ing.
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
        debugPrint('[BackgroundGpsService] GPS Tracking Started');
      } else {
        debugPrint('[BackgroundGpsService ERROR] start() returned without throwing, but the engine is not enabled');
      }
      return state.enabled;
    } catch (e) {
      debugPrint('[BackgroundGpsService ERROR] Start failed: $e');
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
      debugPrint('[BackgroundGpsService] GPS Tracking Stopped');
    } catch (e) {
      debugPrint('[BackgroundGpsService ERROR] Stop failed: $e');
    }
  }
}