// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/engines/tracelet_engine.dart
//
// FREE background-location engine, the only one active (2026-09-15) --
// flutter_background_geolocation was removed entirely, not just disabled
// (see pubspec.yaml's own comment on the removed dependency line for why
// and the exact reactivation steps). Built specifically because its ~$300
// production license wasn't affordable before launch, and this app's
// actual trip-start trigger
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
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracelet/tracelet.dart' as tl;

import '../../i18n/app_texts.dart';
import '../../models/gig_app.dart';
import '../../services/supabase_bootstrap.dart';
import '../tracking_controller.dart';
import '../location_profile.dart';
import '../tracking_notification.dart';
import '../../services/diag_log.dart';
import '../auto_trip_detection_service.dart';

class TraceletEngine {
  static final TraceletEngine _instance = TraceletEngine._internal();
  factory TraceletEngine() => _instance;
  TraceletEngine._internal();

  bool isTracking = false;
  static bool _isInitialized = false;

  // True in the headless isolate Android starts while the app is closed. There the
  // native engine is already configured and running; configuring it again from
  // this isolate (Tracelet.ready) is not attempted.
  static bool _inHeadless = false;

  static bool get isRunning => _instance.isTracking;

  // =========================================================
  // HEADLESS TASK (se ejecuta cuando la app está terminada)
  // =========================================================
  // Must be a top-level or static function -- tracelet converts it to a
  // callback handle via dart:ui's PluginUtilities, same constraint
  // flutter_background_geolocation's registerHeadlessTask already has
  // (see bg_geolocation_engine.dart, unchanged there).
  @pragma('vm:entry-point')
  static void _headlessTask(tl.HeadlessEvent event) async {
    debugPrint('[TraceletEngine] Headless: ${event.name}');
    DiagLog.tag = 'headless';

    if (event.name != 'location') return;

    _inHeadless = !_isInitialized;
    final location = tl.Location.fromMap(event.event);
    final coords = location.coords;
    final safeSpeed = coords.speed < 0 ? 0.0 : coords.speed;
    final isMock = location.mockHeuristics?.platformFlagMock == true;
    DiagLog.add('fix', {
      'lat': DiagLog.coarse(coords.latitude),
      'lng': DiagLog.coarse(coords.longitude),
      'v': safeSpeed.toStringAsFixed(1),
      'acc': coords.accuracy.toStringAsFixed(0),
      'mock': isMock,
      'state': TrackingController.currentState.name,
    });

    // This isolate never ran main(): the backend client must exist before the
    // tick looks for an open trip.
    try {
      await SupabaseBootstrap.ensure();
    } catch (e) {
      debugPrint('[TraceletEngine] Headless: backend not ready: $e');
      return;
    }

    await TrackingController.processGpsTick(
      latitude: coords.latitude,
      longitude: coords.longitude,
      speed: safeSpeed,
      accuracy: coords.accuracy,
      timestamp: DateTime.parse(location.timestamp),
      isMock: isMock,
    );

    await _afterFix(safeSpeed, coords.accuracy, isMock);
  }

  /// After a fix was counted, in whichever engine received it. It runs second so a
  /// trip another engine started is picked up before anything tries to start one.
  /// No trip: driving can start one (General: any drive; Apps: a selected gig app).
  /// A trip: Apps mode follows the driver to another selected gig app.
  static Future<void> _afterFix(double speedMps, double accuracy, bool isMock) async {
    if (isMock) return;
    if (TrackingController.currentState == TrackingState.idle) {
      await AutoTripDetectionService.instance.handleIdleFix(speedMps: speedMps, accuracy: accuracy);
    } else {
      await AutoTripDetectionService.instance.handleRunningFix();
    }
  }

