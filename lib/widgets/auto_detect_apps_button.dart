// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/auto_detect_apps_button.dart
//
// Explicit user request (2026-08-27): replaces the small circular icon
// toggle that used to live in TrackingActionButton -- "ese botón de auto
// detección no me gustó". Same underlying feature/state as before
// (AppState.autoDetectEnabled/premiumEntitled), same activation flow
// (AutoTripDetectionService.requestEnable), just a full-width, more
// polished control -- design adapted from a reference the user provided,
// with real ControlMiles state wired in instead of placeholder demo
// state, every string routed through appState.tr() instead of hardcoded
// English (see [[feedback_i18n_hardcoded_strings]] -- this project's own
// standing rule), and .withOpacity(x) converted to the non-deprecated
// .withValues(alpha: x) this codebase already uses everywhere else.
//
// Deliberately NO shine/shimmer animation -- explicit user request
// ("sin ningún tipo de brillo, eso ayuda a la batería"): the reference
// design's continuous AnimationController (repeating forever, every
// 2.2s, for as long as this widget is visible on the Dashboard) was cut
// entirely rather than just paused/conditional, since a static gradient
// costs nothing to repaint and a looping animation does, however small.
//
// Self-contained, matching TrackingActionButton's own pattern: reads
// AppState directly via Provider instead of taking enabled/onPressed
// props from the caller, so the premium-lock + first-time-explainer +
// requestEnable logic lives in exactly one place, not duplicated between
// this widget and its parent screen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/app_state.dart';
import '../tracking/auto_trip_detection_service.dart';

class AutoDetectAppsButton extends StatefulWidget {
  const AutoDetectAppsButton({super.key});

  @override
  State<AutoDetectAppsButton> createState() => _AutoDetectAppsButtonState();
}

class _AutoDetectAppsButtonState extends State<AutoDetectAppsButton> {
  bool _isLoading = false;

  static const String _autoDetectIntroSeenKey =
      'controlmiles_auto_detect_intro_seen';

  Future<void> _handleTap(AppState appState) async {
    if (!appState.premiumEntitled) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(appState.tr('premium_feature_locked_title')),
          content: Text(appState.tr('premium_feature_locked_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(appState.tr('ok')),
            ),
          ],
        ),
      );
      return;
    }

    if (appState.autoDetectEnabled) {
      await appState.setAutoDetectEnabled(false);
      if (mounted) setState(() {});
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final introSeen = prefs.getBool(_autoDetectIntroSeenKey) ?? false;

    if (!introSeen) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(appState.tr('auto_detect_intro_title')),
          content: Text(appState.tr('auto_detect_intro_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(appState.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(appState.tr('continue')),
            ),
          ],
        ),
      );
      await prefs.setBool(_autoDetectIntroSeenKey, true);
      if (proceed != true || !mounted) return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // requestEnable owns the whole activation flow (permission check +
      // shift-start odometer capture + actually arming).
      await AutoTripDetectionService.requestEnable(context, appState);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final enabled = appState.autoDetectEnabled;
    final locked = !appState.premiumEntitled;
    final isDisabled = _isLoading;

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: enabled
          ? appState.tr('auto_detect_apps_title_on')
          : appState.tr('auto_detect_apps_title_off'),
      child: GestureDetector(
        onTap: isDisabled ? null : () => _handleTap(appState),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: isDisabled ? 0.55 : 1,
          child: Container(
            width: double.infinity,
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(31),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF56E0BA),
                  Color(0xFF35BDE8),
                  Color(0xFF6A63E8),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF36DCC3).withValues(alpha: 0.22),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: const Color(0xFF615DE6).withValues(alpha: 0.22),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            padding: const EdgeInsets.all(2.5),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0C1720),
                borderRadius: BorderRadius.circular(29),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF52E2BB), Color(0xFF478EEA)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF47DAD3,
                          ).withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: _isLoading
                        ? Text(
                            appState
                                .tr('auto_detect_apps_checking')
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (enabled
                                        ? appState.tr(
                                            'auto_detect_apps_title_on',
                                          )
                                        : appState.tr(
                                            'auto_detect_apps_title_off',
                                          ))
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.65,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                enabled
                                    ? appState.tr(
                                        'auto_detect_apps_subtitle_on',
                                      )
                                    : appState.tr(
                                        'auto_detect_apps_subtitle_off',
                                      ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFA7B7C5),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(right: 20),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Color(0xFF54DCC2),
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        locked
                            ? Icons.lock_outline_rounded
                            : (enabled
                                  ? Icons.toggle_on_rounded
                                  : Icons.chevron_right_rounded),
                        size: enabled ? 39 : 30,
                        color: locked
                            ? const Color(0xFF90A4B7)
                            : (enabled
                                  ? const Color(0xFF56DFBF)
                                  : const Color(0xFF90A4B7)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
