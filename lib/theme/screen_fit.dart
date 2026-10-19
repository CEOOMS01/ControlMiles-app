// Olympus Mont Systems LLC - ControlMiles
// lib/theme/screen_fit.dart
//
// Screen fit (2026-10-18, testers on stock phones saw every screen too big).
// The layouts were tuned on a phone set to a smaller "display size" (~500 dp
// wide); phones at the factory display size give the app only 360-412 dp
// (a Galaxy S23+ is 384 x 832 dp), so every card, button and gap came out
// ~25-30% bigger relative to the screen.
//
// The app now lays out on a canvas at least [kDesignWidth] dp wide and is
// drawn scaled down to the real screen -- the proportions the owner's phone
// shows. It is done in the binding (a larger device pixel ratio), not with a
// Transform widget: global coordinates stay equal to layout coordinates, so
// the product tour (showcaseview positions its card from global
// coordinates), maps and touches all line up. Tablets and phones already
// that wide are untouched. The system font size is kept inside 0.85x-1.3x.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Narrowest canvas the app lays out on (dp).
const double kDesignWidth = 480;

/// Never shrink more than this, so text stays readable on very small phones
/// or phones with a large display size.
const double kMinUiScale = 0.75;

/// How much the app is shrunk on [view] (1.0 = not at all).
double uiScaleFor(ui.FlutterView view) {
  final logical = view.physicalSize / view.devicePixelRatio;
  return uiScaleForShortestSide(logical.shortestSide);
}

/// Same as [uiScaleFor], for a screen whose shortest side is [shortestSide] dp.
double uiScaleForShortestSide(double shortestSide) =>
    shortestSide <= 0 ? 1.0 : (shortestSide / kDesignWidth).clamp(kMinUiScale, 1.0);

/// Draws every view at its UI scale: the render tree gets a device pixel
/// ratio divided by the scale (so it lays out on the wider canvas) and
/// touches are converted to that canvas. Create it before anything else in
/// main(), in place of WidgetsFlutterBinding.ensureInitialized().
class ScreenFitBinding extends WidgetsFlutterBinding {
  ScreenFitBinding._();

  static WidgetsBinding ensureInitialized() {
    ScreenFitBinding._();
    return WidgetsBinding.instance;
  }

  @override
  ViewConfiguration createViewConfigurationFor(RenderView renderView) {
    final view = renderView.flutterView;
    final physicalConstraints = BoxConstraints.fromViewConstraints(view.physicalConstraints);
    final devicePixelRatio = view.devicePixelRatio * uiScaleFor(view);
    return ViewConfiguration(
      physicalConstraints: physicalConstraints,
      logicalConstraints: physicalConstraints / devicePixelRatio,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  void handlePointerEvent(PointerEvent event) {
    final view = platformDispatcher.view(id: event.viewId);
    final scale = view == null ? 1.0 : uiScaleFor(view);
    if (scale == 1.0) return super.handlePointerEvent(event);
    super.handlePointerEvent(event.copyWith(position: event.position / scale, delta: event.delta / scale));
  }
}

/// Wraps the whole app (MaterialApp.builder): gives every screen, dialog,
/// sheet and the tour a MediaQuery that matches the scaled canvas, and keeps
/// the system text size inside 0.85x-1.3x -- with no ceiling it grew every
/// fixed-height card, button and carousel.
class ScreenFitScope extends StatelessWidget {
  final Widget child;
  const ScreenFitScope({super.key, required this.child});

  static const double minTextScale = 0.85;
  static const double maxTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final textScaler = mq.textScaler.clamp(minScaleFactor: minTextScale, maxScaleFactor: maxTextScale);
    // Only when the binding really draws scaled (not in widget tests).
    final scale = WidgetsBinding.instance is ScreenFitBinding ? uiScaleFor(View.of(context)) : 1.0;
    if (scale == 1.0) {
      return MediaQuery(data: mq.copyWith(textScaler: textScaler), child: child);
    }
    return MediaQuery(
      data: mq.copyWith(
        size: mq.size / scale,
        devicePixelRatio: mq.devicePixelRatio * scale,
        textScaler: textScaler,
        padding: mq.padding / scale,
        viewPadding: mq.viewPadding / scale,
        viewInsets: mq.viewInsets / scale,
        systemGestureInsets: mq.systemGestureInsets / scale,
      ),
      child: child,
    );
  }
}
