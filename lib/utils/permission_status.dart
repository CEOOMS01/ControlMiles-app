// Olympus Mont Systems LLC - ControlMiles
// lib/utils/permission_status.dart
//
// One place that answers "is this permission really working?" for the
// step-by-step permissions screen and the Settings status card (2026-11-03).
// Two cases the plain permission status hides:
//  * Android 12+ lets the driver give only APPROXIMATE location: the
//    permission shows as granted but the miles come out poor.
//  * "Allow only while using the app" is granted for location, but not
//    enough to keep a trip recording once the app is in the background.

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart';

import '../services/gig_app_detection_service.dart';

enum PermKind { location, locationAlways, notifications, motion, battery, camera, usageAccess }

class PermissionStatusService {
  PermissionStatusService._();

  /// False only when the driver gave approximate location (Android 12+).
  /// Any failure to find out counts as precise: never nag on a guess.
  static Future<bool> isPrecise() async {
    try {
      return await geo.Geolocator.getLocationAccuracy() != geo.LocationAccuracyStatus.reduced;
    } catch (e) {
      debugPrint('[PermissionStatus] accuracy check failed: $e');
      return true;
    }
  }

  static Future<bool> isOk(PermKind kind) async {
    switch (kind) {
      case PermKind.location:
        return await Permission.locationWhenInUse.isGranted && await isPrecise();
      case PermKind.locationAlways:
        return await Permission.locationAlways.isGranted;
      case PermKind.notifications:
        return Permission.notification.isGranted;
      case PermKind.motion:
        return Permission.activityRecognition.isGranted;
      case PermKind.battery:
        return Permission.ignoreBatteryOptimizations.isGranted;
      case PermKind.camera:
        return Permission.camera.isGranted;
      case PermKind.usageAccess:
        if (!GigAppDetectionService.instance.isSupported) return true;
        return GigAppDetectionService.instance.hasUsageAccess();
    }
  }
}
