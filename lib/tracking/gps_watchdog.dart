// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/gps_watchdog.dart
//
// Watches the phone's location while a trip runs (2026-10-28, from a real trip: the driver
// switched the phone's GPS off mid-trip, moved on, and the app kept the clock running for
// almost two hours with no position at all).
//
//  * GPS switched off (or location permission taken away): after a few seconds the trip is
//    PAUSED -- no clock, no miles -- and the driver is told to turn GPS back on.
//  * GPS back on while the trip is paused by this watchdog: the driver is told to resume. It
//    never resumes by itself, so a driver who switched GPS off on purpose is not recorded again
//    without noticing.
//  * GPS on but no position for a while (tunnel, garage, bad sky view): the trip keeps running
//    but the driver is told that no miles are counted until the signal returns. Waiting a few
//    minutes before probing avoids false alarms while the vehicle is simply parked (the location
//    engine sends no points then).
//
// A paused trip then follows the existing path: reminders after 1, 2 and 4 hours
// (NotificationService.schedulePauseReminder) and the server closes it after 12 hours without
// activity (close_abandoned_trips).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/audit_service.dart';
import '../services/notification_service.dart';
import 'tracking_controller.dart';

enum GpsIssue { none, gpsOff, permissionOff, gpsBackOn, noSignal }

enum GpsVerdict { ok, gpsOff, permissionOff }

class GpsWatchdog {
  static const Duration checkEvery = Duration(seconds: 5);
  // GPS toggles quickly when the driver fiddles with the quick settings: wait before pausing.
  static const Duration offDebounce = Duration(seconds: 8);
  static const Duration noSignalAfter = Duration(minutes: 3);
  static const String _prefsKey = 'gps_watchdog_paused_by_gps';

  static final ValueNotifier<GpsIssue> issue = ValueNotifier(GpsIssue.none);

  static Timer? _timer;
  static bool _busy = false;
  static bool _pausedByGps = false;
  static DateTime? _offSince;
  static DateTime? _runningSince;
  static DateTime? _lastProbeAt;
  static DateTime? _lastProbeOkAt;
  static DateTime? _noSignalSince;
  static TrackingState _prevState = TrackingState.idle;

