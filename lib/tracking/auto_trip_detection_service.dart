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

import 'background_gps_service.dart';
import 'tracking_controller.dart';
import '../logic/app_state.dart';
import '../services/gig_app_detection_service.dart';
import '../services/notification_service.dart';
import '../screens/odometer_capture_screen.dart';
import '../utils/permission_recovery_service.dart';

class AutoTripDetectionService {
  AutoTripDetectionService._internal();
  static final AutoTripDetectionService instance =
      AutoTripDetectionService._internal();

  static const String _enabledPrefKey = 'controlmiles_auto_detect_enabled';
  static const String _shiftOdoValueKey = 'controlmiles_shift_odometer_value';
  static const String _shiftOdoImageKey = 'controlmiles_shift_odometer_image_url';
  static const String _autoSwitchPrefKey = 'controlmiles_auto_switch_gig_app';

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
  // keep polling for the foreground gig app -- if it differs from the
  // one the trip is currently tracking under, either switch silently
  // (autoSwitchGigApp) or surface it as a tappable suggestion on
  // DashboardScreen's status card for the driver to confirm themselves.
  // Never both -- see _pollForMidTripSwitch. Set by AppState.
  // setAutoSwitchGigApp, mirrored here the same way shiftStartOdometer*
  // is (AppState owns persistence, this class holds the live copy the
  // poll actually reads).
  bool autoSwitchGigApp = false;
  String? midTripDetectedGigAppId;
  String? _dismissedMidTripAppId;
  String? _lastPolledCurrentGigApp;

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
  Future<void> setEnabled(bool enabled) async {
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
      _dismissedMidTripAppId = null;
      midTripDetectedGigAppId = null;
      _lastPolledCurrentGigApp = null;
      // Explicit user requirement: turning auto-detect off clears the
      // shift-start reading -- the next activation must capture a fresh
      // one, never silently reuse a stale one from an earlier session.
      await clearShiftStartOdometer();
    }

