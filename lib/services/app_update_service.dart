import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'local_storage_service.dart';

/// A newer build exists and this phone must update before it is used.
class UpdateRequirement {
  final int installed;
  final int required;
  final String storeUrl;
  const UpdateRequirement({
    required this.installed,
    required this.required,
    required this.storeUrl,
  });
}

/// Every new version is a required update (2026-11-24, owner's rule: "when there is a
/// new version the app must be updated before it is used"). The server keeps one row
/// per app in `app_versions`; the build the phone must reach is the higher of
/// `min_build` and `latest_build`. The screen that stops the app is
/// widgets/update_gate.dart; this class only decides and remembers.
///
/// Publishing: set `latest_build` in `app_versions` only when the new build can really
/// be downloaded from Google Play (a staged or late rollout would lock out phones that
/// cannot update yet).
class AppUpdateService {
  AppUpdateService._();

  static const _app = 'gig';
  static const _fallbackStoreUrl =
      'https://play.google.com/store/apps/details?id=com.olimsys.controlmiles';
  static const _kRequiredBuild = 'app_update_required_build';
  static const _kStoreUrl = 'app_update_store_url';
  static const _minGap = Duration(minutes: 10);

  /// Null: the app can be used. Set: show the update screen.
  static final ValueNotifier<UpdateRequirement?> requirement = ValueNotifier(
    null,
  );

  static DateTime? _lastCheck;
  static bool _checking = false;

  /// The build a phone must reach: the higher of the two numbers.
  @visibleForTesting
  static int requiredBuild(int minBuild, int latestBuild) =>
      minBuild > latestBuild ? minBuild : latestBuild;

  /// Blocked when a build is required and this one is older.
  @visibleForTesting
  static bool isBlocked(int installed, int required) =>
      required > 0 && installed < required;

  /// Asks the server and updates [requirement]. Offline, it uses what it learned last
  /// time, so a phone told to update stays told. Not asked again within ten minutes
  /// unless [force] or a requirement is already showing.
  static Future<void> refresh({bool force = false}) async {
    if (_checking) return;
    final last = _lastCheck;
    if (!force &&
        requirement.value == null &&
        last != null &&
        DateTime.now().difference(last) < _minGap) {
      return;
    }
    _checking = true;
    try {
      final info = await PackageInfo.fromPlatform();
      final installed = int.tryParse(info.buildNumber) ?? 0;
      final prefs = await SharedPreferences.getInstance();

      int? required;
      String? url;
      try {
        final row = await Supabase.instance.client
            .from('app_versions')
            .select('min_build, latest_build, store_url')
            .eq('app', _app)
            .maybeSingle()
            .timeout(const Duration(seconds: 10));
        if (row == null) {
          await prefs.remove(_kRequiredBuild);
          await prefs.remove(_kStoreUrl);
          required = 0;
        } else {
          required = requiredBuild(
            (row['min_build'] as num?)?.toInt() ?? 0,
            (row['latest_build'] as num?)?.toInt() ?? 0,
          );
          url = row['store_url'] as String?;
          await prefs.setInt(_kRequiredBuild, required);
          if (url != null) await prefs.setString(_kStoreUrl, url);
        }
      } catch (e) {
        debugPrint(
          '[AppUpdate] server not reached, using what was learned before: $e',
        );
        required = prefs.getInt(_kRequiredBuild);
        url = prefs.getString(_kStoreUrl);
      }

      if (required == null || !isBlocked(installed, required)) {
        requirement.value = null;
        return;
      }
      // A trip being recorded is never cut off by a screen: the notice waits for it.
      if (await LocalStorageService.hasActiveTrip()) {
        requirement.value = null;
        return;
      }
      requirement.value = UpdateRequirement(
        installed: installed,
        required: required,
        storeUrl: (url == null || url.isEmpty)
            ? (prefs.getString(_kStoreUrl) ?? _fallbackStoreUrl)
            : url,
      );
    } catch (e) {
      debugPrint('[AppUpdate] check failed: $e');
    } finally {
      _lastCheck = DateTime.now();
      _checking = false;
    }
  }

  static Future<void> openStore() async {
    final r = requirement.value;
    final url = r?.storeUrl ?? _fallbackStoreUrl;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[AppUpdate] could not open the store: $e');
    }
  }
}
