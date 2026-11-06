import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/app_state.dart';

/// Tells the driver when a newer build of the app exists. The server keeps one
/// row per app in `app_versions`: `latest_build` is a gentle "update available"
/// (shown once per build), `min_build` is a required update.
class AppUpdateService {
  AppUpdateService._();

  static const _app = 'gig';
  static const _offeredKey = 'app_update_offered_build';
  static bool _shownThisRun = false;

  static Future<void> checkAndPrompt(BuildContext context) async {
    if (_shownThisRun) return;
    try {
      final info = await PackageInfo.fromPlatform();
      final installed = int.tryParse(info.buildNumber) ?? 0;

      final row = await Supabase.instance.client
          .from('app_versions')
          .select('min_build, latest_build, store_url')
          .eq('app', _app)
          .maybeSingle();
      if (row == null) return;

      final minBuild = (row['min_build'] as num?)?.toInt() ?? 0;
      final latest = (row['latest_build'] as num?)?.toInt() ?? 0;
      final url = row['store_url'] as String?;
      if (url == null || installed >= latest && installed >= minBuild) return;

      final required = installed < minBuild;
      final prefs = await SharedPreferences.getInstance();
      if (!required && prefs.getInt(_offeredKey) == latest) return;

      if (!context.mounted) return;
      _shownThisRun = true;
      final tr = context.read<AppState>().tr;
      final go = await showDialog<bool>(
        context: context,
        barrierDismissible: !required,
        builder: (ctx) => PopScope(
          canPop: !required,
          child: AlertDialog(
            title: Text(tr('update_available_title')),
            content: Text(tr(required ? 'update_required_body' : 'update_available_body')),
            actions: [
              if (!required)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(tr('update_later')),
                ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr('update_now')),
              ),
            ],
          ),
        ),
      );

      if (!required) await prefs.setInt(_offeredKey, latest);
      if (go == true) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[AppUpdate] check failed: $e');
    }
  }
}
