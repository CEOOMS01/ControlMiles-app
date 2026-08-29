// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/auto_detect_apps_button.dart
//
// Explicit user request (2026-08-27): replaces the small circular icon
// toggle that used to live in TrackingActionButton -- "ese botón de auto
// detección no me gustó". Same underlying feature/state as before
// (AppState.autoDetectEnabled/premiumEntitled), same activation flow
// (AutoTripDetectionService.requestEnable). Every string routed through
// appState.tr() instead of hardcoded English (see
// [[feedback_i18n_hardcoded_strings]] -- this project's own standing
// rule), and .withOpacity(x) converted to the non-deprecated
// .withValues(alpha: x) this codebase already uses everywhere else.
//
// Deliberately NO shine/shimmer animation -- explicit user request
// ("sin ningún tipo de brillo, eso ayuda a la batería"): a first pass
// had a continuous AnimationController (repeating forever, every 2.2s,
// for as long as this widget is visible on the Dashboard) -- cut
// entirely rather than just paused/conditional, since a static gradient
// costs nothing to repaint and a looping animation does, however small.
//
// Second explicit revision, same session: shrunk from a full-width bar
// to a compact, fixed-width slide track, and the circle is now a real
// draggable thumb -- "al tocar el círculo se pueda deslizar a la
// derecha para activar la auto detección". Dragging past the midpoint
// and releasing commits to the opposite state (same premium-lock/
// first-time-explainer/requestEnable path a plain tap already used).
// The label stays centered in the track; the subtitle moved below it,
// outside the dark track, since a shorter track no longer has room for
// two lines.
//
// Third explicit revision (2026-08-29): the thumb's plain-tap shortcut
// (kept in the second revision above "as a quick alternative to
// dragging") was REMOVED -- a simple tap was accidentally starting/
// stopping auto-detection without the user meaning to drag. Only the
// horizontal drag gesture (right past the midpoint = activate, left =
// deactivate) can change state now.
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
import '../routes/app_routes.dart';
import '../tracking/auto_trip_detection_service.dart';

class AutoDetectAppsButton extends StatefulWidget {
  const AutoDetectAppsButton({super.key});

  @override
  State<AutoDetectAppsButton> createState() => _AutoDetectAppsButtonState();
}

class _AutoDetectAppsButtonState extends State<AutoDetectAppsButton> {
  bool _isLoading = false;
  bool _dragging = false;
  double _dragT = 0; // 0..1 while actively dragging

  static const String _autoDetectIntroSeenKey =
      'controlmiles_auto_detect_intro_seen';

  static const double _trackWidth = 220;
  static const double _trackHeight = 56;
  static const double _outerPad = 3;
  static const double _thumbInset = 4;
  static const double _thumbSize = 42;

  double get _innerWidth => _trackWidth - _outerPad * 2;
  double get _maxThumbTravel => _innerWidth - _thumbSize - _thumbInset * 2;

  Future<void> _activate(AppState appState) async {
    if (!appState.premiumEntitled) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(appState.tr('premium_feature_locked_title')),
          content: Text(appState.tr('premium_feature_locked_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(appState.tr('cancel')),
            ),
            // Real Stripe subscription flow now exists (see
            // subscription_screen.dart) -- this used to be an OK-only
            // dead end ("contact support"), now it goes straight to the
            // real self-serve upgrade path.
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, AppRoutes.subscription);
              },
              child: Text(appState.tr('upgrade_plan')),
            ),
          ],
        ),
      );
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

  Future<void> _deactivate(AppState appState) async {
    await appState.setAutoDetectEnabled(false);
    if (mounted) setState(() {});
  }

  void _handleDragStart(bool enabled) {
    setState(() {
      _dragging = true;
      _dragT = enabled ? 1.0 : 0.0;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_maxThumbTravel <= 0) return;
    setState(() {
      _dragT = (_dragT + details.delta.dx / _maxThumbTravel).clamp(0.0, 1.0);
    });
  }

  Future<void> _handleDragEnd(AppState appState, bool enabled) async {
    final shouldEnable = _dragT > 0.5;
    setState(() => _dragging = false);
    if (shouldEnable == enabled) return;
    if (shouldEnable) {
      await _activate(appState);
    } else {
      await _deactivate(appState);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final enabled = appState.autoDetectEnabled;
    final locked = !appState.premiumEntitled;
    final isBusy = _isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final restingT = enabled ? 1.0 : 0.0;
    final t = _dragging ? _dragT : restingT;
    final thumbLeft = _outerPad + _thumbInset + t * _maxThumbTravel;

    return Column(
      children: [
        Semantics(
          button: true,
          enabled: !isBusy,
          label: enabled
              ? appState.tr('auto_detect_apps_title_on')
              : appState.tr('auto_detect_apps_title_off'),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: isBusy ? 0.6 : 1,
            child: Container(
              width: _trackWidth,
              height: _trackHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_trackHeight / 2),
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
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: const Color(0xFF615DE6).withValues(alpha: 0.22),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(_outerPad),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1720),
                  borderRadius: BorderRadius.circular(
                    (_trackHeight - _outerPad * 2) / 2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Real bug found live: a fixed-centered label
                    // overlapped the thumb at its resting position (the
                    // string is nearly as wide as the whole shortened
                    // track). Reserves space on the side OPPOSITE the
                    // thumb's resting side instead, so the two never
                    // overlap regardless of label length or language.
                    Positioned(
                      left: enabled
                          ? 0
                          : (_thumbInset + _thumbSize + 10),
                      right: enabled
                          ? (_thumbInset + _thumbSize + 10)
                          : 0,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Text(
                          (enabled
                                  ? appState.tr('auto_detect_apps_title_on')
                                  : appState.tr('auto_detect_apps_title_off'))
                              .toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: _dragging
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      left: thumbLeft,
                      top: (_trackHeight - _outerPad * 2 - _thumbSize) / 2,
                      child: GestureDetector(
                        // BUG FIX (pedido explícito, 2026-08-29): un simple
                        // tap ya no activa/desactiva -- solo el gesto de
                        // arrastre (derecha = activar, izquierda =
                        // desactivar) puede disparar el flujo. Reversa
                        // deliberada de la decisión anterior (comentario de
                        // cabecera, 2026-08-27) que mantenía el tap como
                        // atajo rápido: ese atajo causaba activaciones
                        // accidentales con un simple toque.
                        onHorizontalDragStart: isBusy
                            ? null
                            : (_) => _handleDragStart(enabled),
                        onHorizontalDragUpdate: isBusy
                            ? null
                            : _handleDragUpdate,
                        onHorizontalDragEnd: isBusy
                            ? null
                            : (_) => _handleDragEnd(appState, enabled),
                        child: Container(
                          width: _thumbSize,
                          height: _thumbSize,
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
                          child: Center(
                            child: isBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : Icon(
                                    locked
                                        ? Icons.lock_outline_rounded
                                        : Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          enabled
              ? appState.tr('auto_detect_apps_subtitle_on')
              : appState.tr('auto_detect_apps_subtitle_off'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
