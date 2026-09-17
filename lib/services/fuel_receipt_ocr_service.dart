// Olympus Mont Systems LLC - ControlMiles
// lib/services/fuel_receipt_ocr_service.dart
//
// Fuel purchase capture, piece 2 of the real IFTA build (explicit user
// request, 2026-09-17): a single-shot OCR pass over a photographed gas
// station receipt -- deliberately NOT the live-camera-stream approach
// odometer_ocr_service.dart uses. An odometer is one clean number the
// driver frames deliberately; a receipt is a printed document with many
// numbers in a layout that varies wildly by station chain, so this runs
// ML Kit ONCE on the captured still photo and regex-scans the full
// recognized text for the handful of fields that matter, rather than
// trying to track/stabilize a single value across frames.
//
// Every field here is a BEST-EFFORT extraction, never trusted blindly --
// the capture screen always shows these as editable fields for the
// driver to confirm or correct before submitting, same philosophy as
// odometer capture's manual-override path. A receipt whose layout this
// can't parse at all still works fine: every field just starts blank for
// manual entry instead of blocking the flow.

import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class FuelReceiptOcrResult {
  final double? gallons;
  final double? pricePerGallon;
  final double? totalCost;
  final DateTime? purchaseDate;

  /// Fraction of the 4 fields above that were actually found -- a rough
  /// signal for the UI (e.g. "review these fields" vs "looks complete"),
  /// not a statistical confidence score.
  final double fieldsFoundRatio;

  const FuelReceiptOcrResult({
    this.gallons,
    this.pricePerGallon,
    this.totalCost,
    this.purchaseDate,
    required this.fieldsFoundRatio,
  });

  static const empty = FuelReceiptOcrResult(fieldsFoundRatio: 0.0);
}

class FuelReceiptOcrService {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<FuelReceiptOcrResult> scanReceipt(File imageFile) async {
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognized = await _recognizer.processImage(inputImage);
      return _parse(recognized.text);
    } catch (_) {
      // Never let a parse failure block the manual-entry fallback --
      // same "silent fallback, never a hard error" contract as
      // SpeedLimitService.lookup().
      return FuelReceiptOcrResult.empty;
    }
  }

  void dispose() => _recognizer.close();

  FuelReceiptOcrResult _parse(String text) {
    final gallons = _extractGallons(text);
    final pricePerGallon = _extractPricePerGallon(text);
    final totalCost = _extractTotal(text);
    final date = _extractDate(text);

    final found = [gallons, pricePerGallon, totalCost, date].where((v) => v != null).length;

    return FuelReceiptOcrResult(
      gallons: gallons,
      pricePerGallon: pricePerGallon,
      totalCost: totalCost,
      purchaseDate: date,
      fieldsFoundRatio: found / 4.0,
    );
  }

  /// Tries a list of patterns in order, returns the first match's captured
  /// number. Multiple patterns exist per field because receipt layouts
  /// genuinely vary (label-before-number vs number-before-label, "GAL"
  /// vs "GALLONS", etc.) -- not redundant, each covers a real format.
  double? _firstMatch(String text, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final value = double.tryParse(match.group(1)!);
        if (value != null) return value;
      }
    }
    return null;
  }

  double? _extractGallons(String text) {
    return _firstMatch(text, [
      RegExp(r'GALLONS?[:\s]+(\d{1,3}\.\d{2,3})', caseSensitive: false),
      RegExp(r'(\d{1,3}\.\d{2,3})\s*GAL(?:LONS?)?\b', caseSensitive: false),
      RegExp(r'\bGAL\b[:\s]*(\d{1,3}\.\d{2,3})', caseSensitive: false),
    ]);
  }

  double? _extractPricePerGallon(String text) {
    return _firstMatch(text, [
      RegExp(r'(?:PRICE\s*/?\s*GAL|PPG|\$\s*/\s*GAL)[:\s]*\$?\s*(\d{1,2}\.\d{2,3})', caseSensitive: false),
      RegExp(r'\$\s*(\d{1,2}\.\d{3})\s*/\s*GAL', caseSensitive: false),
    ]);
  }

  double? _extractTotal(String text) {
    // "SUBTOTAL" and "TAX TOTAL"-style lines contain the substring
    // "TOTAL" too -- explicitly excluded so a subtotal is never mistaken
    // for the real total charged. Checked line by line (not the whole
    // blob) so the exclusion only applies to the line actually being
    // matched, not the whole receipt.
    for (final line in text.split('\n')) {
      final upper = line.toUpperCase();
      if (!upper.contains('TOTAL') || upper.contains('SUBTOTAL')) continue;
      final match = RegExp(r'\$?\s*(\d{1,4}\.\d{2})').firstMatch(line);
      if (match != null) {
        final value = double.tryParse(match.group(1)!);
        if (value != null) return value;
      }
    }
    return null;
  }

  DateTime? _extractDate(String text) {
    final match = RegExp(r'\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\b').firstMatch(text);
    if (match == null) return null;
    final month = int.tryParse(match.group(1)!);
    final day = int.tryParse(match.group(2)!);
    var year = int.tryParse(match.group(3)!);
    if (month == null || day == null || year == null) return null;
    if (year < 100) year += 2000;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    try {
      final date = DateTime(year, month, day);
      // Reject an implausible date (garbled OCR digits) rather than
      // silently accepting a nonsense purchase date -- a receipt from
      // the future or decades in the past is always a misread, never a
      // real fuel purchase.
      final now = DateTime.now();
      if (date.isAfter(now.add(const Duration(days: 1))) || date.isBefore(DateTime(now.year - 2))) {
        return null;
      }
      return date;
    } catch (_) {
      return null;
    }
  }
}
