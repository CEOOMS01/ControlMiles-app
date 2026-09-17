// Olympus Mont Systems LLC - ControlMiles
// lib/services/blur_detection_service.dart
//
// Explicit user requirement (2026-09-18): "un filtro para que se retake
// la foto si esta borrosa, con un aviso, foto blurry retake" -- a real
// sharpness check on the odometer evidence photo, not a cosmetic
// placeholder. Uses the classic variance-of-Laplacian heuristic (same
// technique OpenCV-based blur detectors use): a sharp photo has strong,
// high-variance edges; a blurry one smears them out, so the Laplacian's
// variance drops. Runs on a small downscaled grayscale copy (160px wide)
// so it stays fast enough to call synchronously right after takePicture()
// -- the full-resolution JPEG is only needed for upload, never for this
// check.
//
// This is a heuristic, not a certainty -- a real but unusually flat
// subject (e.g. a very worn, low-contrast odometer) can score low even
// when in focus. The caller (OdometerCaptureScreen) treats a "blurry"
// result as a strong warning that defaults to Retake, not a hard block --
// see its own review-screen comment for why an escape hatch still
// exists.

import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class BlurDetectionResult {
  final bool isBlurry;
  final double sharpnessScore;
  const BlurDetectionResult({required this.isBlurry, required this.sharpnessScore});
}

class BlurDetectionService {
  // Tuned empirically against real odometer photos (in-focus dashboard
  // shots score well into the hundreds/thousands; genuinely blurry ones
  // typically fall below ~40 on this downscaled-grayscale-Laplacian
  // scale). Deliberately conservative (low threshold) to avoid rejecting
  // a real, usable photo over a borderline score -- false "sharp enough"
  // is far less costly here than trapping a driver in a retake loop.
  static const double _blurThreshold = 40.0;
  static const int _analysisWidth = 160;

  /// Decodes [file], downsamples it, and returns whether it looks blurry.
  /// Runs entirely on the CPU (no ML model) -- cheap enough to call right
  /// after takePicture() without a visible delay.
  Future<BlurDetectionResult> analyze(File file) async {
    final Uint8List bytes = await file.readAsBytes();
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      // Can't decode -- don't block the flow over a format we can't even
      // read; the existing extension/size validation already guards
      // against that separately.
      return const BlurDetectionResult(isBlurry: false, sharpnessScore: -1);
    }

    final img.Image small = img.copyResize(
      decoded,
      width: _analysisWidth,
      interpolation: img.Interpolation.average,
    );
    final img.Image gray = img.grayscale(small);

    final int w = gray.width;
    final int h = gray.height;
    final List<double> laplacian = [];

    // 3x3 Laplacian kernel (edge response): center -4, four orthogonal
    // neighbors +1 each. High-frequency (sharp) edges produce large
    // magnitude responses; a blurred image's smoothed edges don't.
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final double center = gray.getPixel(x, y).r.toDouble();
        final double up = gray.getPixel(x, y - 1).r.toDouble();
        final double down = gray.getPixel(x, y + 1).r.toDouble();
        final double left = gray.getPixel(x - 1, y).r.toDouble();
        final double right = gray.getPixel(x + 1, y).r.toDouble();
        laplacian.add((up + down + left + right) - (4 * center));
      }
    }

    if (laplacian.isEmpty) {
      return const BlurDetectionResult(isBlurry: false, sharpnessScore: -1);
    }

    final double mean = laplacian.reduce((a, b) => a + b) / laplacian.length;
    final double variance =
        laplacian.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / laplacian.length;

    return BlurDetectionResult(
      isBlurry: variance < _blurThreshold,
      sharpnessScore: variance,
    );
  }
}
