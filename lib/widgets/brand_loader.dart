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

/// Rim, hub and three spokes (left, right, down) -- a steering wheel seen from
/// the driver's seat.
class _WheelPainter extends CustomPainter {
  final Color color;
  const _WheelPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final stroke = r * 0.16;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final rimR = r - stroke / 2;
    canvas.drawCircle(c, rimR, paint);

    final hubR = r * 0.2;
    final inner = rimR - stroke / 2;
    for (final angle in const [math.pi, 0.0, math.pi / 2]) {
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(c + dir * hubR, c + dir * inner, paint);
    }

    canvas.drawCircle(c, hubR, Paint()..color = color);
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
    return Scaffold(
      backgroundColor: CmColors.splashBg,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 250),
          builder: (_, v, child) => Opacity(opacity: v, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLoader(size: 76, color: CmColors.logoBlue),
              const SizedBox(height: 22),
              Text(
                tagline,
                style: const TextStyle(
                  fontSize: 15,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w500,
                  color: CmColors.inkDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
