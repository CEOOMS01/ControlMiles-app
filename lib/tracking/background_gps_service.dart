// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/background_gps_service.dart
// VERSIÓN REVISADA Y ALINEADA - 2026

import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

import 'tracking_controller.dart';
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

      final safeSpeed = (coords.speed ?? 0.0) < 0 ? 0.0 : (coords.speed ?? 0.0);
      bool isMock = false;
      try {
        isMock = location.mock ?? false;
      } catch (_) {}

      // Procesar ubicación incluso en modo headless
      await TrackingController.processGpsTick(
        latitude: coords.latitude,
        longitude: coords.longitude,
        speed: safeSpeed,
        accuracy: coords.accuracy ?? 0.0,
        timestamp: DateTime.parse(location.timestamp),
        isMock: isMock,
      );
    } 
    else if (event.name == bg.Event.TERMINATE) {
      // Guardar checkpoint al terminar la app
      await _saveTerminateCheckpoint();
    }
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
          final safeSpeed = (coords.speed ?? 0.0) < 0 ? 0.0 : (coords.speed ?? 0.0);

          bool isMock = false;
          try {
            isMock = location.mock ?? false;
          } catch (_) {}

          await TrackingController.processGpsTick(
            latitude: coords.latitude,
            longitude: coords.longitude,
            speed: safeSpeed,
            accuracy: coords.accuracy ?? 0.0,
            timestamp: DateTime.parse(location.timestamp),
            isMock: isMock,
          );
        },
        (bg.LocationError error) {
          debugPrint('[GPS ERROR] ${error.code} - ${error.message}');
        },
      );

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
  static Future<void> startTracking() async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) return;
    }

    try {
      final state = await bg.BackgroundGeolocation.state;
      if (!state.enabled) {
        await bg.BackgroundGeolocation.start();
      }
      _instance.isTracking = true;
      debugPrint('[BackgroundGpsService] GPS Tracking Started');
    } catch (e) {
      debugPrint('[BackgroundGpsService ERROR] Start failed: $e');
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