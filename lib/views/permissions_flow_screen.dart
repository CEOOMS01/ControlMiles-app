// Olympus Mont Systems LLC - ControlMiles
// lib/views/permissions_flow_screen.dart
//
// Permissions, one at a time (2026-11-03, explicit request): each step says
// WHY the permission is needed and what stops working at 100% without it;
// when the driver allows it the icon turns into a check and the next step
// slides in over the same background. Replaces the old "ask everything in a
// row" chain that sent people to Settings with no explanation.
//
// Location is the only step that cannot be skipped: with no location there is
// nothing to record. Every other step can be skipped, with the warning shown
// right there; the Settings status card shows what is still missing.

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../services/gig_app_detection_service.dart';
import '../utils/permission_status.dart';

class _Step {
  final PermKind kind;
  final IconData icon;
  final String key; // i18n prefix: perm_flow_<key>_title / _why / _skip
  final bool required;
  const _Step(this.kind, this.icon, this.key, {this.required = false});
}

class PermissionsFlowScreen extends StatefulWidget {
  /// Onboarding must go through the steps; opened later from Settings the
  /// driver may back out at any time.
  final bool dismissible;
  const PermissionsFlowScreen({super.key, this.dismissible = false});

  @override
  State<PermissionsFlowScreen> createState() => _PermissionsFlowScreenState();
}

