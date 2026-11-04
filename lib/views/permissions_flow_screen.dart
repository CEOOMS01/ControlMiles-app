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
import '../theme/cm_colors.dart';
import '../widgets/brand_loader.dart';
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

  /// First-time onboarding leaves the camera out: it is asked at the moment an
  /// odometer photo is needed, like MileIQ does. Settings lists it.
  final bool includeCamera;

  /// Same for Usage Access (Premium gig-app detection): it is asked when the
  /// driver turns that feature on, not at first launch.
  final bool includeUsageAccess;

  /// Asks for ONE permission, in the moment it is needed (the camera when an
  /// odometer photo is about to be taken, Usage Access when auto-detect is
  /// turned on). Same page as the first-launch steps, just that one step.
  final PermKind? only;

  /// Onboarding only: runs the first time the driver taps Allow (records the
  /// 18+ / Terms acceptance). While it has not run, the acceptance sentence is
  /// shown under the button, so there is no separate screen or checkbox.
  final Future<void> Function()? onAccept;

  const PermissionsFlowScreen({super.key, this.dismissible = false, this.includeCamera = true, this.includeUsageAccess = true, this.onAccept, this.only});

  /// Opens the single-step page for [kind] and returns when it closes; the
  /// caller re-checks the permission itself (the driver may have skipped it).
  static Future<void> ask(BuildContext context, PermKind kind) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PermissionsFlowScreen(dismissible: true, only: kind)),
    );
  }

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
  bool _accepted = false; // onAccept already ran

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _steps = <_Step>[
      const _Step(PermKind.location, Icons.location_on_rounded, 'location', required: true),
      const _Step(PermKind.locationAlways, Icons.my_location_rounded, 'always'),
      const _Step(PermKind.notifications, Icons.notifications_active_rounded, 'notifications'),
      const _Step(PermKind.motion, Icons.directions_walk_rounded, 'motion'),
      if (Platform.isAndroid) const _Step(PermKind.battery, Icons.battery_charging_full_rounded, 'battery'),
      if (widget.includeCamera || widget.only != null) const _Step(PermKind.camera, Icons.camera_alt_rounded, 'camera'),
      if ((widget.includeUsageAccess || widget.only != null) && GigAppDetectionService.instance.isSupported)
        const _Step(PermKind.usageAccess, Icons.apps_rounded, 'usage'),
    ];
    if (widget.only != null) _steps.removeWhere((st) => st.kind != widget.only);
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
      if (!_accepted && widget.onAccept != null) {
        _accepted = true;
        await widget.onAccept!();
      }
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

    final bgColor = isDark ? CmColors.night : CmColors.cream;
    final cardColor = isDark ? CmColors.nightCard : Colors.white;
    final borderColor = isDark ? CmColors.ink : CmColors.sand;
    final textColor = isDark ? Colors.white : CmColors.ink;
    final subTextColor = isDark ? Colors.white70 : CmColors.inkDim;

    return PopScope(
      canPop: widget.dismissible, // onboarding: the only way out is through the steps
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: !_ready
                ? const Center(child: BrandLoader())
                : Column(
                    children: [
                      if (_steps.length > 1)
                      Row(
                        children: [
                          Expanded(
                            child: Row(
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
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_index + 1}/${_steps.length}',
                            style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w700),
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
                      if (widget.onAccept != null && !_accepted)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            appState.tr('perm_flow_terms_notice'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, height: 1.35, color: subTextColor),
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
                              ? const BrandLoader.small(color: Colors.white)
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
    // The check is the Olimsys brand blue (the theme's primary), not green.
    final iconColor = primary;

    // After allowing location, a phone that gave only "approximate" lands here
    // again: say exactly what to change instead of repeating the same text.
    final preciseHint = step.kind == PermKind.location && _needsSettings;

    return Column(
      children: [
        // The effect: the icon swaps for a check that pops in, in brand blue.
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: 124,
          height: 124,
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
              size: 62,
              color: iconColor,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          appState.tr(step.required ? 'perm_flow_eyebrow_required' : 'perm_flow_eyebrow_recommended'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, letterSpacing: 1.6, fontWeight: FontWeight.w700, color: textColor),
        ),
        const SizedBox(height: 10),
        Text(
          _success ? appState.tr('perm_flow_granted') : appState.tr('perm_flow_${step.key}_title'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, height: 1.15, fontWeight: FontWeight.w800, color: _success ? primary : textColor),
        ),
        const SizedBox(height: 26),
        _infoRow(Icons.check_circle_outline_rounded, appState.tr('perm_flow_${step.key}_head'),
            appState.tr(preciseHint ? 'perm_flow_precise_hint' : 'perm_flow_${step.key}_why'), primary, textColor, subTextColor),
        const SizedBox(height: 18),
        _infoRow(Icons.lock_outline_rounded, appState.tr('perm_flow_safe_title'),
            appState.tr('perm_flow_${step.key}_safe'), primary, textColor, subTextColor),
        const SizedBox(height: 18),
        _infoRow(Icons.info_outline_rounded, appState.tr('perm_flow_without_title'),
            appState.tr('perm_flow_${step.key}_skip'), CmColors.amber, textColor, subTextColor),
      ],
    );
  }

  Widget _infoRow(IconData icon, String heading, String text, Color iconColor, Color textColor, Color subTextColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 28, color: iconColor),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(heading, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
              const SizedBox(height: 3),
              Text(text, style: TextStyle(fontSize: 14, height: 1.35, color: subTextColor)),
            ],
          ),
        ),
      ],
    );
  }
}
