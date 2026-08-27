// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/auto_trip_detection_service.dart
//
// Premium Gig feature (explicit user requirement): detects when the
// device starts moving via flutter_background_geolocation's own
// motion-detection (onMotionChange), then interrupts the user
// immediately to confirm the trip + enter the start odometer -- the
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

import 'package:shared_preferences/shared_preferences.dart';

import 'background_gps_service.dart';
import 'tracking_controller.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../routes/app_routes.dart';

class AutoTripDetectionService {
  AutoTripDetectionService._internal();
  static final AutoTripDetectionService instance =
      AutoTripDetectionService._internal();

  static const String _enabledPrefKey = 'controlmiles_auto_detect_enabled';

  bool _armed = false;
  bool _promptActive = false;

  bool get isArmed => _armed;

  /// Called from AppState.setAutoDetectEnabled -- turns the always-on
  /// motion-listening mode on/off. Arming starts BackgroundGpsService
  /// (idempotent) so the plugin's own stationary<->moving state machine
  /// runs even with no active trip; disarming only stops it if there's
  /// no trip actually in progress right now -- toggling the setting off
  /// mid-drive must not kill a real trip's GPS.
  Future<void> setEnabled(bool enabled) async {
    _armed = enabled;
    if (enabled) {
      await BackgroundGpsService.startTracking();
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

  /// Registered once from BackgroundGpsService.initialize()'s
  /// onMotionChange listener -- fires on EVERY stationary<->moving
  /// transition regardless of armed state, so this method is the single
  /// gate deciding whether it matters right now.
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

  Future<void> _promptForTrip() async {
    if (_promptActive) return;
    _promptActive = true;

    await NotificationService.instance.showAutoTripDetectedNotification();

    // Only push directly if the app is actually foregrounded with a live
    // navigator -- if backgrounded/terminated, the notification alone is
    // the prompt; tapping it is what brings the app forward.
    final nav = NotificationService.instance.navigatorKey?.currentState;
    if (nav != null) {
      await nav.pushNamed(AppRoutes.autoTripPrompt);
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
  /// once the user taps through into the full app.
  static Future<bool> shouldNotifyForHeadlessMotion() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledPrefKey) ?? false;
    if (!enabled) return false;

    final hasActiveTrip = await LocalStorageService.hasActiveTrip();
    return !hasActiveTrip;
  }
}