class _PermissionsFlowScreenState extends State<PermissionsFlowScreen> with WidgetsBindingObserver {
  late final List<_Step> _steps;
  int _index = 0;
  bool _ready = false; // first "skip what is already granted" pass finished
  bool _busy = false;
  bool _success = false; // showing the check before moving on
  bool _needsSettings = false; // asking again will not show a dialog

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _steps = [
      const _Step(PermKind.location, Icons.location_on_rounded, 'location', required: true),
      const _Step(PermKind.locationAlways, Icons.my_location_rounded, 'always'),
      const _Step(PermKind.notifications, Icons.notifications_active_rounded, 'notifications'),
      const _Step(PermKind.motion, Icons.directions_walk_rounded, 'motion'),
      if (Platform.isAndroid) const _Step(PermKind.battery, Icons.battery_charging_full_rounded, 'battery'),
      const _Step(PermKind.camera, Icons.camera_alt_rounded, 'camera'),
      if (GigAppDetectionService.instance.isSupported)
        const _Step(PermKind.usageAccess, Icons.apps_rounded, 'usage'),
    ];
    _advanceFrom(0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from system Settings: if the driver turned it on there, show
  /// the check and move on.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ready && !_busy && !_success) {
      _checkCurrent();
    }
  }

  _Step get _step => _steps[_index];

  /// Moves to the first step at or after [from] that is not already working;
  /// finishes when none is left.
  Future<void> _advanceFrom(int from) async {
    var i = from;
    while (i < _steps.length) {
      final kind = _steps[i].kind;
      // "All the time" cannot be asked before plain location is granted.
      final blocked = kind == PermKind.locationAlways && !await Permission.locationWhenInUse.isGranted;
      if (blocked || await PermissionStatusService.isOk(kind)) {
        i++;
      } else {
        break;
      }
    }
    if (!mounted) return;
    if (i >= _steps.length) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _index = i;
      _ready = true;
      _success = false;
      _needsSettings = false;
    });
  }

  Future<void> _checkCurrent() async {
    if (await PermissionStatusService.isOk(_step.kind)) await _granted();
  }

  Future<void> _granted() async {
    if (!mounted) return;
    setState(() {
      _success = true;
      _busy = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 950));
    await _advanceFrom(_index + 1);
  }

  Future<void> _allow() async {
    if (_busy || _success) return;
    setState(() => _busy = true);
    try {
      if (_needsSettings) {
        if (_step.kind == PermKind.usageAccess) {
          await GigAppDetectionService.instance.openUsageAccessSettings();
        } else {
          await openAppSettings();
        }
        return; // the resume hook re-checks when the driver is back
      }

      PermissionStatus? status;
      switch (_step.kind) {
        case PermKind.location:
          status = await Permission.locationWhenInUse.request();
        case PermKind.locationAlways:
          status = await Permission.locationAlways.request();
        case PermKind.notifications:
          status = await Permission.notification.request();
        case PermKind.motion:
          status = await Permission.activityRecognition.request();
        case PermKind.battery:
          status = await Permission.ignoreBatteryOptimizations.request();
        case PermKind.camera:
          status = await Permission.camera.request();
        case PermKind.usageAccess:
          // No system dialog exists: only the Settings screen can grant it.
          await GigAppDetectionService.instance.openUsageAccessSettings();
      }

      if (!mounted) return;
      if (await PermissionStatusService.isOk(_step.kind)) {
        await _granted();
        return;
      }
      // Not granted. "All the time", approximate-only location, a permanent
      // denial and Usage Access all need the Settings screen from here on.
      final needsSettings = status == null ||
          status.isPermanentlyDenied ||
          _step.kind == PermKind.locationAlways ||
          (_step.kind == PermKind.location && status.isGranted);
      setState(() => _needsSettings = needsSettings);
    } finally {
      if (mounted && !_success) setState(() => _busy = false);
    }
  }

  void _skip() {
    if (_busy || _success || _step.required) return;
    _advanceFrom(_index + 1);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final bgColor = isDark ? const Color(0xFF12100C) : const Color(0xFFFAF6EE);
    final cardColor = isDark ? const Color(0xFF1C1812) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E281F) : const Color(0xFFE3D9C4);
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF6B6250);

    return PopScope(
      canPop: widget.dismissible, // onboarding: the only way out is through the steps
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: !_ready
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Image.asset(
                        'assets/images/logo_olympus.png',
                        height: 56,
                        errorBuilder: (_, _, _) => Icon(Icons.shield_rounded, size: 52, color: primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        appState
                            .tr('perm_flow_step_of')
                            .replaceAll('{n}', '${_index + 1}')
                            .replaceAll('{total}', '${_steps.length}'),
                        style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var i = 0; i < _steps.length; i++)
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: i <= _index ? primary : borderColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 380),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween(begin: const Offset(0.15, 0), end: Offset.zero).animate(animation),
                              child: child,
                            ),
                          ),
                          child: SingleChildScrollView(
                            key: ValueKey(_index),
                            padding: const EdgeInsets.only(top: 28),
                            child: _stepBody(appState, primary, cardColor, borderColor, textColor, subTextColor),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (_busy || _success) ? null : _allow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : Text(
                                  appState.tr(_needsSettings ? 'perm_flow_open_settings' : 'perm_flow_allow').toUpperCase(),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                      ),
                      SizedBox(
                        height: 48,
                        child: _step.required
                            ? null
                            : TextButton(
                                onPressed: (_busy || _success) ? null : _skip,
                                child: Text(appState.tr('perm_flow_not_now'), style: TextStyle(color: subTextColor)),
                              ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _stepBody(AppState appState, Color primary, Color cardColor, Color borderColor, Color textColor,
      Color subTextColor) {
    final step = _step;
    const green = Color(0xFF2E9E5B);
    final iconColor = _success ? green : primary;

    // After allowing location, a phone that gave only "approximate" lands here
    // again: say exactly what to change instead of repeating the same text.
    final preciseHint = step.kind == PermKind.location && _needsSettings;

    return Column(
      children: [
        // The effect: the icon swaps for a check that pops in, in green.
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconColor.withValues(alpha: 0.14),
            border: Border.all(color: iconColor.withValues(alpha: 0.5), width: 2),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
              child: child,
            ),
            child: Icon(
              _success ? Icons.check_circle_rounded : step.icon,
              key: ValueKey(_success),
              size: 56,
              color: iconColor,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _success ? appState.tr('perm_flow_granted') : appState.tr('perm_flow_${step.key}_title'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _success ? green : textColor),
        ),
        const SizedBox(height: 12),
        Text(
          appState.tr(preciseHint ? 'perm_flow_precise_hint' : 'perm_flow_${step.key}_why'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.4, color: subTextColor),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8A33D).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8A33D).withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFE8A33D)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  appState.tr('perm_flow_${step.key}_skip'),
                  style: TextStyle(fontSize: 13, height: 1.35, color: textColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
