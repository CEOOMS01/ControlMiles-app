// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/auto_trip_detection_service.dart
//
// Premium Gig feature (explicit user requirement).
//
// PRIMARY (and, as of 2026-08-28, ONLY) trigger: gig app detected in the
// foreground (Android only, via GigAppDetectionService/
// UsageStatsManager), polled periodically while armed. Explicit user
// correction from the original movement-based design: "en principio eso
// era lo que queria... no por movimiento" -- opening Uber/DoorDash/etc
// is what should trigger a trip, not raw device motion.
//
// REVISED 2026-08-27, explicit user request ("elimina el preguntar en
// gig app"): a trip whose gig app was identified with real confidence
// now starts SILENTLY, no confirmation screen -- see _autoStartTrip. The
// odometer-mandatory requirement from the original design is still
// fully honored: it's satisfied once, for real, at activation time
// (requestEnable's own camera capture), and every auto-started trip
// afterward carries that same reading forward (TrackingController.
// startTripFlow's useAutoDetectOdometer path) -- asking the driver to
// additionally tap "confirm" before every single detected trip no
// longer served that evidentiary purpose, it was pure friction. Only an
// informational notification fires afterward, same pattern already used
// for mid-trip auto-switch.
//
// REVISED AGAIN 2026-08-28, explicit user request ("aun continua trip
// detected, confirm and start... elimina ese módulo"): the motion-only
// fallback (flutter_background_geolocation's onMotionChange, kept
// because iOS has no gig-app-foreground API and because a driver may
// start moving before opening the gig app) used to fall back to the
// EXACT confirmation screen the user had just asked to remove above --
// there was no specific app to auto-select in that case, so a real
// prompt seemed structurally necessary. Real-world report: this path
// fired for a genuine Android user (GoShare, one of this session's own
// newly-added platforms) -- motion detection can legitimately win a
// race against the 30s gig-app poll (a driver starts moving before that
// poll has caught up to which app they opened), surfacing the exact
// "Trip detected -- tap to confirm" flow that was supposed to be gone.
// Rather than trying to close that race, the whole motion-triggered
// prompt path is removed: AutoTripPromptScreen deleted, the route
// deleted, the notification that led into it deleted. Motion detection
// alone no longer starts or prompts for anything -- see
// handleMotionChange below, now only responsible for restarting the
// background service when the driver goes stationary again (unrelated
// plumbing, not prompt-related). In practice this means auto-detect's
// real, working trigger is Android gig-app detection only; the iOS/
// unknown-app case has no auto-start path anymore, since there's no way
// to silently pick a gig app that was never identified, and confirming
// it is exactly what was asked to be removed.
//
// v1 scope, disclosed: only trip START is automatic. Ending a trip
// still uses the existing manual End button -- auto-ending wasn't part
// of what was asked for this pass.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'background_gps_service.dart';
import 'drive_wake.dart';
import 'tracking_controller.dart';
import '../logic/app_state.dart';
import '../services/gig_app_detection_service.dart';
import '../services/diag_log.dart';
import '../services/notification_service.dart';
import '../services/odometer_capture_service.dart';
import '../services/supabase_bootstrap.dart';
import '../services/vehicle_service.dart';
import '../screens/odometer_capture_screen.dart';
import '../utils/permission_gate.dart';
import '../utils/permission_recovery_service.dart';
import '../utils/permission_status.dart';
import '../views/permissions_flow_screen.dart';

class AutoTripDetectionService {
  AutoTripDetectionService._internal();
  static final AutoTripDetectionService instance =
      AutoTripDetectionService._internal();

  static const String _enabledPrefKey = 'controlmiles_auto_detect_enabled';
  static const String _shiftOdoValueKey = 'controlmiles_shift_odometer_value';
  static const String _shiftOdoImageKey = 'controlmiles_shift_odometer_image_url';

  // Premium-exclusive "select gig apps for working shift" (explicit user
  // request, 2026-09-18). Same key AppState.setSelectedGigAppIds persists
  // to -- read directly here (same pattern this class already uses for
  // _enabledPrefKey) instead of going through AppState, since this poll
  // loop has no BuildContext/Provider access.
  static const String _selectedGigAppIdsPrefKey = 'controlmiles_selected_gig_app_ids';