  // ---------------------------------------------------------------
  // Pure decisions (unit tested)
  // ---------------------------------------------------------------
  static GpsVerdict verdict({
    required bool serviceEnabled,
    required geo.LocationPermission permission,
  }) {
    if (!serviceEnabled) return GpsVerdict.gpsOff;
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      return GpsVerdict.permissionOff;
    }
    return GpsVerdict.ok;
  }

  /// True once nothing (no tick, no successful probe, no trip start) has shown the phone
  /// alive for [noSignalAfter] and no probe ran in that same window.
  static bool shouldProbe({
    required DateTime now,
    required DateTime? lastAlive,
    required DateTime? lastProbe,
  }) {
    if (lastAlive == null) return false;
    if (now.difference(lastAlive) < noSignalAfter) return false;
    if (lastProbe != null && now.difference(lastProbe) < noSignalAfter) return false;
    return true;
  }

  // ---------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------
  static void start() {
    if (_timer != null) return;
    unawaited(_load());
    _timer = Timer.periodic(checkEvery, (_) => _check());
    try {
      geo.Geolocator.getServiceStatusStream().listen((_) => _check(), onError: (_) {});
    } catch (_) {}
  }

  static Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pausedByGps = prefs.getBool(_prefsKey) ?? false;
    } catch (_) {}
  }

  static Future<void> _persist(bool v) async {
    _pausedByGps = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, v);
    } catch (_) {}
  }

  static Future<void> _clear() async {
    _offSince = null;
    _noSignalSince = null;
    if (_pausedByGps) await _persist(false);
    if (issue.value != GpsIssue.none) {
      issue.value = GpsIssue.none;
      await NotificationService.instance.cancelGpsAlert();
    }
  }

  // ---------------------------------------------------------------
  // Check
  // ---------------------------------------------------------------
  static Future<void> _check() async {
    if (_busy) return;
    _busy = true;
    try {
      final state = TrackingController.currentState;
      if (state == TrackingState.idle) {
        _prevState = state;
        await _clear();
        return;
      }

      final enabled = await geo.Geolocator.isLocationServiceEnabled();
      final permission = await geo.Geolocator.checkPermission();
      final v = verdict(serviceEnabled: enabled, permission: permission);
      final now = DateTime.now();

      if (state == TrackingState.running) {
        if (_prevState != TrackingState.running) _runningSince = now;
        // Running again after a pause this watchdog made: the driver resumed.
        if (_pausedByGps) await _clear();

        if (v != GpsVerdict.ok) {
          _offSince ??= now;
          if (now.difference(_offSince!) >= offDebounce) {
            await _pauseBecause(v == GpsVerdict.gpsOff ? GpsIssue.gpsOff : GpsIssue.permissionOff);
          }
        } else {
          _offSince = null;
          await _checkSignal(now);
        }
      } else {
        // paused
        _offSince = null;
        if (_pausedByGps) {
          final next = v == GpsVerdict.ok
              ? GpsIssue.gpsBackOn
              : (v == GpsVerdict.gpsOff ? GpsIssue.gpsOff : GpsIssue.permissionOff);
          if (issue.value != next) {
            issue.value = next;
            await NotificationService.instance.showGpsAlert(next);
          }
        }
      }
      _prevState = state;
    } catch (e) {
      debugPrint('[GpsWatchdog] check failed: $e');
    } finally {
      _busy = false;
    }
  }

  static Future<void> _pauseBecause(GpsIssue why) async {
    final sessionId = TrackingController.activeSessionId;
    final sectionId = TrackingController.activeSection?.id;
    final miles = TrackingController.activeSection?.totalMiles ?? 0;
    final ok = await TrackingController.pauseTracking();
    if (!ok) return; // try again on the next check
    await _persist(true);
    issue.value = why;
    try {
      await NotificationService.instance.showGpsAlert(why);
      if (sessionId != null) {
        await AuditService.logEvent(
          sessionId: sessionId,
          sectionId: sectionId,
          eventType: why == GpsIssue.gpsOff ? 'GPS_OFF_PAUSE' : 'LOCATION_PERMISSION_OFF_PAUSE',
          payload: {'miles': miles},
        );
      }
    } catch (e) {
      debugPrint('[GpsWatchdog] side effect failed: $e');
    }
  }

  static Future<void> _checkSignal(DateTime now) async {
    final lastTick = TrackingController.lastGpsTickAt;

    // A fresh point after a "no signal" notice: the signal is back.
    if (issue.value == GpsIssue.noSignal &&
        lastTick != null &&
        _noSignalSince != null &&
        lastTick.isAfter(_noSignalSince!)) {
      await _clear();
    }

    final alive = [lastTick, _lastProbeOkAt, _runningSince].whereType<DateTime>().fold<DateTime?>(
          null,
          (a, b) => a == null || b.isAfter(a) ? b : a,
        );
    if (!shouldProbe(now: now, lastAlive: alive, lastProbe: _lastProbeAt)) return;

    _lastProbeAt = now;
    try {
      await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      _lastProbeOkAt = DateTime.now();
      if (issue.value == GpsIssue.noSignal) await _clear();
    } on TimeoutException {
      if (issue.value != GpsIssue.noSignal) {
        _noSignalSince = now;
        issue.value = GpsIssue.noSignal;
        await NotificationService.instance.showGpsAlert(GpsIssue.noSignal);
      }
    } catch (_) {
      // Location errors that are not a timeout are handled by the on/off check above.
    }
  }

  // ---------------------------------------------------------------
  // For the UI
  // ---------------------------------------------------------------
  /// True when a trip can be resumed (GPS on and location permission granted).
  static Future<bool> locationReady() async {
    final v = verdict(
      serviceEnabled: await geo.Geolocator.isLocationServiceEnabled(),
      permission: await geo.Geolocator.checkPermission(),
    );
    return v == GpsVerdict.ok;
  }

  static Future<void> openSettings() async {
    try {
      if (!await geo.Geolocator.isLocationServiceEnabled()) {
        await geo.Geolocator.openLocationSettings();
      } else {
        await geo.Geolocator.openAppSettings();
      }
    } catch (_) {}
  }
}
