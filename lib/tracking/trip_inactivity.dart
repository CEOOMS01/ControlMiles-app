// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/trip_inactivity.dart
//
// A trip that stops moving (2026-11-07, explicit decision, same for every plan):
// after 10 minutes without movement the trip is closed by itself, ending when the
// car stopped, and a notice says so. Moving again starts a new trip. The driver
// can always end it sooner with End trip. Personal trips only: fleet trips are
// never touched.
//
// Why the clock lives in SharedPreferences: GPS fixes may be handled in the app
// or in another engine Android started while the app is closed, and a phone that
// sits still sends no fixes at all. The last-motion time is written by whichever
// isolate sees the movement and read back (with a reload) by the timer and by the
// next fix, so they all agree.
//
// What counts as motion: a valid fix at 1.5 m/s or faster, or a jump of 25 m or
// more since the previous one. GPS jitter while parked is smaller than both.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/diag_log.dart';
import '../services/notification_service.dart';
import 'tracking_controller.dart';

class TripInactivity {
  TripInactivity._();

  static const Duration stillFor = Duration(minutes: 10);
  static const double movingSpeedMps = 1.5;
  static const double movingJumpMeters = 25.0;

  static const _kLastMotion = 'trip_last_motion_ms';

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
    } catch (e) {
      debugPrint('[TripInactivity] noteMotion failed: $e');
    }
  }

  /// A trip just started or resumed: the clock starts now.
  static Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastMotion, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[TripInactivity] reset failed: $e');
    }
    ensureWatching();
  }

  /// Timer for when no fixes arrive (the phone is still).
  static void ensureWatching() {
    if (_timer?.isActive ?? false) return;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => check());
  }

  /// The trip ended or paused: stop watching.
  static void clear() {
    _timer?.cancel();
    _timer = null;
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kLastMotion);
      } catch (_) {}
    }());
  }

  /// When the trip should end: the moment the car stopped, once it has been
  /// still for [stillFor]; null while it is still a trip.
  static DateTime? endOfStillTrip({required DateTime lastMotion, required DateTime now}) =>
      now.difference(lastMotion) >= stillFor ? lastMotion : null;

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
      final lastMs = prefs.getInt(_kLastMotion);
      if (lastMs == null) {
        await prefs.setInt(_kLastMotion, DateTime.now().millisecondsSinceEpoch);
        return;
      }
      final endedAt = endOfStillTrip(
        lastMotion: DateTime.fromMillisecondsSinceEpoch(lastMs),
        now: DateTime.now(),
      );
      if (endedAt == null) return;
      DiagLog.add('trip still for 10 minutes: closing it');
      if (await TrackingController.stopTracking(endedAt: endedAt)) {
        await NotificationService.instance.showTripAutoClosed();
      }
    } catch (e) {
      debugPrint('[TripInactivity] check failed: $e');
    } finally {
      _acting = false;
    }
  }
}