    if (enabled) {
      await BackgroundGpsService.startTracking();
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
    } else if (TrackingController.currentState == TrackingState.idle) {
      await BackgroundGpsService.stopTracking();
    }
  }

  /// Re-arms on cold app start if the user already had this on -- mirrors
  /// NotificationService.init()'s own re-scheduling of the weekly summary
  /// reminder when it was left enabled.
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
    autoSwitchGigApp = prefs.getBool(_autoSwitchPrefKey) ?? false;

    await setEnabled(true);
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
    final hasPermissions = await PermissionRecoveryService.hasCriticalPermissions();
    if (!hasPermissions) {
      if (context.mounted) await PermissionRecoveryService.showRecoveryDialog(context);
      return false;
    }

    if (!context.mounted) return false;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OdometerCaptureScreen(isStart: true),
      ),
    );

    if (result is! Map || result['success'] != true) return false;

    final rawValue = result['odometer_value'];
    final value = rawValue is num ? rawValue.toDouble() : double.tryParse(rawValue.toString());
    final imageUrl = result['imageUrl'] as String?;
    if (value == null || imageUrl == null) return false;

    await instance.setShiftStartOdometer(value: value, imageUrl: imageUrl);
    await appState.setAutoDetectEnabled(true);
    return true;
  }

  Future<void> _pollForGigApp() async {
    if (!_armed) return;

    final state = TrackingController.currentState;

    if (state == TrackingState.running) {
      await _pollForMidTripSwitch();
      return;
    }

    if (state != TrackingState.idle) {
      // Paused -- switchSection itself only works while running (same
      // gate this class respects), nothing useful to detect right now.
      lastDetectedGigAppId = null;
      return;
    }

    if (_promptActive) return;
    final gigAppId = await GigAppDetectionService.instance.detectActiveGigAppId();
    lastDetectedGigAppId = gigAppId;
    if (gigAppId != null) {
      await _autoStartTrip(gigAppId);
    }
  }

  /// Explicit user follow-up request: if a DIFFERENT gig app gets
  /// detected while already tracking, either switch silently
  /// (autoSwitchGigApp) or surface it as a tappable suggestion on the
  /// status card -- never re-notify for the same detected app on every
  /// 30s poll, and never re-suggest one the driver already dismissed
  /// this trip (until the foreground app changes to something else
  /// first, which resets both guards).
  Future<void> _pollForMidTripSwitch() async {
    final currentGigApp = TrackingController.currentGigApp;

    // Real bug found live (2026-08-27, "no lee Spark Driver/Shipt/Jitsu"):
    // a dismissal only used to clear when the DETECTED app matched the
    // CURRENTLY-tracked one -- but a driver moving app-to-app during a
    // real shift (doordash->roadie->uber->doordash, all real auto-
    // switches this session) changes currentGigApp on every switch
    // WITHOUT ever detecting the OLD tracked app again, so that reset
    // branch could go untouched for the rest of the trip. One old
    // dismissal of e.g. Spark Driver, made while tracking DoorDash,
    // silently suppressed it through every later switch to a totally
    // different app -- confirmed via logs: detection correctly resolved
    // 'walmart_spark' every poll, but switchSection() was never even
    // attempted (no SWITCH_OK/SWITCH_ERROR ever logged), which only the
    // `gigAppId == _dismissedMidTripAppId` early-return explains. Any
    // real change in what's actively tracked -- this class's own auto-
    // switch, a manual carousel switch, a confirmed suggestion -- means
    // an old dismissal no longer applies to the new context.
    if (_lastPolledCurrentGigApp != currentGigApp) {
      _lastPolledCurrentGigApp = currentGigApp;
      _dismissedMidTripAppId = null;
      midTripDetectedGigAppId = null;
    }

    final gigAppId = await GigAppDetectionService.instance.detectActiveGigAppId();

    if (gigAppId == null || gigAppId == currentGigApp) {
      midTripDetectedGigAppId = null;
      _dismissedMidTripAppId = null;
      return;
    }

    if (gigAppId == _dismissedMidTripAppId) return;

    if (autoSwitchGigApp) {
      final switched = await TrackingController.switchSection(gigAppId);
      if (switched) {
        midTripDetectedGigAppId = null;
        await NotificationService.instance.showMidTripAutoSwitchedNotification(gigAppId: gigAppId);
      }
      return;
    }

    if (midTripDetectedGigAppId == gigAppId) return;
    midTripDetectedGigAppId = gigAppId;
    await NotificationService.instance.showMidTripSwitchSuggestedNotification(gigAppId: gigAppId);
  }

  /// Called from DashboardScreen's status card when the driver taps the
  /// "switch" suggestion.
  Future<void> confirmMidTripSwitch() async {
    final gigAppId = midTripDetectedGigAppId;
    if (gigAppId == null) return;
    final switched = await TrackingController.switchSection(gigAppId);
    if (switched) midTripDetectedGigAppId = null;
  }

  /// Called from DashboardScreen's status card when the driver dismisses
  /// the suggestion instead -- keeps tracking under the current app,
  /// and won't re-suggest the SAME detected app again this trip.
  void dismissMidTripSwitch() {
    _dismissedMidTripAppId = midTripDetectedGigAppId;
    midTripDetectedGigAppId = null;
  }

  /// Mirrors setEnabled's split: AppState.setAutoSwitchGigApp owns
  /// persistence, this just updates the live copy the poll reads.
  void setAutoSwitchGigApp(bool value) {
    autoSwitchGigApp = value;
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
    if (TrackingController.currentState != TrackingState.idle) return;
    if (isMoving) return;

    // The plugin can auto-stop itself once stationary again (its own
    // stopTimeout behavior) -- restart so we stay armed for the NEXT
    // trip instead of silently going deaf after the first one.
    await BackgroundGpsService.startTracking();
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
    final nav = NotificationService.instance.navigatorKey?.currentState;
    if (nav == null) {
      _promptStuckTimer?.cancel();
      _promptActive = false;
      return;
    }

    await TrackingController.startTripFlow(
      context: nav.context,
      gigApp: gigAppId,
      useAutoDetectOdometer: true,
    );

    _promptStuckTimer?.cancel();
    _promptActive = false;

    if (TrackingController.currentState == TrackingState.running) {
      await NotificationService.instance.showAutoTripStartedNotification(gigAppId: gigAppId);
    }
  }

}
