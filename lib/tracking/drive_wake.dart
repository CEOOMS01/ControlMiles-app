// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/drive_wake.dart
//
// "Sleeping" detection (2026-11-05): while nothing is happening the app holds no
// GPS and no notification. Two things can wake it (Android only; iOS keeps the old
// path), neither of which depends on one signal alone:
//   * Android says the phone entered a vehicle (Activity Recognition), or
//   * the phone left a small fence around the place it was last parked.
// The wake runs [driveWakeEntry], the one trip engine (see trip_link.dart). Neither
// signal proves the car is moving (a walk, a bus, sitting in a parked car), so both
// are checked with a short GPS burst before they count as a trip.
// The fence centre is also where the trip really began, so the miles from there to
// the first GPS point are not lost.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PluginUtilities;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../services/supabase_bootstrap.dart';
import 'auto_trip_detection_service.dart';
import 'background_gps_service.dart';
import 'tracking_controller.dart';
import 'trip_link.dart';
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
    final handle = PluginUtilities.getCallbackHandle(driveWakeEntry);
    if (handle == null) return false;
    try {
      return (await _channel.invokeMethod<bool>('register', {'handle': handle.toRawHandle()})) ?? false;
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

/// The one trip engine (see trip_link.dart). DriveWakeService runs it when a drive
/// may be starting, when the app sends a command, or when Tracelet has a fix and no
/// engine. It owns every trip until the trip ends, then stops.
@pragma('vm:entry-point')
Future<void> driveWakeEntry() async {
  WidgetsFlutterBinding.ensureInitialized();
  DiagLog.tag = 'engine';
  DiagLog.add('trip engine started');
  const bg = MethodChannel('controlmiles/drive_wake_bg');
  try {
    await SupabaseBootstrap.ensure();
    TripLink.serve();
    await BackgroundGpsService.initialize();
    await BackgroundGpsService.removeLegacyWorkPlaceGeofences();
    // A trip that was running when the last engine died carries on here.
    await TrackingController.initializeOrRecover();
    TripLink.markReady();
    bg.setMethodCallHandler((call) async {
      if (call.method == 'wake') unawaited(_onWake());
      return null;
    });
    unawaited(_onWake());
    await _holdWhileNeeded(bg);
    if (TrackingController.currentState == TrackingState.idle) await BackgroundGpsService.stopTracking();
  } catch (e) {
    debugPrint('[DriveWake] trip engine failed: $e');
    DiagLog.add('trip engine failed', {'error': e});
  }
  TripLink.stopServing();
  DiagLog.add('trip engine finished');
  try {
    await bg.invokeMethod('finished');
  } catch (_) {}
}

bool _waking = false;

/// A drive may be starting ("vehicle" or "fence"). A start for the app's sake has
/// nothing to check.
Future<void> _onWake() async {
  final info = await DriveWake.wakeInfo();
  if (info.source == 'app' || _waking) return;
  _waking = true;
  try {
    await AutoTripDetectionService.instance.onWake(info);
  } finally {
    _waking = false;
  }
}

/// Keeps the engine while a trip is open, a drive is being checked, or the app is
/// using it. A running trip shows only its own tracking notice; a paused one (GPS
/// off) keeps the engine's notice so Android does not stop it.
Future<void> _holdWhileNeeded(MethodChannel bg) async {
  String? shown;
  while (true) {
    final state = TrackingController.currentState;
    final mode = state == TrackingState.running
        ? 'trip'
        : state == TrackingState.paused
            ? 'paused'
            : null;
    if (mode != null && mode != shown) {
      try {
        await bg.invokeMethod('keepAlive', {'notice': mode == 'paused'});
      } catch (_) {}
      shown = mode;
    }
    if (mode == null && !_waking && TripLink.idleFor > const Duration(seconds: 90)) return;
    await Future<void>.delayed(const Duration(seconds: 3));
  }
}
