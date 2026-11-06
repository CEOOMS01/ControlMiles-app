// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/brand_loader.dart
//
// The ControlMiles loader (2026-11-04, explicit request): a steering wheel that
// turns without stopping. It is the app's start-up screen and replaces the
// stock spinner wherever the app waits on something.
//
// Drawn in code, not from an image: it stays sharp at any size, takes its color
// from the theme (the brand blue by default, white on a filled button), and
// there is no asset to ship or forget. With "remove animations" on in the
// system settings it stays still instead of spinning.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/cm_colors.dart';
import '../theme/screen_fit.dart';

class BrandLoader extends StatefulWidget {
  /// Side of the square it is drawn in.
  final double size;

  /// Defaults to the theme's primary (brand blue).
  final Color? color;

  /// One full turn. Lower is faster (800 quick, 1800 calm).
  final Duration duration;

  const BrandLoader({
    super.key,
    this.size = 64,
    this.color,
    this.duration = const Duration(milliseconds: 1200),
  });

  /// For inside a button or a list row.
  const BrandLoader.small({super.key, this.color, this.duration = const Duration(milliseconds: 900)}) : size = 22;

  @override
  State<BrandLoader> createState() => _BrandLoaderState();
}

class _BrandLoaderState extends State<BrandLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Loading',
      child: RepaintBoundary(
        child: RotationTransition(
          turns: _controller,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _WheelPainter(color),
          ),
        ),
      ),
    );
  }
}

/// A three-spoke steering wheel seen from the driver's seat, drawn the way the
/// real part is built: a thick rim, a wide hub, and spokes that are thin at the
/// waist and flare where they meet the rim and the hub. The lighter band at
/// 12 o'clock is the centre mark every sport wheel has; it is also what lets
/// the eye see the wheel turn, which a plain symmetric ring would not show.
class _WheelPainter extends CustomPainter {
  final Color color;
  const _WheelPainter(this.color);

  // Unit geometry: the wheel is drawn in a circle of radius 1.
  static const _rimMid = 0.9; // centre line of the rim
  static const _rimWidth = 0.2; // outer edge 1.0, inner edge 0.8
  static const _hubR = 0.3;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(r);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Spokes first, so the rim and hub cover where they join.
    // Left and right droop a little below horizontal; the third points down.
    for (final deg in const [12.0, 90.0, 168.0]) {
      canvas.save();
      canvas.rotate(deg * math.pi / 180);
      canvas.drawPath(_spoke(), fill);
      canvas.restore();
    }

    canvas.drawCircle(
      Offset.zero,
      _rimMid,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _rimWidth
        ..isAntiAlias = true,
    );

    canvas.drawCircle(Offset.zero, _hubR, fill);

    final light = Color.lerp(color, Colors.white, 0.78)!;

    // Horn pad: a lighter disc inside the hub.
    canvas.drawCircle(Offset.zero, _hubR * 0.48, Paint()..color = light);

    // Centre mark on the rim, 12 o'clock.
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: _rimMid),
      -math.pi / 2 - 0.13,
      0.26,
      false,
      Paint()
        ..color = light
        ..style = PaintingStyle.stroke
        ..strokeWidth = _rimWidth
        ..strokeCap = StrokeCap.butt
        ..isAntiAlias = true,
    );
  }

  /// One spoke along +x: flared at the hub, narrow at the waist, flared again
  /// where it runs into the rim.
  Path _spoke() {
    return Path()
      ..moveTo(0.16, -0.17)
      ..quadraticBezierTo(0.5, -0.06, 0.82, -0.15)
      ..lineTo(0.82, 0.15)
      ..quadraticBezierTo(0.5, 0.06, 0.16, 0.17)
      ..close();
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.color != color;
}

/// The start-up screen: the wheel in the logo blue with its line under it, on
/// the same background the system launch screen has. The dashboard shows this
/// same screen while it loads, so the app opens as one continuous turn of the
/// wheel instead of a splash, a spinner and then the app.
class BrandSplash extends StatelessWidget {
  final String tagline;
  const BrandSplash({super.key, required this.tagline});

  @override
  Widget build(BuildContext context) {
    // One start-up screen (2026-11-05): the Android launch screen already shows the
    // ControlMiles logo, 192 dp, centered on this same background. This draws the
    // same logo at the same size and place -- so nothing seems to change -- and the
    // small wheel appears under it. The app is drawn scaled on narrow phones
    // (screen_fit.dart), so the size is divided by that scale to stay 192 dp.
    final scale = WidgetsBinding.instance is ScreenFitBinding ? uiScaleFor(View.of(context)) : 1.0;
    final logo = 192 / scale;
    return Scaffold(
      backgroundColor: CmColors.splashBg,
      body: LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            Center(child: Image.asset('assets/images/logo_controlmiles.png', width: logo, height: logo)),
            Positioned(
              left: 0,
              right: 0,
              top: box.maxHeight / 2 + logo / 2 + 28 / scale,
              child: Center(child: BrandLoader(size: 26 / scale, color: CmColors.logoBlue)),
            ),
          ],
        ),
      ),
    );
  }
}
