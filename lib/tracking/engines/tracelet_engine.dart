// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/engines/tracelet_engine.dart
//
// FREE background-location engine, active by default (2026-09-15) --
// see location_engine_config.dart. Built specifically because
// flutter_background_geolocation's ~$300 production license wasn't
// affordable before launch, and this app's actual trip-start trigger
// (AutoTripDetectionService's gig-app-foreground polling) never depended
// on motion-based activity recognition to begin with -- the only thing
// genuinely required here is: (1) reliable continuous background GPS
// while a trip is running, feeding TrackingController.processGpsTick,
// and (2) a stationary<->moving signal to keep the background service
// armed for AutoTripDetectionService. Both come from `tracelet` with no
// hand-rolled activity-recognition state machine needed.
//
// Package research (2026-09-15), sources:
//   https://pub.dev/packages/tracelet -- v3.8.7, Apache-2.0, verified
//     publisher ikolvi.com, 160 pub points, 5.0k weekly downloads,
//     production-grade (not a 0.x experiment).
//   https://github.com/Ikolvi/Tracelet -- native Kotlin (FusedLocationProvider,
//     WorkManager, Geofencing API) on Android, native Swift (CoreLocation,
//     CoreMotion, BackgroundTasks) on iOS -- not a Dart-only wrapper around
//     the plain `location` package, which is why it can do headless/
//     foreground-service/motion-detection at all without the app process
//     staying alive. Considered and rejected: hand-assembling `location` +
//     `flutter_activity_recognition` (both free) -- would need its own
//     custom motion state-machine built and battery-tuned from scratch;
//     tracelet already ships that exact functionality, tested against
//     real OEM battery killers, for the same $0.
//
// Known, disclosed gap vs. the paid engine (see bg_geolocation_engine.dart):
// tracelet's HeadlessEvent has no TERMINATE-equivalent event (confirmed by
// reading headless_event.dart's own doc comment listing every known event
// name -- 'location', 'motionchange', 'activitychange', etc., no
// 'terminate'), so there is no direct replacement for
// BgGeolocationEngine's _saveTerminateCheckpoint. Not a correctness gap in
// practice: TrackingController.processGpsTick already calls
// LocalStorageService.saveTripCheckpoint on every single GPS tick (see
// tracking_controller.dart), so the worst case if the OS kills the app
// between one tick and the next is losing that one tick's worth of
// distance/time (seconds, a few meters) -- not the trip.
import 'package:flutter/foundation.dart';
import 'package:tracelet/tracelet.dart' as tl;

import '../tracking_controller.dart';
import '../auto_trip_detection_service.dart';

class TraceletEngine {
  static final TraceletEngine _instance = TraceletEngine._internal();
  factory TraceletEngine() => _instance;
  TraceletEngine._internal();

  bool isTracking = false;
  static bool _isInitialized = false;

  static bool get isRunning => _instance.isTracking;

  // =========================================================
  // HEADLESS TASK (se ejecuta cuando la app está terminada)
  // =========================================================
  // Must be a top-level or static function -- tracelet converts it to a
  // callback handle via dart:ui's PluginUtilities, same constraint
  // flutter_background_geolocation's registerHeadlessTask already has
  // (see bg_geolocation_engine.dart, unchanged there).
  static void _headlessTask(tl.HeadlessEvent event) async {
    debugPrint('[TraceletEngine] Headless: ${event.name}');

    if (event.name != 'location') return;

    final location = tl.Location.fromMap(event.event);
    final coords = location.coords;
    final safeSpeed = coords.speed < 0 ? 0.0 : coords.speed;
    final isMock = location.mockHeuristics?.platformFlagMock == true;

    await TrackingController.processGpsTick(
      latitude: coords.latitude,
      longitude: coords.longitude,
      speed: safeSpeed,
      accuracy: coords.accuracy,
      timestamp: DateTime.parse(location.timestamp),
      isMock: isMock,
    );
  }

  // =========================================================
  // INITIALIZE
  // =========================================================
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await tl.Tracelet.registerHeadlessTask(_headlessTask);

      await tl.Tracelet.ready(
        const tl.Config(
          geo: tl.GeoConfig(
            desiredAccuracy: tl.DesiredAccuracy.high,
            distanceFilter: 10.0,              // cada 10 metros
            stationaryRadius: 30.0,
            disableElasticity: true,
          ),
          app: tl.AppConfig(
            stopOnTerminate: false,
            startOnBoot: true,
          ),
          android: tl.AndroidConfig(
            foregroundService: tl.ForegroundServiceConfig(
              enabled: true,
              channelId: 'controlmiles_tracking',
              notificationTitle: 'ControlMiles Tracking',
              notificationText: 'Recording miles securely',
              notificationColor: '#2196F3',
              notificationSmallIcon: 'drawable/ic_stat_tracking',
            ),
          ),
          ios: tl.IosConfig(
            preventSuspend: true,
          ),
          logger: tl.LoggerConfig(logLevel: tl.LogLevel.off, debug: false),
        ),
      );

      // Callback principal cuando la app está en foreground/background
      tl.Tracelet.onLocation((tl.Location location) async {
        final coords = location.coords;
        final safeSpeed = coords.speed < 0 ? 0.0 : coords.speed;
        final isMock = location.mockHeuristics?.platformFlagMock == true;

        await TrackingController.processGpsTick(
          latitude: coords.latitude,
          longitude: coords.longitude,
          speed: safeSpeed,
          accuracy: coords.accuracy,
          timestamp: DateTime.parse(location.timestamp),
          isMock: isMock,
        );
      });

      // Mismo rol que en BgGeolocationEngine: solo re-arma el servicio al
      // volver a quedarse quieto, ya no dispara ni pregunta nada -- ver
      // AutoTripDetectionService.handleMotionChange.
      tl.Tracelet.onMotionChange((tl.Location location) {
        AutoTripDetectionService.instance.handleMotionChange(location.isMoving);
      });

      _isInitialized = true;
      debugPrint('[TraceletEngine] Initialized successfully');
    } catch (e) {
      _isInitialized = false;
      debugPrint('[TraceletEngine ERROR] Initialization failed: $e');
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
      var state = await tl.Tracelet.getState();
      if (!state.enabled) {
        state = await tl.Tracelet.start();
      }
      _instance.isTracking = state.enabled;
      if (state.enabled) {
        debugPrint('[TraceletEngine] GPS Tracking Started');
      } else {
        debugPrint('[TraceletEngine ERROR] start() returned without throwing, but the engine is not enabled');
      }
      return state.enabled;
    } catch (e) {
      debugPrint('[TraceletEngine ERROR] Start failed: $e');
      _instance.isTracking = false;
      return false;
    }
  }

  // =========================================================
  // STOP TRACKING
  // =========================================================
  static Future<void> stopTracking() async {
    try {
      await tl.Tracelet.stop();
      _instance.isTracking = false;
      debugPrint('[TraceletEngine] GPS Tracking Stopped');
    } catch (e) {
      debugPrint('[TraceletEngine ERROR] Stop failed: $e');
    }
  }
}
