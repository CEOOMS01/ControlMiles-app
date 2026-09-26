// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/live_update_bridge.dart
//
// Thin bridge to the Android side that asks Android 16+ to present the tracking
// notification as a "Live Update" (status-bar chip, lock-screen live
// notification, Samsung Now Bar). See LiveUpdatePromoter.kt: it promotes the
// tracking engine's own notification, it never creates a second one.
//
// Everything here is best-effort and silent: on iOS, on Android below 16, or in
// a background isolate where the channel is not registered, calls simply do
// nothing. The native side also starts itself with the app process, so this
// only makes the request immediate when a trip starts from the UI.

import 'package:flutter/services.dart';

class LiveUpdateBridge {
  static const MethodChannel _channel = MethodChannel('controlmiles/live_update');

  /// Starts (idempotently) the native loop that keeps the tracking
  /// notification promoted.
  static Future<void> ensureRunning() async {
    try {
      await _channel.invokeMethod<void>('ensureRunning');
    } catch (_) {
      // Not available here (iOS, old Android, headless isolate): nothing to do.
    }
  }

  /// Whether the user currently allows this app's Live Updates. False when the
  /// platform does not support them.
  static Future<bool> canPromote() async {
    try {
      return await _channel.invokeMethod<bool>('canPromote') ?? false;
    } catch (_) {
      return false;
    }
  }
}
