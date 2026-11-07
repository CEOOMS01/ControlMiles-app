// Olympus Mont Systems LLC - ControlMiles (Gig)
// lib/services/permission_report_service.dart
//
// Tells our server which permissions are ON for this account (2026-11-03), so
// support can see why a phone loses miles in the background without asking the
// driver to read out their settings.
//
// What is sent: on/off per permission, location precise/approximate/denied,
// app version, OS version and phone model -- the "device and diagnostic
// information" the privacy policy already lists. Never a location, never an
// advertising or hardware identifier. One row per user, overwritten (see the
// device_permission_status migration). Best-effort: a failure is logged and
// never shown to the driver.

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/permission_status.dart';

class PermissionReportService {
  PermissionReportService._();

  static const _kLastKey = 'permission_report_last';
  static const Duration _refreshAfter = Duration(hours: 24);

  /// Sends the current state when it changed or is a day old. Safe to call on
  /// every app resume.
  static Future<void> reportIfNeeded() async {
    try {
      if (Supabase.instance.client.auth.currentUser == null) return;

      final fine = await Permission.locationWhenInUse.isGranted;
      final locationState = !fine
          ? 'denied'
          : (await PermissionStatusService.isPrecise() ? 'precise' : 'approximate');

      final params = <String, Object?>{
        'p_location_state': locationState,
        'p_location_always': await Permission.locationAlways.isGranted,
        'p_notifications': await Permission.notification.isGranted,
        'p_motion': await Permission.activityRecognition.isGranted,
        'p_camera': await Permission.camera.isGranted,
        'p_battery_unrestricted':
            Platform.isAndroid ? await Permission.ignoreBatteryOptimizations.isGranted : null,
        'p_usage_access': await PermissionStatusService.isOk(PermKind.usageAccess),
        'p_exact_alarm': null, // no longer used (the app schedules no alarms)
      };

      // Skip when nothing changed since the last report and it is recent.
      final prefs = await SharedPreferences.getInstance();
      final signature = jsonEncode(params);
      final last = prefs.getString(_kLastKey);
      if (last != null) {
        final sep = last.indexOf('|');
        final sentAt = int.tryParse(last.substring(0, sep)) ?? 0;
        final age = DateTime.now().millisecondsSinceEpoch - sentAt;
        if (last.substring(sep + 1) == signature && age < _refreshAfter.inMilliseconds) return;
      }

      final info = await PackageInfo.fromPlatform();
      final device = await _device();
      await Supabase.instance.client.rpc('report_permission_status', params: {
        'p_app_version': '${info.version}+${info.buildNumber}',
        'p_os_version': device.os,
        'p_device_model': device.model,
        ...params,
      });
      await prefs.setString(_kLastKey, '${DateTime.now().millisecondsSinceEpoch}|$signature');
    } catch (e) {
      debugPrint('[PermissionReport] not sent: $e');
    }
  }

  static Future<({String os, String model})> _device() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final a = await plugin.androidInfo;
      return (os: 'Android ${a.version.release} (SDK ${a.version.sdkInt})', model: '${a.manufacturer} ${a.model}');
    }
    if (Platform.isIOS) {
      final i = await plugin.iosInfo;
      return (os: 'iOS ${i.systemVersion}', model: i.utsname.machine);
    }
    return (os: Platform.operatingSystem, model: Platform.operatingSystem);
  }
}