  /// The only apps Apps mode reacts to (2026-11-07, explicit decision): the ones the
  /// driver selected from the integrated catalog. No other app on the phone counts,
  /// none selected means nothing starts, and 'custom' is General, never an app.
  Future<Set<String>> _selectedApps() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_selectedGigAppIdsPrefKey) ?? const <String>[]).where((id) => id != 'custom').toSet();
  }

  // Polling interval for "is a gig app in the foreground right now" --
  // relies on the SAME foreground service flutter_background_geolocation
  // already keeps alive while armed (persistent notification, immune to
  // Android killing the process), not a separate background mechanism.
  static const Duration _gigAppPollInterval = Duration(seconds: 30);

  bool _armed = false;
  bool _promptActive = false;
  Timer? _pollTimer;
  Timer? _promptStuckTimer;

  // Real bug found live (2026-08-27, "solo detecta 1 o 2 apps y no
  // vuelve a hacerlo"): _promptActive guards _autoStartTrip below against
  // re-triggering while a start is already in flight, but nothing
  // guaranteed it always got cleared -- if the guard stuck true, EVERY
  // future poll's `if (_promptActive) return` silently killed detection
  // for the rest of the process's life, matching the report exactly.
  // This timeout is a pure safety net: the fast path (_autoStartTrip
  // itself clearing the guard once it's done) still fires immediately
  // and cancels this first -- it only ever fires if nothing else cleared
  // the guard in time.
  static const Duration _promptStuckTimeout = Duration(minutes: 3);

  // Ambient "what's currently detected" status, for DashboardScreen's
  // status card (replaces the manual GigAppSelector carousel while idle
  // + armed, per explicit user request -- showing both was inconsistent
  // once auto-detect actually does the same job the carousel did). Set
  // by the SAME 30s poll that already exists for triggering the prompt
  // -- deliberately not a separate/faster poll, to keep the battery cost
  // exactly what it already was. DashboardScreen already rebuilds every
  // second on its own existing UI timer, so a plain field (not a
  // ValueNotifier) is enough -- no new listener plumbing needed.
  String? lastDetectedGigAppId;

  // Mid-trip gig-app-switch detection (explicit user follow-up request,
  // separate from trip-START detection above): while a trip is RUNNING,
  // every GPS fix checks the foreground gig app -- if it differs from the
  // one the trip is currently tracking under, switch silently, same as
  // trip-start. See handleRunningFix.

  // Shift-start odometer reading, captured once (real photo, real
  // evidence -- see OdometerCaptureService.processEvidence's standalone
  // mode) and carried forward onto every trip auto-detected afterward,
  // explicit user requirement: "que la activacion de auto detection
  // dispare el registro de odometro... de esta manera no hay que
  // hacerlo durante el tracking". Cleared on disarm (setEnabled(false))
  // so the NEXT activation always starts with a fresh reading --
  // persisted to SharedPreferences too, so a stale in-memory-only value
  // doesn't survive a real app restart mid-shift with the wrong
  // semantics; restoreFromPrefs() reloads it alongside the armed state.
  double? shiftStartOdometerValue;
  String? shiftStartOdometerImageUrl;

  bool get hasShiftStartOdometer =>
      shiftStartOdometerValue != null && shiftStartOdometerImageUrl != null;

  bool get isArmed => _armed;

  /// Called from AppState.setAutoDetectEnabled -- turns the always-on
  /// listening mode on/off. Arming starts BackgroundGpsService
  /// (idempotent) so the motion-detection fallback runs even with no
  /// active trip, and starts the gig-app poll timer on Android; disarming
  /// only stops either if there's no trip actually in progress right
  /// now -- toggling the setting off mid-drive must not kill a real
  /// trip's GPS.
  ///
  /// REAL BUG FIX (2026-08-28, "bug silencioso en auto-detección"):
  /// used to return void and arm unconditionally regardless of whether
  /// BackgroundGpsService.startTracking() actually succeeded --
  /// _armed/the poll timer would come up fine even with a dead GPS
  /// engine, and the UI had no way to know. Now returns whether the GPS
  /// engine is genuinely running after this call; still arms the gig-app
  /// poll either way (that's a separate Android subsystem/permission
  /// from GPS, and still useful on its own), but callers that need to
  /// know the whole feature is healthy -- requestEnable's dialog,
  /// restoreFromPrefs's notification -- can now tell.
  Future<bool> setEnabled(bool enabled) async {
    _armed = enabled;
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!enabled) {
      lastDetectedGigAppId = null;
      // Don't carry a stale prompt guard into the NEXT activation --
      // same reasoning as the shift-odometer clear right below.
      _promptStuckTimer?.cancel();
      _promptStuckTimer = null;
      _promptActive = false;
      // Explicit user requirement: turning auto-detect off clears the
      // shift-start reading -- the next activation must capture a fresh
      // one, never silently reuse a stale one from an earlier session.
      await clearShiftStartOdometer();
    }

    if (enabled) {
      // Android: the phone sleeps until Android says it entered a vehicle (no GPS,
      // no notification while idle; see drive_wake.dart). Elsewhere the engine
      // keeps listening the old way.
      if (DriveWake.isSupported && TrackingController.currentState == TrackingState.idle) {
        // A listening service left over from an older version: no trip is running,
        // so let it go (its notification goes with it).
        await BackgroundGpsService.stopTracking();
      }
      final gpsOk = DriveWake.isSupported
          ? await DriveWake.register()
          : await BackgroundGpsService.startTracking();
      if (GigAppDetectionService.instance.isSupported) {
        // Pre-warm the package catalog NOW, while this call is guaranteed
        // to be running from a real foreground user action (the Settings/
        // drawer toggle) -- see GigAppDetectionService's own comment on
        // why leaving this to the poll timer's first tick is fragile.
        // Best-effort: if it fails here (rare -- would need a real outage
        // right at this moment), the poll's own lazy retry is still the
        // fallback, unchanged.
        await GigAppDetectionService.instance.preloadCatalog();
        _pollTimer = Timer.periodic(
          _gigAppPollInterval,
          (_) => _pollForGigApp(),
        );
      }
      return gpsOk;
    } else {
      await DriveWake.unregister();
      if (TrackingController.currentState == TrackingState.idle) {
        await BackgroundGpsService.stopTracking();
      }
    }
    return true;
  }

  /// Re-arms on cold app start if the user already had this on -- mirrors
  /// NotificationService.init()'s own re-scheduling of the weekly summary
  /// reminder when it was left enabled.
  ///
  /// REAL BUG FIX (2026-08-28): this is THE path most exposed to the
  /// silent-failure bug -- it runs on every cold boot with no
  /// BuildContext to show anything, and used to call setEnabled(true)
  /// with zero permission re-check (unlike requestEnable's interactive
  /// activation, which does check). If background-location permission
  /// gets revoked after the fact -- the user does it manually, or
  /// Android's own automatic permission-reset for rarely-opened apps,
  /// both real -- this is exactly where it would have gone unnoticed
  /// forever. Now fires a real notification (the only signal available
  /// with no UI up yet) when the GPS engine doesn't actually come back.
  Future<void> restoreFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledPrefKey) ?? false;
    if (!enabled) return;

    // Reload the cached shift-start reading BEFORE arming, so a real app
    // restart mid-shift doesn't lose it (setEnabled(true) itself never
    // touches this cache -- only setEnabled(false)/clearShiftStartOdometer
    // do).
    shiftStartOdometerValue = double.tryParse(prefs.getString(_shiftOdoValueKey) ?? '');
    shiftStartOdometerImageUrl = prefs.getString(_shiftOdoImageKey);

    final gpsOk = await setEnabled(true);
    if (!gpsOk) DiagLog.add('auto-detect could not start');
  }

  /// Called once the standalone OdometerCaptureScreen capture succeeds
  /// (see requestEnable below) -- caches the real, already-uploaded
  /// photo/value so every trip detected for the rest of this armed
  /// stint can carry it forward instead of asking again.
  Future<void> setShiftStartOdometer({
    required double value,
    required String imageUrl,
  }) async {
    shiftStartOdometerValue = value;
    shiftStartOdometerImageUrl = imageUrl;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shiftOdoValueKey, value.toString());
    await prefs.setString(_shiftOdoImageKey, imageUrl);
  }

  Future<void> clearShiftStartOdometer() async {
    shiftStartOdometerValue = null;
    shiftStartOdometerImageUrl = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_shiftOdoValueKey);
    await prefs.remove(_shiftOdoImageKey);
  }

  static bool _armTriedThisRun = false;

  /// Premium accounts keep automatic detection on without any button
  /// (2026-11-05): it sleeps and wakes when the phone moves. Called when the
  /// Dashboard opens or resumes. Nothing is shown when everything needed is
  /// already there (location all the time, the app-detection permission in Apps
  /// mode, this cycle's odometer photo); the camera is asked once per app start
  /// only when the cycle still has no reading. Does nothing for Basic accounts,
  /// for a driver who turned it off in Settings, or before they chose a work mode.
  static Future<void> ensureArmed(BuildContext context, AppState appState, {bool force = false}) async {
    // [force]: the driver just changed how they work from the Dashboard, so it is
    // fine to show what is missing (permission pages, the camera) right now.
    if (force) {
      if (!appState.premiumEntitled || appState.autoDetectOffByUser) return;
      if (appState.autoDetectEnabled) {
        if (appState.workMode == 'gig' &&
            GigAppDetectionService.instance.isSupported &&
            !await GigAppDetectionService.instance.hasUsageAccess() &&
            context.mounted) {
          await PermissionsFlowScreen.ask(context, PermKind.usageAccess);
        }
        return;
      }
      await requestEnable(context, appState);
      return;
    }
    if (!appState.premiumEntitled || appState.autoDetectEnabled || appState.autoDetectOffByUser) return;
    final mode = appState.workMode;
    if (mode != 'general' && mode != 'gig') return;
    if (TrackingController.currentState != TrackingState.idle) return;
    if (!await PermissionRecoveryService.hasCriticalPermissions()) return;
    if (mode == 'gig' &&
        GigAppDetectionService.instance.isSupported &&
        !await GigAppDetectionService.instance.hasUsageAccess()) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final vehicle = await VehicleService().getActiveOrAssignedVehicle(user.id, organizationId: null);
      final existing = vehicle == null ? null : await OdometerCaptureService().currentWeekStartReading(vehicle.id);
      if (existing != null) {
        await instance.setShiftStartOdometer(value: existing.value, imageUrl: existing.imageUrl);
        await appState.setAutoDetectEnabled(true);
        return;
      }
    }
    if (_armTriedThisRun || !context.mounted) return;
    _armTriedThisRun = true;
    await requestEnable(context, appState);
  }

  /// Full "turn auto-detect on" flow -- called from Settings/the drawer
  /// toggle INSTEAD of calling appState.setAutoDetectEnabled(true)
  /// directly, since activation now also has to capture the shift-start
  /// odometer first (explicit user requirement). Checks permissions,
  /// then opens the same OdometerCaptureScreen every manual trip already
  /// uses (standalone mode -- sessionId: null, see the screen/service's
  /// own comments), and only actually arms auto-detect if that capture
  /// succeeds. Returns false (nothing enabled) if the user backs out at
  /// any step -- permission denied, or cancelled the camera screen.
  static Future<bool> requestEnable(BuildContext context, AppState appState) async {
    // Location, precise and all the time: asked here with the explanation page
    // (and Settings only if it is still not enough), not a dead-end dialog.
    if (!await PermissionGate.ensure(context, requireAlways: true)) return false;

    if (!context.mounted) return false;

    // BUG FIX (2026-09-16, reportado en vivo: "al activarlo no está leyendo
    // ninguna gig app de las ya integradas"). Armar solo comprobaba los
    // permisos de UBICACIÓN. La detección de gig app depende de otro
    // completamente distinto -- Usage Access (PACKAGE_USAGE_STATS) -- y sin
    // él detectActiveGigAppId() devuelve null en cada sondeo, para siempre,
    // en silencio absoluto.
    //
    // No es hipotético: la causa real de ese reporte fue el renombrado del
    // paquete Android en 1c5aaeb (com.example.controlmiles ->
    // com.olimsys.controlmiles, obligatorio antes de publicar en Play).
    // Usage Access se concede POR NOMBRE DE PAQUETE, así que el renombrado
    // lo revocó sin avisar y auto-detect quedó muerto una semana sin un
    // solo error en ningún log. Confirmado en el dispositivo real: appops
    // reportaba GET_USAGE_STATS como nunca concedido al paquete nuevo.
    //
    // El sitio normal donde se pide es el onboarding (welcome_page), una
    // sola vez. Esto de aquí NO es repetir la pregunta: es la precondición
    // de la función que el usuario acaba de encender. Se comprueba ANTES de
    // la captura de odómetro para no hacerle fotografiar el odómetro y
    // decirle después que falta un permiso.
    // General mode watches every drive, so it does not need to see which app is open.
    if (appState.workMode != 'general' &&
        GigAppDetectionService.instance.isSupported &&
        !await GigAppDetectionService.instance.hasUsageAccess()) {
      if (!context.mounted) return false;
      // The same one-step page as the first launch: why it is needed and what
      // stops working without it. The page re-checks when the driver comes
      // back from Settings, so a grant there carries straight on to arming.
      await PermissionsFlowScreen.ask(context, PermKind.usageAccess);
      if (!await GigAppDetectionService.instance.hasUsageAccess()) {
        // No se arma: "armado pero ciego" es exactamente el estado que este
        // arreglo existe para impedir.
        return false;
      }
    }

    // Weekly odometer checkpoint (explicit user request, 2026-09-03): if
    // this vehicle's current calendar week already has a start reading
    // (fresh this week, or rolled forward from a missed close last week),
    // arming auto-detect needs no new photo at all -- just reuse it.
    double? value;
    String? imageUrl;

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final activeVehicle = await VehicleService().getActiveOrAssignedVehicle(
        user.id,
        organizationId: null,
      );
      if (activeVehicle != null) {
        final existing = await OdometerCaptureService()
            .currentWeekStartReading(activeVehicle.id);
        if (existing != null) {
          value = existing.value;
          imageUrl = existing.imageUrl;
        }
      }
    }

    if (value == null || imageUrl == null) {
      if (!context.mounted) return false;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OdometerCaptureScreen(isStart: true),
        ),
      );

      if (result is! Map || result['success'] != true) return false;

      final rawValue = result['odometer_value'];
      value = rawValue is num ? rawValue.toDouble() : double.tryParse(rawValue.toString());
      imageUrl = result['imageUrl'] as String?;
      if (value == null || imageUrl == null) return false;
    }

    await instance.setShiftStartOdometer(value: value, imageUrl: imageUrl);
    final gpsOk = await appState.setAutoDetectEnabled(true);

    // REAL BUG FIX (2026-08-28): this used to return true unconditionally
    // the moment the odometer capture succeeded, regardless of whether
    // the GPS engine underneath actually started -- the interactive
    // activation path had a live BuildContext and still told the user
    // nothing when it silently failed. Now surfaces it immediately, here,
    // instead of only via the cold-boot notification.
    if (!gpsOk && context.mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(appState.tr('auto_detect_failed_title')),
          content: Text(appState.tr('auto_detect_failed_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(appState.tr('ok')),
            ),
          ],
        ),
      );
    }

    return true;
  }

  // REAL BUG FIX (2026-08-28, "bug silencioso en auto-detección"): the
  // 30s poll used to only ever check for a gig app, never whether the
  // GPS engine underneath was still actually alive -- it could die
  // AFTER a successful activation (permission revoked mid-session,
  // Android killing the plugin, etc.) with nothing ever re-checking.
  // One attempted restart per idle poll tick; a real notification only
  // fires with a cooldown (not every 30s) so a genuinely stuck state
  // doesn't spam the driver.

  Future<void> _pollForGigApp() async {
    if (!_armed) return;

    final state = TrackingController.currentState;

    if (state != TrackingState.idle) {
      // A trip is open: handleRunningFix follows the apps from the GPS fixes.
      lastDetectedGigAppId = null;
      return;
    }

    // Android sleeps without GPS on purpose (see drive_wake.dart): an idle engine is
    // not a fault there, and starting it here would bring its notification back.
    if (!DriveWake.isSupported && !BackgroundGpsService.isRunning) {
      final restarted = await BackgroundGpsService.startTracking();
      if (!restarted) {
        DiagLog.add('health check: GPS engine did not restart');
        return;
      }
    }

    if (_promptActive) return;
    // General: no app decides anything, driving does (see handleIdleFix).
    if (await _isGeneralMode()) {
      lastDetectedGigAppId = null;
      return;
    }
    // 2026-11-05: opening the app is no longer enough. The trip starts when the
    // driver also MOVES (see handleIdleFix), so a gig app left open at home
    // never records a trip.
    lastDetectedGigAppId = await GigAppDetectionService.instance.detectActiveGigAppId(await _selectedApps());
  }

  /// REVISED 2026-08-28, explicit user request: "la detección automática
  /// de gig app es automática... el flujo no debe ni tiene que pedirle a
  /// un cliente que toque una notificación para hacer switch." The old
  /// "ask" mode (default, notification said "Open ControlMiles to switch
  /// to X", required a tap) contradicted the whole premise of this
  /// feature -- auto-detect already starts trips with zero taps, a
  /// mid-trip app change is exactly the same kind of event and gets the
  /// same treatment now. Every detected app change closes the old
  /// section and opens a new one immediately, no toggle, no
  /// confirmation, matching _autoStartTrip's own silent-by-default
  /// design one section down.
  ///
  /// 2026-11-07: moved from the 30 s timer to the GPS fixes. The timer lives only in
  /// the open app, so a trip the phone started with the app closed never switched;
  /// fixes reach whichever engine is running the trip. A parked car sends no fixes and
  /// adds no miles, so the switch simply lands on the first fix of the next leg.
  bool _switchChecking = false;
  DateTime? _lastSwitchCheckAt;

  Future<void> handleRunningFix() async {
    if (TrackingController.currentState != TrackingState.running) return;
    final now = DateTime.now();
    final last = _lastSwitchCheckAt;
    if (_switchChecking || (last != null && now.difference(last) < _appLookupEvery)) return;
    _switchChecking = true;
    _lastSwitchCheckAt = now;
    try {
      // General is one section from start to end; switching by app belongs to Apps mode.
      if (!await _isArmedNow() || await _isGeneralMode()) return;
      final gigAppId = await GigAppDetectionService.instance.detectActiveGigAppId(await _selectedApps());
      if (gigAppId != null && gigAppId != TrackingController.currentGigApp) {
        await TrackingController.switchSection(gigAppId);
      }
    } finally {
      _switchChecking = false;
    }
  }

  /// Registered once from BackgroundGpsService.initialize()'s
  /// onMotionChange listener -- fires on EVERY stationary<->moving
  /// transition regardless of armed state. REVISED 2026-08-28 (explicit
  /// user request, see file header): motion alone no longer starts or
  /// prompts for a trip -- it used to fall back to a confirmation
  /// screen the user asked to remove entirely, and that fallback could
  /// win a real race against the gig-app poll (confirmed live: a
  /// genuine driver report using GoShare). This method now only
  /// restarts the background service when the driver goes stationary
  /// again, so auto-detect stays armed for the next real gig-app
  /// detection instead of silently going deaf -- unrelated plumbing,
  /// not a trip trigger.
  Future<void> handleMotionChange(bool isMoving) async {
    if (!_armed) return;
    if (DriveWake.isSupported) return; // Android sleeps between drives on purpose
    if (TrackingController.currentState != TrackingState.idle) return;
    if (isMoving) return;

    // The plugin can auto-stop itself once stationary again (its own
    // stopTimeout behavior) -- restart so we stay armed for the NEXT
    // trip instead of silently going deaf after the first one.
    await BackgroundGpsService.startTracking();
  }

  // "General" work mode (2026-11-05, explicit decision): the phone starts a trip
  // by itself when the driver is really driving, whatever app is open, and
  // asks what it was for once it is over. "Gig" mode keeps the app trigger above.
  static const String _workModePrefKey = 'controlmiles_work_mode';
  static const double _drivingSpeedMps = 4.5; // ~10 mph, faster than walking or cycling
  static const double _fastDrivingSpeedMps = 7.0; // ~15 mph: one fix is enough
  static const Duration _restartCooldown = Duration(minutes: 5);
  static const Duration _appLookupEvery = Duration(seconds: 20);
  // How long after leaving a selected gig app the driver can start moving and still
  // be on that gig (a map, a call). Past this, the drive is not that app's.
  static const Duration _gigAppLeftWithin = Duration(minutes: 15);
  int _drivingFixes = 0;
  DateTime? _lastAppLookupAt;

  Future<bool> _isGeneralMode() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_workModePrefKey) ?? const []).contains('general');
  }

  /// The driver's "track by itself only on these days and hours" choice
  /// (Settings). [days, startMinute, endMinute]; not set = always. An end time at
  /// or before the start means the window runs past midnight.
  Future<bool> _isWithinAutoSchedule(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getStringList('controlmiles_auto_schedule');
    if (s == null || s.length != 3) return true;
    final days = s[0].split(',').map(int.tryParse).whereType<int>().toSet();
    final start = int.tryParse(s[1]) ?? 0;
    final end = int.tryParse(s[2]) ?? 1440;
    final minute = now.hour * 60 + now.minute;
    final today = now.weekday;
    final yesterday = today == 1 ? 7 : today - 1;
    if (start < end) return days.contains(today) && minute >= start && minute < end;
    // Past midnight: the evening belongs to today, the early hours to yesterday.
    return (days.contains(today) && minute >= start) || (days.contains(yesterday) && minute < end);
  }

  /// Armed in this isolate, or armed according to the saved setting. The second
  /// is what the headless isolate Android starts while the app is closed sees:
  /// it never ran setEnabled, so its own flag is false.
  Future<bool> _isArmedNow() async {
    final prefs = await SharedPreferences.getInstance();
    // The headless isolate's cache can be older than what the app saved since.
    await prefs.reload();
    if (!_armed && !(prefs.getBool(_enabledPrefKey) ?? false)) return false;
    if (!hasShiftStartOdometer) {
      shiftStartOdometerValue = double.tryParse(prefs.getString(_shiftOdoValueKey) ?? '');
      shiftStartOdometerImageUrl = prefs.getString(_shiftOdoImageKey);
    }
    return true;
  }

  /// Every GPS fix that arrives while no trip is running -- from the app or from
  /// the headless isolate (app closed). The phone starts the trip when the
  /// driver really is driving (2026-11-05, explicit decision):
  ///  * General: whatever app is open.
  ///  * Apps (Premium "gig"): only when one of the apps the driver marked was
  ///    the last one opened, i.e. they opened it and then moved.
  Future<void> handleIdleFix({required double speedMps, required double accuracy}) async {
    if (_promptActive) return;
    if (accuracy > 100 || speedMps < _drivingSpeedMps) {
      _drivingFixes = 0;
      return;
    }
    if (!await _isArmedNow()) return;
    final stoppedAt = TrackingController.lastStopAt;
    if (stoppedAt != null && DateTime.now().difference(stoppedAt) < _restartCooldown) return;
    if (speedMps < _fastDrivingSpeedMps && ++_drivingFixes < 2) return;
    _drivingFixes = 0;

    if (await _isGeneralMode()) {
      // Only inside the days/hours the driver chose; nothing chosen = always.
      if (!await _isWithinAutoSchedule(DateTime.now())) return;
      await _autoStartTrip('custom');
      return;
    }
    final now = DateTime.now();
    final last = _lastAppLookupAt;
    if (last != null && now.difference(last) < _appLookupEvery) return;
    _lastAppLookupAt = now;
    // The app the driver opened may already be behind the map it sent them to.
    final gigAppId = await GigAppDetectionService.instance.detectActiveGigAppId(
      await _selectedApps(),
      leftWithin: _gigAppLeftWithin,
    );
    if (gigAppId == null) return;
    lastDetectedGigAppId = gigAppId;
    await _autoStartTrip(gigAppId);
  }

  /// A wake-up from [DriveWake]. "vehicle": Android thinks the phone is in a vehicle;
  /// "fence": the phone left the place it was parked. Neither proves the car is moving
  /// (a driver sitting in a parked car is "in a vehicle" too: seen 2026-11-07, five
  /// empty trips in ten minutes while stationary), so both are checked with a short
  /// burst of GPS first (see [_verifyDriving]): the trip starts only when the speed is
  /// really that of a vehicle. The parking spot is kept as the real start.
  static const String _anchorPrefKey = 'controlmiles_trip_anchor';
  static const Duration _verifyWindow = Duration(seconds: 150);

  Future<void> onWake(WakeInfo info) async {
    DiagLog.add('wake', {'source': info.source, 'anchor': info.hasAnchor ? '${DiagLog.coarse(info.lat!)},${DiagLog.coarse(info.lng!)}' : 'none'});
    if (!await _isArmedNow()) {
      DiagLog.add('wake ignored: detection is not armed');
      return;
    }
    if (!await _serverPlanAllowsAutomaticTrips()) return;
    if (await _hasOpenTrip()) {
      DiagLog.add('wake ignored: a trip is already open');
      return;
    }
    if (info.hasAnchor) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_anchorPrefKey, '${info.lat},${info.lng},${DateTime.now().millisecondsSinceEpoch}');
    }
    // A vehicle signal gets a little longer: in Apps mode the driver opens the app first.
    await _verifyDriving(info.source == 'vehicle' ? const Duration(seconds: 200) : _verifyWindow);
  }

  /// The phone left its parking fence: listen with the light GPS profile for a couple
  /// of minutes. [handleIdleFix] starts the trip as soon as the speed is really that
  /// of a vehicle (and, in Apps mode, one of the driver's apps is in front). If it
  /// never is, it was not a drive: the GPS goes back to sleep and the fence moves here.
  bool _verifying = false;

  Future<void> _verifyDriving(Duration window) async {
    // Android can repeat the vehicle signal while the phone sits in a parked car: one
    // check at a time.
    if (_verifying) return;
    _verifying = true;
    try {
      await _verifyDrivingNow(window);
    } finally {
      _verifying = false;
    }
  }

  Future<void> _verifyDrivingNow(Duration window) async {
    if (await _isGeneralMode()) {
      if (!await _isWithinAutoSchedule(DateTime.now())) {
        await DriveWake.refreshFence();
        return;
      }
    } else {
      if ((await _selectedApps()).isEmpty) {
        await DriveWake.refreshFence();
        return;
      }
    }

    final started = await BackgroundGpsService.startTracking();
    if (!started) {
      await DriveWake.refreshFence();
      return;
    }
    final deadline = DateTime.now().add(window);
    while (DateTime.now().isBefore(deadline) && TrackingController.currentState == TrackingState.idle) {
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    // This isolate only knows its own trip: another engine may have started one, and
    // stopping here would turn off that trip's GPS (seen 2026-11-06).
    if (TrackingController.currentState == TrackingState.idle && !await _hasOpenTrip()) {
      // No trip came of it: forget this wake-up's parking spot, so a trip the driver
      // starts by hand a minute later never borrows it.
      (await SharedPreferences.getInstance()).remove(_anchorPrefKey);
      await BackgroundGpsService.stopTracking();
      await DriveWake.refreshFence();
    }
  }

  /// Automatic trips are Premium, and the database decides that, not the phone's saved
  /// copy: a plan can lapse with the app closed for days. When it did, detection turns
  /// itself off. With no signal the answer is yes, so a real drive is not lost.
  Future<bool> _serverPlanAllowsAutomaticTrips() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('premium_entitled')
          .eq('id', user.id)
          .maybeSingle();
      if (row?['premium_entitled'] == true) return true;
    } catch (_) {
      return true;
    }
    DiagLog.add('automatic detection off: the account is not Premium');
    _armed = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledPrefKey, false);
    await prefs.setBool('controlmiles_premium_entitled', false);
    await DriveWake.unregister();
    return false;
  }

  /// A trip is already recording (this isolate does not know about the one the open
  /// app, or another wake-up, may have started).
  Future<bool> _hasOpenTrip() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return true; // nobody signed in: nothing to record
    try {
      final rows = await Supabase.instance.client
          .from('sessions')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_closed', false)
          // A session abandoned long ago must not block every future automatic trip.
          .gte('start_time', DateTime.now().toUtc().subtract(const Duration(hours: 24)).toIso8601String())
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return true; // cannot tell: do not risk a second trip
    }
  }

  /// Explicit user request (2026-08-27): once a specific gig app is
  /// identified with real confidence, start the trip silently -- no
  /// confirmation screen. The mandatory-odometer requirement is still
  /// fully honored (see requestEnable's own camera capture at
  /// activation time, carried forward via useAutoDetectOdometer below),
  /// so a manual "tap to confirm" per detected trip no longer served
  /// any evidentiary purpose -- it was pure friction. Only an
  /// informational notification fires afterward, matching the pattern
  /// already used for mid-trip auto-switch.
  Future<void> _autoStartTrip(String gigAppId) async {
    if (_promptActive) return;
    _promptActive = true;
    _promptStuckTimer?.cancel();
    _promptStuckTimer = Timer(_promptStuckTimeout, () {
      _promptActive = false;
    });

    // startTripFlow needs a real BuildContext (its own context.mounted
    // guard + the OdometerCaptureScreen fallback path) -- NavigatorState
    // extends State<Navigator>, so .context is a genuine live one as
    // long as the widget tree exists, which it normally does even while
    // ControlMiles is backgrounded (not terminated) -- that's the whole
    // premise this polling mechanism already depends on. A null navigator
    // here means the widget tree itself isn't up yet (very early startup
    // race) -- just let the next poll retry rather than crash.
    // No navigator (the app is closed and this runs in the headless isolate):
    // the trip starts without a screen. It only needs one to ask for an
    // odometer photo, and then it does not start (the shift-start reading
    // taken when auto-detect was armed is what a closed-app start carries).
    final nav = NotificationService.instance.navigatorKey?.currentState;

    // Headless isolate: Supabase and the saved account are not loaded yet.
    await SupabaseBootstrap.ensure();
    if (!await _serverPlanAllowsAutomaticTrips()) {
      _promptStuckTimer?.cancel();
      _promptActive = false;
      return;
    }
    // Another isolate (the wake engine, the headless engine) may have started this very
    // trip a moment ago: the server knows, this isolate does not.
    if (await _hasOpenTrip()) {
      DiagLog.add('auto-start skipped: a trip is already open', {'app': gigAppId});
      _promptStuckTimer?.cancel();
      _promptActive = false;
      return;
    }
    DiagLog.add('auto-start', {'app': gigAppId});
    if (TrackingController.currentState != TrackingState.idle) {
      _promptStuckTimer?.cancel();
      _promptActive = false;
      return;
    }

    await TrackingController.startTripFlow(
      context: (nav != null && nav.mounted) ? nav.context : null,
      gigApp: gigAppId,
      useAutoDetectOdometer: true,
    );

    _promptStuckTimer?.cancel();
    _promptActive = false;

    if (TrackingController.currentState == TrackingState.running) {
      TrackingController.autoFlashEvent.value = 'start';
    }
  }

}
