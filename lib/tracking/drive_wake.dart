// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/drive_wake.dart
//
// "Sleeping" detection (2026-11-05): while nothing is happening the app holds no
// GPS and no notification. Two things can wake it (Android only; iOS keeps the old
// path), neither of which depends on one signal alone:
//   * Android says the phone entered a vehicle (Activity Recognition), or
//   * the phone left a small fence around the place it was last parked.
// The wake starts the app's engine (see TripHost). Neither
// signal proves the car is moving (a walk, a bus, sitting in a parked car), so both
// are checked with a short GPS burst before they count as a trip.
// The fence centre is also where the trip really began, so the miles from there to
// the first GPS point are not lost.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auto_trip_detection_service.dart';
import 'tracking_controller.dart';
import '../services/diag_log.dart';

/// What woke the app and where the phone was parked.
class WakeInfo {
  /// "vehicle" (Android said it entered a vehicle) or "fence" (it left the fence).
  final String source;
  final double? lat;
  final double? lng;
  final DateTime? at;
  const WakeInfo({required this.source, this.lat, this.lng, this.at});

  bool get hasAnchor => lat != null && lng != null;
}

class DriveWake {
  DriveWake._();

  static const _channel = MethodChannel('controlmiles/drive_wake');

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Subscribes to the wake-ups. True when Android accepted the vehicle one.
  static Future<bool> register() async {
    if (!isSupported) return false;
    try {
      return (await _channel.invokeMethod<bool>('register')) ?? false;
    } catch (e) {
      debugPrint('[DriveWake] register failed: $e');
      return false;
    }
  }

  static Future<void> unregister() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('unregister');
    } catch (e) {
      debugPrint('[DriveWake] unregister failed: $e');
    }
  }

  /// Puts the fence around where the phone is now (after a trip, or a false alarm).
  static Future<void> refreshFence() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('refreshFence');
    } catch (e) {
      debugPrint('[DriveWake] refreshFence failed: $e');
    }
  }

  static Future<WakeInfo> wakeInfo() async {
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('wakeInfo');
      final atMs = (m?['atMs'] as num?)?.toInt();
      return WakeInfo(
        source: (m?['source'] as String?) ?? 'vehicle',
        lat: (m?['lat'] as num?)?.toDouble(),
        lng: (m?['lng'] as num?)?.toDouble(),
        at: atMs == null || atMs == 0 ? null : DateTime.fromMillisecondsSinceEpoch(atMs),
      );
    } catch (e) {
      debugPrint('[DriveWake] wakeInfo failed: $e');
      return const WakeInfo(source: 'vehicle');
    }
  }
}

/// One engine (2026-11-07, modelled on MileIQ's single drive service): the screens
/// and the trips share the app's only Flutter engine. DriveWakeService starts that
/// engine when the app is closed (a drive may be starting, or Tracelet has a fix
/// for an open trip) and keeps it alive while a trip or a drive check needs it; the
/// app's screen attaches to the same engine when it opens. There is no second
/// copy of a trip anywhere.
class TripHost {
  TripHost._();

  static const _bg = MethodChannel('controlmiles/drive_wake_bg');
  static bool _serviceUp = false;
  static bool _waking = false;
  static String? _held;
  static DateTime _idleSince = DateTime.now();

  static Future<void> start() async {
    if (!DriveWake.isSupported) return;
    _bg.setMethodCallHandler((call) async {
      if (call.method == 'wake') {
        _serviceUp = true;
        unawaited(_onWake());
      }
      return null;
    });
    // A trip that was running when the process died carries on here.
    await TrackingController.initializeOrRecover();
    await _reportDeniedWake();
    // The service may have started this engine for a drive check.
    try {
      if (await _bg.invokeMethod<bool>('hello') == true) {
        _serviceUp = true;
        unawaited(_onWake());
      }
      _serviceUp = true;
    } catch (_) {}
    Timer.periodic(const Duration(seconds: 3), (_) => unawaited(_tick()));
  }

  /// Android refused a drive check while the app was closed: leave it in the log.
  static Future<void> _reportDeniedWake() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final ms = prefs.getInt('cm_wake_denied_ms');
      if (ms == null) return;
      DiagLog.add('wake denied by Android', {'at': DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String()});
      await prefs.remove('cm_wake_denied_ms');
    } catch (e) {
      debugPrint('[TripHost] could not read the denied wake: $e');
    }
  }

  /// A drive may be starting ("vehicle" or "fence").
  static Future<void> _onWake() async {
    final info = await DriveWake.wakeInfo();
    if (info.source == 'app' || _waking) return;
    _waking = true;
    try {
      await AutoTripDetectionService.instance.onWake(info);
    } finally {
      _waking = false;
    }
  }

  /// While a trip is open the service keeps the engine (only the trip's own
  /// tracking notice shows; a paused trip, with the GPS off, keeps the service's
  /// notice so Android does not stop it). With nothing to do it lets go.
  static Future<void> _tick() async {
    final state = TrackingController.currentState;
    final mode = state == TrackingState.running
        ? 'trip'
        : state == TrackingState.paused
            ? 'paused'
            : null;
    if (mode != null) {
      _idleSince = DateTime.now();
      if (mode == _held && _serviceUp) return;
      try {
        await _bg.invokeMethod('keepAlive', {'notice': mode == 'paused'});
        DiagLog.add('engine held', {'for': mode});
        _held = mode;
        _serviceUp = true;
      } catch (_) {
        // No service yet (a trip started from the button): start it, then hold.
        _serviceUp = false;
        _held = null;
        try {
          await _channel.invokeMethod('startEngine');
        } catch (e) {
          debugPrint('[TripHost] could not start the service: $e');
        }
      }
      return;
    }
    _held = null;
    if (!_serviceUp || _waking) return;
    if (DateTime.now().difference(_idleSince) < const Duration(seconds: 60)) return;
    _serviceUp = false;
    DiagLog.add('engine released');
    try {
      await _bg.invokeMethod('finished');
    } catch (_) {}
  }

  static const _channel = MethodChannel('controlmiles/drive_wake');
}
