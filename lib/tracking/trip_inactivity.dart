// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/trip_inactivity.dart
//
// A trip that stops moving (2026-11-04, explicit decision):
//   * Started / Basic: after 5 minutes without movement the trip is PAUSED and
//     the driver ends it (or resumes it) when they come back.
//   * Premium: after 5 minutes without movement the app asks "Did you end your
//     trip?"; if there is no answer in 5 more minutes, or the driver taps End,
//     the trip is closed for good. Moving again, or tapping Keep going, cancels
//     the question.
// Personal trips only: fleet trips are never touched.
//
// Why the clock lives in SharedPreferences: GPS fixes may be handled in the app
// or in the background isolate Android starts when the app is closed, and a
// phone that sits still sends no fixes at all. The last-motion time is written
// by whichever isolate sees the movement and read back (with a reload) by the
// timer and by the next fix, so they all agree.
//
// What counts as motion: a valid fix at 1.5 m/s or faster, or a jump of 25 m or
// more since the previous one. GPS jitter while parked is smaller than both.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import 'tracking_controller.dart';

class TripInactivity {
  TripInactivity._();

  static const Duration stillFor = Duration(minutes: 5);
  static const Duration answerWithin = Duration(minutes: 5);
  static const double movingSpeedMps = 1.5;
  static const double movingJumpMeters = 25.0;

  static const _kLastMotion = 'trip_last_motion_ms';
  static const _kPromptAt = 'trip_still_prompt_ms';

  static Timer? _timer;
  static DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);
  static DateTime _lastCheck = DateTime.fromMillisecondsSinceEpoch(0);
  static bool _acting = false;

  /// Called for every valid GPS fix of a running trip.
  static Future<void> onFix({required double speedMps, required double jumpMeters}) async {
    ensureWatching();
    if (speedMps >= movingSpeedMps || jumpMeters >= movingJumpMeters) {
      await noteMotion();
    }
    // Checked at most every 20 s from the fix path: it only needs to run when
    // fixes are arriving but the phone has not really moved.
    final now = DateTime.now();
    if (now.difference(_lastCheck) >= const Duration(seconds: 20)) {
      _lastCheck = now;
      unawaited(check());
    }
  }

  /// Stamps "the phone moved just now" (written at most every 10 s).
  static Future<void> noteMotion({bool force = false}) async {
    final now = DateTime.now();
    if (!force && now.difference(_lastWrite) < const Duration(seconds: 10)) return;
    _lastWrite = now;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastMotion, now.millisecondsSinceEpoch);
      // Moving again answers a pending question.
      if (prefs.containsKey(_kPromptAt)) await _dropPrompt(prefs);
    } catch (e) {
      debugPrint('[TripInactivity] noteMotion failed: $e');
    }
  }

  /// A trip just started or resumed: the clock starts now.
  static Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastMotion, DateTime.now().millisecondsSinceEpoch);
      await _dropPrompt(prefs);
    } catch (e) {
      debugPrint('[TripInactivity] reset failed: $e');
    }
    ensureWatching();
  }

  /// Timer for when the app is alive and no fixes arrive (the phone is still).
  static void ensureWatching() {
    if (_timer?.isActive ?? false) return;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => check());
  }

  /// The trip ended or paused: stop watching and forget any question.
  static void clear() {
    _timer?.cancel();
    _timer = null;
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kLastMotion);
        await _dropPrompt(prefs);
      } catch (_) {}
    }());
  }

  static Future<void> _dropPrompt(SharedPreferences prefs) async {
    await prefs.remove(_kPromptAt);
    await NotificationService.instance.cancelTripStillPrompt();
  }

  static Future<void> check() async {
    if (_acting) return;
    if (TrackingController.currentState != TrackingState.running ||
        TrackingController.activeSessionId == null) {
      return;
    }
    // Fleet trips keep their own rules.
    if (TrackingController.activeOrganizationId != null) return;

    _acting = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final lastMs = prefs.getInt(_kLastMotion);
      if (lastMs == null) {
        await prefs.setInt(_kLastMotion, nowMs);
        return;
      }
      final promptMs = prefs.getInt(_kPromptAt);
      final premium = prefs.getBool('controlmiles_premium_entitled') ?? false;

      if (promptMs != null) {
        if (lastMs > promptMs) {
          await _dropPrompt(prefs); // moved after the question
          return;
        }
        if (nowMs - promptMs >= answerWithin.inMilliseconds) {
          await _closeForGood(prefs);
        }
        return;
      }

      if (nowMs - lastMs < stillFor.inMilliseconds) return;

      if (premium) {
        await prefs.setInt(_kPromptAt, nowMs);
        await NotificationService.instance.showTripStillPrompt();
      } else {
        await _pauseForInactivity(prefs);
      }
    } catch (e) {
      debugPrint('[TripInactivity] check failed: $e');
    } finally {
      _acting = false;
    }
  }

  static Future<void> _pauseForInactivity(SharedPreferences prefs) async {
    final paused = await TrackingController.pauseTracking();
    if (paused) {
      await NotificationService.instance.showTripAutoPaused();
    }
  }

  static Future<void> _closeForGood(SharedPreferences prefs) async {
    await _dropPrompt(prefs);
    final stopped = await TrackingController.stopTracking();
    if (stopped) {
      await NotificationService.instance.showTripAutoClosed();
    }
  }

  // ---- the two buttons of the question -------------------------------------

  /// "Keep going": five more minutes before the question comes back.
  static Future<void> continueTrip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastMotion, DateTime.now().millisecondsSinceEpoch);
      await _dropPrompt(prefs);
    } catch (e) {
      debugPrint('[TripInactivity] continueTrip failed: $e');
    }
  }

  /// "End trip".
  static Future<void> endNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _dropPrompt(prefs);
    } catch (_) {}
    if (TrackingController.currentState != TrackingState.idle) {
      await TrackingController.stopTracking();
    }
  }
}
