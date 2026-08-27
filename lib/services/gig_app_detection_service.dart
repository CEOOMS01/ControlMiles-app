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

  /// Public entry point so callers can pre-warm the catalog at a moment
  /// they know has real network access (see AutoTripDetectionService.
  /// setEnabled/restoreFromPrefs) instead of leaving the first-ever fetch
  /// to whenever the poll timer happens to tick -- see _ensureCatalogLoaded's
  /// own comment for why that timing matters.
  Future<void> preloadCatalog() => _ensureCatalogLoaded();

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
      //
      // Real bug found live (2026-08-27, "no lee Spark Driver/Shipt/
      // Jitsu" on a fresh install): this only ever got called lazily,
      // from inside detectActiveGigAppId() -- i.e. from the poll timer,
      // which can just as easily tick for the FIRST time while
      // ControlMiles is already backgrounded (confirmed via logcat: a
      // real cascade of DNS FAIL/isBlocked=true right after the tick,
      // matching Android's background network restrictions). If that
      // first-ever fetch fails, every later poll retries it, but if the
      // app stays backgrounded (the driver is still in the gig app --
      // exactly when detection matters most), it can keep failing for
      // the rest of that armed stint, with detection silently dead the
      // whole time. Callers should prefer preloadCatalog() at a moment
      // guaranteed to have real foreground network access (see
      // AutoTripDetectionService.setEnabled/restoreFromPrefs) instead of
      // relying on this lazy path succeeding eventually.
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
