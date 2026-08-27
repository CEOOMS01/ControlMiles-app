// Olympus Mont Systems LLC - ControlMiles
// lib/services/gig_app_detection_service.dart
//
// Premium auto-detect: identifies which gig app is currently in the
// foreground, Android only -- iOS has no public API for this (confirmed
// during design, no workaround exists without a private/App-Store-
// rejected API). This is an AUXILIARY signal, never ground truth -- it
// only pre-selects a gig app on the confirmation prompt, the user still
// has to confirm and enter the odometer. Package names come from the
// gig_app_packages table (verified via real Play Store lookups, backend
// -maintained) -- never hardcoded/guessed here, fetched once and cached
// for the life of the app process.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GigAppDetectionService {
  GigAppDetectionService._internal();
  static final GigAppDetectionService instance =
      GigAppDetectionService._internal();

  static const MethodChannel _channel =
      MethodChannel('controlmiles/gig_app_detection');

  Map<String, String>? _packageToGigAppId; // package_name -> gig_app_id

  bool get isSupported => Platform.isAndroid;

  /// UsageStatsManager access is a "special access" permission -- no
  /// runtime dialog exists for it. This checks whether the user already
  /// granted it via Settings, it does not request anything itself.
  Future<bool> hasUsageAccess() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Opens Settings.ACTION_USAGE_ACCESS_SETTINGS -- the only way to grant
  /// this permission, there's no in-app request dialog for it.
  Future<void> openUsageAccessSettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('openUsageAccessSettings');
    } catch (_) {}
  }

  Future<void> _ensureCatalogLoaded() async {
    if (_packageToGigAppId != null) return;
    try {
      final data = await Supabase.instance.client
          .from('gig_app_packages')
          .select('gig_app_id, package_name')
          .eq('os', 'android');

      final map = <String, String>{};
      for (final row in List<Map<String, dynamic>>.from(data)) {
        final pkg = row['package_name'] as String?;
        final appId = row['gig_app_id'] as String?;
        if (pkg != null && appId != null) map[pkg] = appId;
      }
      _packageToGigAppId = map;
    } catch (e) {
      // Leave null so the NEXT call retries the fetch instead of caching
      // a permanent empty result from a transient network failure.
    }
  }

  /// Returns the ControlMiles gig_app_id (e.g. 'uber', 'doordash') whose
  /// verified package is currently in the foreground, or null if
  /// unsupported, access not granted, or the foreground app isn't a
  /// known gig platform.
  Future<String?> detectActiveGigAppId() async {
    if (!isSupported) return null;
    if (!await hasUsageAccess()) return null;

    await _ensureCatalogLoaded();
    final catalog = _packageToGigAppId;
    if (catalog == null || catalog.isEmpty) return null;

    String? foregroundPackage;
    try {
      foregroundPackage =
          await _channel.invokeMethod<String>('getForegroundPackage');
    } catch (e) {
      return null;
    }
    if (foregroundPackage == null) return null;

    return catalog[foregroundPackage];
  }
}
