// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/auto_trip_detection_service.dart
//
// Premium Gig feature (explicit user requirement). Two independent
// triggers feed the same confirmation prompt:
//
// 1. PRIMARY -- gig app detected in the foreground (Android only, via
//    GigAppDetectionService/UsageStatsManager), polled periodically
//    while armed. Explicit user correction from the original
//    movement-based design: "en principio eso era lo que queria... no
//    por movimiento" -- opening Uber/DoorDash/etc is what should
//    trigger the prompt, not raw device motion.
// 2. FALLBACK -- flutter_background_geolocation's own motion-detection
//    (onMotionChange). Kept because iOS has no gig-app-foreground API
//    at all, and because a driver may start moving without the gig app
//    open yet (e.g. driving TO the pickup zone before going online).
//
// Either way, this service never silently starts a session -- the
// user's own explicit call, over a fully-silent auto-log, was that
// odometer entry stays mandatory "en ese mismo momento" for evidence
// rigor, even though it's less convenient than a silent log. GPS
// distance itself is only ever recorded once the user confirms and
// TrackingController.startTripFlow runs its normal, already-audited
// path -- this service never writes to sessions/session_sections/the
// antifraud engine itself, it only decides WHEN to surface the
// existing manual-start flow automatically instead of waiting for a
// button tap.
//
// v1 scope, disclosed: only trip START is automatic. Ending a trip
// still uses the existing manual End button -- auto-ending wasn't part
// of what was asked for this pass.

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'background_gps_service.dart';
import 'tracking_controller.dart';
import '../services/gig_app_detection_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../routes/app_routes.dart';

class AutoTripDetectionService {
  AutoTripDetectionService._internal();
  static final AutoTripDetectionService instance =
      AutoTripDetectionService._internal();

  static const String _enabledPrefKey = 'controlmiles_auto_detect_enabled';

  // Polling interval for "is a gig app in the foreground right now" --
  // relies on the SAME foreground service flutter_background_geolocation
  // already keeps alive while armed (persistent notification, immune to
  // Android killing the process), not a separate background mechanism.
  static const Duration _gigAppPollInterval = Duration(seconds: 30);

  bool _armed = false;
  bool _promptActive = false;
  Timer? _pollTimer;

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

    if (enabled) {
      await BackgroundGpsService.startTracking();
      if (GigAppDetectionService.instance.isSupported) {
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
    if (enabled) {
      await setEnabled(true);
    }
  }

  Future<void> _pollForGigApp() async {
    if (!_armed || _promptActive) return;
    if (TrackingController.currentState != TrackingState.idle) return;

    final gigAppId = await GigAppDetectionService.instance.detectActiveGigAppId();
    if (gigAppId != null) {
      await _promptForTrip(detectedGigAppId: gigAppId);
    }
  }

  /// Registered once from BackgroundGpsService.initialize()'s
  /// onMotionChange listener -- fires on EVERY stationary<->moving
  /// transition regardless of armed state, so this method is the single
  /// gate deciding whether it matters right now. Secondary/fallback
  /// trigger -- see the file header for why this stays even though
  /// gig-app detection is now primary.
  Future<void> handleMotionChange(bool isMoving) async {
    if (!_armed) return;
    if (TrackingController.currentState != TrackingState.idle) return;

    if (!isMoving) {
      // The plugin can auto-stop itself once stationary again (its own
      // stopTimeout behavior) -- restart so we stay armed for the NEXT
      // trip instead of silently going deaf after the first one.
      await BackgroundGpsService.startTracking();
      return;
    }

    await _promptForTrip();
  }

  Future<void> _promptForTrip({String? detectedGigAppId}) async {
    if (_promptActive) return;
    _promptActive = true;

    await NotificationService.instance.showAutoTripDetectedNotification(
      detectedGigAppId: detectedGigAppId,
    );

    // Only push directly if the app is actually foregrounded with a live
    // navigator -- if backgrounded/terminated, the notification alone is
    // the prompt; tapping it is what brings the app forward.
    final nav = NotificationService.instance.navigatorKey?.currentState;
    if (nav != null) {
      await nav.pushNamed(AppRoutes.autoTripPrompt, arguments: detectedGigAppId);
    }
  }

  /// Called by AutoTripPromptScreen when it closes, confirmed or
  /// dismissed either way -- clears the in-flight guard and cancels the
  /// notification so it doesn't linger in the tray.
  Future<void> clearPrompt() async {
    _promptActive = false;
    await NotificationService.instance.cancelAutoTripDetectedNotification();
  }

  // ============================================================
  // HEADLESS PATH (app terminated/backgrounded, fresh isolate -- none
  // of this class's in-memory state above exists here)
  // ============================================================
  /// Headless-safe: reads SharedPreferences + the local trip checkpoint
  /// directly, same discipline BackgroundGpsService's own terminate
  /// checkpoint already follows for this exact isolate-freshness
  /// problem. Only decides whether to fire the notification -- no
  /// session is ever created from a headless isolate, that only happens
  /// once the user taps through into the full app. Gig-app polling
  /// itself doesn't run headless (Dart Timers don't survive a fresh
  /// headless isolate) -- motion-change is the only trigger available
  /// while the app process itself isn't resident.
  static Future<bool> shouldNotifyForHeadlessMotion() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledPrefKey) ?? false;
    if (!enabled) return false;

    final hasActiveTrip = await LocalStorageService.hasActiveTrip();
    return !hasActiveTrip;
  }
}
