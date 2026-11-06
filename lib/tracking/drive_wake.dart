// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/drive_wake.dart
//
// "Sleeping" detection (2026-11-05): while nothing is happening the app holds no
// GPS and no notification. Two things can wake it (Android only; iOS keeps the old
// path), neither of which depends on one signal alone:
//   * Android says the phone entered a vehicle (Activity Recognition), or
//   * the phone left a small fence around the place it was last parked.
// The wake runs [driveWakeEntry] in a short-lived engine. A fence exit is only a
// hint (a walk, a bus, a taxi look the same), so it is checked with a short GPS
// burst before it counts as a trip; "entered a vehicle" starts the trip directly.
// The fence centre is also where the trip really began, so the miles from there to
// the first GPS point are not lost.

import 'dart:io' show Platform;
import 'dart:ui' show PluginUtilities;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../services/supabase_bootstrap.dart';
import 'auto_trip_detection_service.dart';
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

/// Runs in the engine the wake service creates when a drive may be starting.
@pragma('vm:entry-point')
Future<void> driveWakeEntry() async {
  WidgetsFlutterBinding.ensureInitialized();
  DiagLog.tag = 'wake';
  DiagLog.add('wake engine started');
  try {
    await SupabaseBootstrap.ensure();
    await AutoTripDetectionService.instance.onWake(await DriveWake.wakeInfo());
  } catch (e) {
    debugPrint('[DriveWake] wake job failed: $e');
  }
  DiagLog.add('wake engine finished');
  try {
    await const MethodChannel('controlmiles/drive_wake_bg').invokeMethod('finished');
  } catch (_) {}
}
