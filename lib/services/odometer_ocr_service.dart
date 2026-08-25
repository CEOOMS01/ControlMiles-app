// Olympus Mont Systems LLC - ControlMiles
// lib/services/odometer_ocr_service.dart
// ON-DEVICE OCR · google_mlkit_text_recognition · NO API KEY REQUIRED
//
// FLOW:
//   1. processFrame()  →  called on every camera image stream frame
//   2. _extractCandidates() →  regex + range filter on recognized text blocks
//   3. _stabilize()    →  buffer of last N reads; confirms only when consistent
//   4. Returns OcrScanResult or null (caller decides UI update)
//
// DEPENDENCY (pubspec.yaml):
//   google_mlkit_text_recognition: ^0.11.0

import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result Model
// ─────────────────────────────────────────────────────────────────────────────

class OcrScanResult {
  /// Raw numeric value detected (e.g. 87324.0)
  final double value;

  /// Confidence 0.0–1.0 based on digit count + ML Kit line confidence
  final double confidence;

  /// How many consecutive frames agreed on this value (max = _kStabilizeCount)
  final int stabilityCount;

  /// True once stabilityCount >= _kStabilizeCount
  bool get isStable => stabilityCount >= OdometerOcrService.kStabilizeCount;

  const OcrScanResult({
    required this.value,
    required this.confidence,
    required this.stabilityCount,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal candidate
// ─────────────────────────────────────────────────────────────────────────────

class _Candidate {
  final double value;
  final double confidence;
  const _Candidate(this.value, this.confidence);
}

// ─────────────────────────────────────────────────────────────────────────────
// OdometerOcrService
// ─────────────────────────────────────────────────────────────────────────────

class OdometerOcrService {
  // ── Config ────────────────────────────────────────────────────────────────

  /// Minimum plausible odometer reading in miles/km
  static const int kMinOdometer = 100;

  /// Maximum plausible odometer reading (999,999)
  static const int kMaxOdometer = 999999;

  /// Confidence threshold to surface a result to the UI
  static const double kMinConfidence = 0.55;

  /// How many consecutive frames must agree before isStable = true
  static const int kStabilizeCount = 3;

  /// Tolerance: two reads are "the same" if they differ by less than this %
  static const double kStabilizeTolerance = 0.01; // 1 %

  // ── State ─────────────────────────────────────────────────────────────────

  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Rolling buffer of the last [kStabilizeCount] confident reads
  final List<double> _buffer = [];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Call this from CameraController.startImageStream().
  /// Returns null when nothing useful is found or confidence is too low.
  Future<OcrScanResult?> processFrame(
    CameraImage frame,
    int sensorOrientation,
  ) async {
    try {
      final inputImage = _toInputImage(frame, sensorOrientation);
      if (inputImage == null) return null;

      final recognized = await _recognizer.processImage(inputImage);
      final best = _extractBestCandidate(recognized);
      if (best == null) return null;
      if (best.confidence < kMinConfidence) return null;

      return _stabilize(best);
    } catch (e) {
      debugPrint('[OCR] Frame error: $e');
      return null;
    }
  }

  /// Call when the user manually edits the field or the screen is disposed.
  void resetBuffer() => _buffer.clear();

  void dispose() => _recognizer.close();

  // ── Input image conversion ────────────────────────────────────────────────

  // BUG FIX (la cámara nunca reconocía el odómetro): esta función asumía
  // que concatenar los bytes crudos de los planos Y+U+V de CameraImage
  // (image.planes.expand((p) => p.bytes)) ya formaba un buffer NV21 válido
  // para ML Kit. No es así — YUV_420_888 (lo que entrega
  // camera_android_camerax en Android, el backend de cámara de este
  // proyecto) tiene stride por fila (bytesPerRow) que casi siempre incluye
  // padding más allá del ancho real de la imagen, y los planos U/V vienen
  // semi-planares con su propio pixelStride (normalmente 2, intercalados).
  // Concatenar los bytes tal cual, ignorando stride y pixelStride, produce
  // un buffer con basura — el preview de la cámara se veía perfectamente
  // bien (usa su propio pipeline nativo, sin relación con este código),
  // pero ML Kit recibía una imagen corrupta y jamás detectaba texto.
  //
  // Confirmado además que pedir ImageFormatGroup.nv21 directo en el
  // CameraController NO es una solución confiable en camera_android_camerax
  // — es un bug conocido y abierto del plugin (flutter/flutter#145961):
  // aun pidiendo nv21, el stream sigue reportando (y a veces entregando)
  // formato yuv420, y hay reportes de crashes intermitentes al forzarlo. La
  // solución verificada por la comunidad es reconstruir el NV21 a mano acá,
  // respetando bytesPerRow/bytesPerPixel de cada plano — así no depende de
  // ese comportamiento inestable del plugin nativo.
  InputImage? _toInputImage(CameraImage image, int sensorOrientation) {
    try {
      final rotation = _rotation(sensorOrientation);

      if (image.planes.length >= 3) {
        // Caso Android real: 3 planos (Y, U, V) semi-planares.
        final nv21 = _yuv420ToNv21(image);
        return InputImage.fromBytes(
          bytes: nv21,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.nv21,
            // El buffer reconstruido es compacto (sin padding de stride),
            // así que acá el "ancho de fila" real es el ancho de imagen.
            bytesPerRow: image.width,
          ),
        );
      }

      // Un solo plano (bgra8888 en iOS, o algún dispositivo/versión donde
      // la cámara ya entrega nv21 real de un solo plano) — seguro usar los
      // bytes directos sin reconstrucción.
      final format = _mlKitFormat(image);
      if (format == null) return null;

      return InputImage.fromBytes(
        bytes: image.planes.first.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('[OCR] Image conversion failed: $e');
      return null;
    }
  }

  /// Reconstruye un buffer NV21 (Y completo + V/U intercalado) a partir de
  /// los 3 planos semi-planares de un CameraImage YUV_420_888, respetando
  /// el stride real de cada plano — no asume que bytesPerRow == width ni
  /// que los planos U/V están empaquetados sin espacios.
  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final nv21 = Uint8List(width * height + (width * height) ~/ 2);

    // Plano Y: copiar fila por fila usando el stride real (bytesPerRow
    // puede ser mayor que width por alineación de memoria del hardware).
    var idY = 0;
    final yRowStride = yPlane.bytesPerRow;
    final yPixelStride = yPlane.bytesPerPixel ?? 1;
    for (var row = 0; row < height; row++) {
      final rowStart = row * yRowStride;
      for (var col = 0; col < width; col++) {
        nv21[idY++] = yPlane.bytes[rowStart + col * yPixelStride];
      }
    }

    // Planos U/V: semi-planares en la gran mayoría de dispositivos Android
    // (pixelStride = 2). NV21 requiere el orden V,U intercalado.
    var idUV = width * height;
    final uvWidth = width ~/ 2;
    final uvHeight = height ~/ 2;
    final uRowStride = uPlane.bytesPerRow;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vRowStride = vPlane.bytesPerRow;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (var row = 0; row < uvHeight; row++) {
      final uRowStart = row * uRowStride;
      final vRowStart = row * vRowStride;
      for (var col = 0; col < uvWidth; col++) {
        if (idUV > nv21.length - 2) break;
        final uIndex = uRowStart + col * uPixelStride;
        final vIndex = vRowStart + col * vPixelStride;
        nv21[idUV++] = vIndex < vPlane.bytes.length ? vPlane.bytes[vIndex] : 0;
        nv21[idUV++] = uIndex < uPlane.bytes.length ? uPlane.bytes[uIndex] : 0;
      }
    }

    return nv21;
  }

  InputImageFormat? _mlKitFormat(CameraImage image) {
    switch (image.format.group) {
      case ImageFormatGroup.yuv420:
        return InputImageFormat.yuv420;
      case ImageFormatGroup.bgra8888:
        return InputImageFormat.bgra8888;
      default:
        return null;
    }
  }

  InputImageRotation _rotation(int degrees) {
    switch (degrees) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  // ── Candidate extraction ──────────────────────────────────────────────────

  // BUG FIX (OCR "inventaba" cifras — leía 202,000 en un odómetro que
  // marcaba 150,000): esta función busca dígitos en TODO el texto que ML
  // Kit detecta en el frame completo, no solo en el número que el usuario
  // está centrando en el cuadro de escaneo — un tablero típico tiene varios
  // números visibles (cuentakilómetros parcial, RPM, rango de combustible,
  // reloj, etc.). El desempate anterior literalmente decía "ante empate,
  // preferir el número más grande" — eso hacía que cualquier lectura
  // espuria con más dígitos o mayor valor le ganara a la lectura real y
  // correcta del odómetro con total consistencia, no al azar.
  //
  // Ahora se pondera también qué tan grande es el texto detectado
  // (bounding box) en relación al texto más grande visible en ese mismo
  // frame. El odómetro es, casi siempre, el número que el usuario deja más
  // grande y prominente en el cuadro — no necesariamente el de mayor
  // valor numérico. Ya no hay ningún desempate por valor.
  _Candidate? _extractBestCandidate(RecognizedText recognized) {
    // (valor, digitScore, lineConfidence, altura del bounding box)
    // NOTA: debe ser un record de CAMPOS NOMBRADOS (con {}) — un record
    // posicional como (double value, double digitScore, ...) NO genera
    // getters .value/.digitScore/etc, los ignora y solo deja .$1/.$2/...
    final raw = <({double value, double digitScore, double lineConf, double boxHeight})>[];

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        // Strip spaces, commas, periods — common OCR noise on dashboards
        final clean = line.text.replaceAll(RegExp(r'[\s,.\-]'), '');

        // Match 4–7 consecutive digit sequences
        for (final match in RegExp(r'\d{4,7}').allMatches(clean)) {
          final digits = match.group(0)!;
          final value = int.tryParse(digits);
          if (value == null) continue;
          if (value < kMinOdometer || value > kMaxOdometer) continue;

          final digitScore = _digitScore(digits.length);
          // ML Kit provides confidence per-line on supported platforms;
          // fall back to 0.6 when null (still above our threshold).
          final lineConf = (line.confidence ?? 0.6).clamp(0.0, 1.0);

          raw.add((
            value: value.toDouble(),
            digitScore: digitScore,
            lineConf: lineConf,
            boxHeight: line.boundingBox.height,
          ));
        }
      }
    }

    if (raw.isEmpty) return null;

    // Normalización relativa al texto más grande de ESTE frame — evita
    // depender de coordenadas absolutas de imagen (que cambian con la
    // rotación del sensor) y en cambio compara candidatos entre sí.
    final maxBoxHeight = raw.map((c) => c.boxHeight).reduce((a, b) => a > b ? a : b);

    final candidates = raw.map((c) {
      final sizeScore = maxBoxHeight > 0 ? (c.boxHeight / maxBoxHeight).clamp(0.0, 1.0) : 1.0;
      final confidence = (c.digitScore * 0.40) + (c.lineConf * 0.25) + (sizeScore * 0.35);
      return _Candidate(c.value, confidence);
    }).toList();

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));

    return candidates.first;
  }

  /// 5–6 digit numbers are typical odometer readings → highest score
  double _digitScore(int digits) {
    switch (digits) {
      case 6:
        return 1.00;
      case 5:
        return 0.95;
      case 4:
        return 0.70;
      case 7:
        return 0.65;
      default:
        return 0.40;
    }
  }

  // ── Stabilization buffer ──────────────────────────────────────────────────

  OcrScanResult _stabilize(_Candidate candidate) {
    // Check if this read is consistent with the last buffer entry
    if (_buffer.isNotEmpty) {
      final last = _buffer.last;
      final diff = (candidate.value - last).abs() / last;
      if (diff > kStabilizeTolerance) {
        // New number is significantly different → reset buffer
        _buffer.clear();
      }
    }

    _buffer.add(candidate.value);
    if (_buffer.length > kStabilizeCount) _buffer.removeAt(0);

    // Use the median of the buffer as the confirmed value
    final sorted = List<double>.from(_buffer)..sort();
    final confirmedValue = sorted[sorted.length ~/ 2];

    return OcrScanResult(
      value: confirmedValue,
      confidence: candidate.confidence,
      stabilityCount: _buffer.length,
    );
  }
}