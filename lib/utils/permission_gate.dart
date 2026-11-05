// Olympus Mont Systems LLC - ControlMiles
// lib/utils/permission_gate.dart
//
// "Ask, never stay silent" (2026-11-04). Found on a real phone: with every
// permission denied, Start did nothing and said nothing. Anything that needs
// location now goes through here first: it shows the same explanation page as
// the first launch for what is missing, and only if that still is not enough
// does it point to Settings.

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../views/permissions_flow_screen.dart';
import 'permission_recovery_service.dart';
import 'permission_status.dart';

class PermissionGate {
  PermissionGate._();

  static const _kAlwaysOffered = 'perm_gate_always_offered';

  /// True when a trip can record. [requireAlways]: also "all the time" (arming
  /// automatic detection, arrival reminders); without it, location while the
  /// app is in use and precise is enough to start a trip, and "all the time" is
  /// offered once.
  static Future<bool> ensure(BuildContext context, {bool requireAlways = false}) async {
    Future<bool> ready() => requireAlways
        ? PermissionRecoveryService.hasCriticalPermissions()
        : PermissionRecoveryService.hasStartPermissions();

    if (await ready()) return true;
    if (!context.mounted) return false;

    final hasStart = await PermissionRecoveryService.hasStartPermissions();
    if (!context.mounted) return false;
    if (!hasStart) {
      await PermissionsFlowScreen.ask(context, PermKind.location);
    }
    if (!context.mounted) return false;

    if (await PermissionRecoveryService.hasStartPermissions() && !await Permission.locationAlways.isGranted) {
      var offer = requireAlways;
      if (!offer) {
        final prefs = await SharedPreferences.getInstance();
        offer = !(prefs.getBool(_kAlwaysOffered) ?? false);
        if (offer) await prefs.setBool(_kAlwaysOffered, true);
      }
      if (offer && context.mounted) {
        await PermissionsFlowScreen.ask(context, PermKind.locationAlways);
      }
    }

    final ok = await ready();
    if (!ok && context.mounted) await PermissionRecoveryService.showRecoveryDialog(context);
    return ok;
  }
}
