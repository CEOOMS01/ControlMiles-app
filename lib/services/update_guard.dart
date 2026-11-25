// Olympus Mont Systems LLC - ControlMiles
// lib/services/update_guard.dart
//
// Knows when this launch is the first one after an update (2026-11-24). An update
// closes the app, so the next start is always a cold start. Things that are right for
// a cold start the driver chose (signing out when "Stay signed in" is off) are wrong
// right after an update, and Android can reset a permission when it replaces the app.
// So the first launch of a new build is told apart here and handled gently.

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'diag_log.dart';

class UpdateGuard {
  UpdateGuard._();

  static const _kLastBuild = 'cm_last_launched_build';

  /// True from [noteLaunch] until the app closes: this process is the first one of a
  /// newer build than the one that ran before.
  static bool updatedThisLaunch = false;

  /// The build that ran before this one (null on a first install).
  static int? previousBuild;

  /// Call once at start, before any screen decides where to go.
  static Future<void> noteLaunch() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_kLastBuild);
      updatedThisLaunch = isUpdate(last, current);
      previousBuild = last;
      if (last != current) await prefs.setInt(_kLastBuild, current);
      if (updatedThisLaunch) {
        await DiagLog.add('app updated', {'from': last, 'to': current});
      }
    } catch (e) {
      debugPrint('[UpdateGuard] $e');
    }
  }

  /// A newer build than the one that ran last. A first install (no last build) is not
  /// an update: there was no setup to keep.
  @visibleForTesting
  static bool isUpdate(int? last, int current) =>
      last != null && current > last;

  /// For tests.
  @visibleForTesting
  static void reset() {
    updatedThisLaunch = false;
    previousBuild = null;
  }
}