  // =========================================================
  // INITIALIZE
  // =========================================================
  // One run at a time: the app now starts the engine in the background after the
  // first frame, and a screen can ask for it at the same moment.
  static Future<void>? _initRun;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    final running = _initRun;
    if (running != null) return running;
    final run = _initializeOnce();
    _initRun = run;
    try {
      await run;
    } finally {
      _initRun = null;
    }
  }

  static Future<void> _initializeOnce() async {
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
              // New quiet channel (2026-11-05): the old one had default importance,
              // so the card made a sound / popped up every time the app opened.
              // Android keeps a channel's importance once created, hence a new id.
              channelId: 'controlmiles_tracking_quiet',
              channelName: 'ControlMiles tracking',
              notificationPriority: tl.NotificationPriority.low,
              notificationTitle: 'ControlMiles Tracking',
              notificationText: 'Recording miles securely',
              // Azul de marca real (kBrandSeed, #3E93CA en app_colors.dart).
              // Antes era '#2196F3', el azul genérico de Material: la
              // notificación persistente del servicio en primer plano -- la
              // que el conductor ve durante TODO el viaje -- salía de un azul
              // distinto al del resto de la app y al de las otras
              // notificaciones. Va como string porque tl.Config es const y
              // recibe el color en texto, no como Color.
              notificationColor: '#3E93CA',
              notificationSmallIcon: 'drawable/ic_stat_tracking',
              // Explícito a propósito (pedido explícito, 2026-09-18,
              // investigando por qué "ControlMiles Tracking" parecía
              // desaparecer): tracelet's own default for this field is
              // already `true` (non-swipeable while the trip is
              // running) -- confirmed by reading the package source
              // (ForegroundServiceConfig.notificationOngoing getter).
              // The real bug was elsewhere (pauseTracking() tears the
              // whole foreground service down, taking this notification
              // with it -- see notification_service.dart's
              // showPausedTrackingNotification for the actual fix).
              // Setting it here anyway removes any doubt for a future
              // reader and survives a library version bump changing its
              // default.
              notificationOngoing: true,
              // Las actualizaciones (distancia cada ~1 min) reemplazan la
              // notificación en silencio: sin esto cada refresco podría
              // volver a sonar/vibrar. El cronómetro NO se activa acá -- se
              // enciende en startTracking() con la hora de inicio real.
              notificationOnlyAlertOnce: true,
              notificationShowTimer: false,
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
        DiagLog.add('fix', {
          'lat': DiagLog.coarse(coords.latitude),
          'lng': DiagLog.coarse(coords.longitude),
          'v': safeSpeed.toStringAsFixed(1),
          'acc': coords.accuracy.toStringAsFixed(0),
          'mock': isMock,
          'state': TrackingController.currentState.name,
        });

        await TrackingController.processGpsTick(
          latitude: coords.latitude,
          longitude: coords.longitude,
          speed: safeSpeed,
          accuracy: coords.accuracy,
          timestamp: DateTime.parse(location.timestamp),
          isMock: isMock,
        );
        await _afterFix(safeSpeed, coords.accuracy, isMock);
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
    if (!_isInitialized && !_inHeadless) {
      await initialize();
      if (!_isInitialized) return false;
    }

    try {
      var state = await tl.Tracelet.getState();
      // Cronómetro nativo de la notificación (pedido del usuario: en un viaje
      // de 9 horas quería ver en la barra de notificaciones que sigue
      // activo). Se configura ANTES de arrancar para que la primera
      // notificación ya salga con el contador, y se refresca si el servicio
      // ya estaba vivo (recuperación tras cerrar la app).
      final wasRunning = state.enabled;

      // Perfil de ubicacion: un viaje real SIEMPRE con precision completa; en
      // modo "escuchando" (auto-detect armado, sin viaje) uno grueso y poco
      // frecuente. Se aplica ANTES de arrancar, y tambien si el motor ya
      // estaba corriendo (paso de "escuchando" a viaje).
      final hasTrip = TrackingController.activeSection != null;
      final profileOk = await _applyLocationProfile(hasTrip: hasTrip);
      if (hasTrip && !profileOk) {
        // No se arranca un viaje con el perfil de baja precision: mejor un
        // fallo visible (el viaje no inicia y se puede reintentar) que
        // kilometros mal registrados.
        debugPrint('[TraceletEngine ERROR] Could not apply the trip location profile; not starting');
        return false;
      }
      // La "card" completa desde el primer instante (no esperar al primer
      // refresco): distancia en el titulo + app de gig en el texto.
      final labels = await _currentLabels();
      _lastNotificationText = labels.title;
      _lastNotificationAt = DateTime.now();
      await _applyNotification(
        // Solo un viaje real cuenta tiempo: en modo "escuchando" (auto-detect
        // armado, sin viaje) el cronometro NO va, o parecería un viaje activo.
        timer: labels.showTimer,
        refresh: wasRunning,
        title: labels.title,
        text: labels.body,
      );
      // `enabled` is also true in geofence-only mode (work places, idle): that
      // is NOT a running GPS, so a trip must still call start() then.
      if (!state.enabled || state.trackingMode != tl.TrackingMode.location) {
        state = await tl.Tracelet.start();
      }
      DiagLog.add('engine start', {'enabled': state.enabled, 'trip': hasTrip});
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

  /// The work-place reminders were removed (2026-11-06): drop the geofences an older
  /// version registered (their ids start with "wp:").
  static Future<void> removeLegacyWorkPlaceGeofences() async {
    try {
      for (final g in await tl.Tracelet.getGeofences()) {
        if (g.identifier.startsWith('wp:')) await tl.Tracelet.removeGeofence(g.identifier);
      }
    } catch (e) {
      debugPrint('[TraceletEngine] removing old work places failed: $e');
    }
  }

  // =========================================================
  // STOP TRACKING
  // =========================================================
  static Future<void> stopTracking() async {
    try {
      // Nothing is running: leave it alone. Tracelet.stop() starts its foreground
      // service just to shut it down, and the notification flashed on every app
      // open (seen on the Samsung 2026-11-06: service onCreate/onDestroy 17 ms apart).
      final running = (await tl.Tracelet.getState()).enabled;
      if (!running) {
        _instance.isTracking = false;
        return;
      }
      // Apaga el cronómetro ANTES de detener: si el servicio se re-arma solo
      // (startOnBoot) no debe reaparecer con la hora de un viaje anterior.
      _lastNotificationText = null;
      _lastNotificationAt = null;
      _appliedProfileIsTrip = null;
      await _applyNotification(
        timer: false,
        refresh: false,
        title: kDefaultNotificationTitle,
        text: kDefaultNotificationText,
      );
      DiagLog.add('engine stop');
      await tl.Tracelet.stop();
      _instance.isTracking = false;
      debugPrint('[TraceletEngine] GPS Tracking Stopped');
    } catch (e) {
      debugPrint('[TraceletEngine ERROR] Stop failed: $e');
    }
  }

  // =========================================================
  // PERFIL DE UBICACION (bateria)
  // =========================================================
  static bool? _appliedProfileIsTrip;

  /// Aplica el perfil de ubicacion que corresponde (ver location_profile.dart).
  /// Devuelve false si no se pudo aplicar tras reintentos. No hace nada si ya
  /// esta aplicado el mismo perfil. setConfig es una actualizacion PARCIAL:
  /// solo se envian estos campos, el resto (servicio en primer plano, etc.)
  /// queda como esta.
  static Future<bool> _applyLocationProfile({required bool hasTrip}) async {
    if (_appliedProfileIsTrip == hasTrip) return true;

    const defaults = tl.AndroidConfig();
    final profile = locationProfileFor(
      hasActiveTrip: hasTrip,
      defaultIntervalMs: defaults.locationUpdateInterval,
      defaultFastestIntervalMs: defaults.fastestLocationUpdateInterval,
    );

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await tl.Tracelet.setConfig(
          tl.Config(
            geo: tl.GeoConfig(
              desiredAccuracy: profile.accuracy == LocationAccuracy.high
                  ? tl.DesiredAccuracy.high
                  : tl.DesiredAccuracy.medium,
              distanceFilter: profile.distanceFilterMeters,
            ),
            android: tl.AndroidConfig(
              locationUpdateInterval: profile.intervalMs,
              fastestLocationUpdateInterval: profile.fastestIntervalMs,
            ),
          ),
        );
        _appliedProfileIsTrip = hasTrip;
        debugPrint('[TraceletEngine] Location profile: ${hasTrip ? 'TRIP (high, 10 m)' : 'LISTENING (balanced, 100 m)'}');
        return true;
      } catch (e) {
        debugPrint('[TraceletEngine] Location profile attempt $attempt failed: $e');
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    _appliedProfileIsTrip = null;
    return false;
  }

  // =========================================================
  // NOTIFICACIÓN PERSISTENTE (cronómetro + distancia)
  // =========================================================
  static String? _lastNotificationText;
  static DateTime? _lastNotificationAt;

  /// Enciende/apaga el cronómetro nativo de la notificación. El reloj cuenta
  /// el tiempo de manejo ACTIVO (igual que la card del dashboard), así que el
  /// tiempo en pausa no se suma. Best-effort: si falla, el viaje sigue igual.
  static Future<void> _applyNotification({
    required bool timer,
    required bool refresh,
    String? title,
    String? text,
  }) async {
    try {
      final startedAt = notificationStartedAtMs(
        DateTime.now(),
        TrackingController.elapsedSectionDuration,
      );
      await tl.Tracelet.setConfig(
        tl.Config(
          android: tl.AndroidConfig(
            foregroundService: tl.ForegroundServiceConfig(
              notificationShowTimer: timer,
              notificationStartedAt: timer ? startedAt : null,
              notificationTitle: title,
              notificationText: text,
            ),
          ),
        ),
      );
      if (refresh) await tl.Tracelet.updateNotification();
    } catch (e) {
      debugPrint('[TraceletEngine] Notification update failed: $e');
    }
  }

  /// Vuelve a alinear la notificación con el estado actual de la app YA (sin
  /// esperar el minuto de espera): tras cambiar de gig app a mitad de viaje la
  /// sección nueva empieza en 00:00:00 y 0 mi, y el cronómetro nativo -que
  /// sigue con la hora de la sección anterior- quedaría desincronizado de la
  /// tarjeta.
  static Future<void> resyncNotification() async {
    if (!_isInitialized || !_instance.isTracking) return;
    _lastNotificationText = null;
    _lastNotificationAt = null;
    await refreshNotificationDistance();
  }

  /// Llamado desde cada tick GPS aceptado: refresca la distancia en la
  /// notificación como máximo una vez por minuto. Distancia que sigue
  /// creciendo = el GPS sigue grabando (el cronómetro solo prueba que el
  /// servicio está vivo).
  static Future<void> refreshNotificationDistance() async {
    if (!_isInitialized || !_instance.isTracking) return;
    try {
      final labels = await _currentLabels();
      final now = DateTime.now();
      if (!shouldRefreshNotification(
        lastRefreshAt: _lastNotificationAt,
        now: now,
        lastText: _lastNotificationText,
        newText: labels.title,
      )) {
        return;
      }
      _lastNotificationAt = now;
      _lastNotificationText = labels.title;
      await _applyNotification(
        timer: labels.showTimer,
        refresh: true,
        title: labels.title,
        text: labels.body,
      );
    } catch (e) {
      debugPrint('[TraceletEngine] Notification refresh failed: $e');
    }
  }

  /// Lo que dice la "card" ahora mismo: distancia (en la unidad elegida por el
  /// conductor) y app de gig. Lee la unidad de SharedPreferences directamente
  /// para que funcione tambien en el isolate headless.
  static Future<TrackingNotificationLabels> _currentLabels() async {
    final prefs = await SharedPreferences.getInstance();
    final metric = prefs.getBool('controlmiles_unit_system') ?? false;
    final lang = prefs.getString('controlmiles_lang') ?? 'en';
    final gigId = TrackingController.currentGigApp;
    // General mode watches every drive, not a list of apps, so the idle card
    // must not say it is "listening for a gig app".
    final general = (prefs.getStringList('controlmiles_work_mode') ?? const []).contains('general');
    if (general) {
      // Only a drive the phone detected says it is recording; while it waits the
      // card just says it is ready.
      return trackingNotificationLabels(
        hasActiveTrip: TrackingController.activeSection != null,
        miles: TrackingController.activeDistance,
        metric: metric,
        gigAppName: null,
        idleTitle: AppTexts.get('auto_detect_general_title', lang),
        idleBody: AppTexts.get('auto_detect_general_subtitle', lang),
        tripBody: AppTexts.get('tracking_notif_recording', lang),
      );
    }
    return trackingNotificationLabels(
      hasActiveTrip: TrackingController.activeSection != null,
      miles: TrackingController.activeDistance,
      metric: metric,
      gigAppName: gigId == null ? null : GigAppCatalog.byId(gigId).name,
      idleTitle: AppTexts.get('auto_detect_status_listening', lang),
      idleBody: AppTexts.get('auto_detect_status_listening_subtitle', lang),
      tripBody: AppTexts.get('tracking_notif_recording', lang),
    );
  }

}
