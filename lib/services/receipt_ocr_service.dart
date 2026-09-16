// Olympus Mont Systems LLC - ControlMiles
// lib/services/receipt_ocr_service.dart
// ON-DEVICE OCR · google_mlkit_text_recognition · NO API KEY, NO CLOUD CALL
//
// Explicit user requirement (2026-09-16): take the SAME engine/pattern
// already proven in odometer_ocr_service.dart -- ML Kit for text
// detection, a custom scoring/heuristic layer on top for the actual
// domain logic -- and build a SEPARATE, new service for receipts. That
// file stays untouched; nothing here imports or modifies it.
//
// Real difference from the odometer reader, by design: odometer OCR
// processes a live CameraImage stream frame-by-frame (the driver is
// actively centering a moving number in frame) and stabilizes across
// several frames before confirming a value. A receipt is a flat, still
// document captured ONCE as a photo (same capture pattern already used
// for odometer evidence photos, see OdometerCaptureService) -- so this
// runs ML Kit's simpler static-image API (InputImage.fromFilePath) a
// single time per receipt, no NV21 reconstruction, no frame
// stabilization needed.
//
// FLOW:
//   1. scanReceipt(imagePath) -> runs ML Kit once on the captured photo
//   2. _extractMerchant/_extractDate/_extractAmounts -> keyword +
//      regex heuristics over the recognized text lines (same spirit as
//      odometer's digit-run scoring, applied to receipt-shaped fields
//      instead of a single number)
//   3. Returns a ReceiptScanResult with a confidence PER FIELD (never
//      one blended score) -- see fieldConfidence, matching the shared
//      data-model plan (store_assets/document_intelligence_plan.html
//      §7): a wrong total must never reach a tax record un-flagged,
//      even if the merchant name or date came through with low
//      confidence.
//
// DEPENDENCY (pubspec.yaml, already present):
//   google_mlkit_text_recognition: ^0.15.0

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result Model
// ─────────────────────────────────────────────────────────────────────────────

class ReceiptScanResult {
  final String? merchantName;
  final DateTime? transactionDate;
  final double? subtotal;
  final double? tax;
  final double? total;

  /// Per-field confidence, 0.0-1.0. Deliberately a map, not one blended
  /// score -- a caller needs to know SPECIFICALLY which field to ask the
  /// user to confirm, not just "something here is uncertain".
  final Map<String, double> fieldConfidence;

  /// Full recognized text, kept for audit/debugging and as the fallback
  /// a user can read manually if every heuristic below missed.
  final String rawText;

  const ReceiptScanResult({
    required this.merchantName,
    required this.transactionDate,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.fieldConfidence,
    required this.rawText,
  });

  /// True if the single most important field for a tax/expense record
  /// (the total) is missing or below the caller's confidence threshold.
  /// Merchant/date/subtotal/tax being uncertain is worth flagging too
  /// (callers can check fieldConfidence directly for those), but a
  /// missing or low-confidence total is the one case that must never
  /// silently reach a deduction record.
  bool needsReview({double totalThreshold = 0.75}) {
    if (total == null) return true;
    final conf = fieldConfidence['total'] ?? 0.0;
    return conf < totalThreshold;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReceiptOcrService
// ─────────────────────────────────────────────────────────────────────────────

class ReceiptOcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  // ── Keyword vocabularies ─────────────────────────────────────────────────
  // English + Spanish, since ControlMiles already ships both (see
  // lib/i18n/). A receipt's own printed language has nothing to do with
  // the app's UI language, so both lists are always checked regardless
  // of the user's selected locale.

  static const _totalKeywords = [
    'total', 'amount due', 'balance due', 'grand total', 'total due',
    'monto total', 'total a pagar', 'importe total',
  ];
  static const _subtotalKeywords = [
    'subtotal', 'sub total', 'sub-total',
  ];
  static const _taxKeywords = [
    'tax', 'sales tax', 'vat', 'gst', 'hst',
    'impuesto', 'iva',
  ];

  /// Currency amount: optional $ sign, digits with optional thousands
  /// separators, a required decimal point/comma and 2 decimal digits --
  /// deliberately requires the cents, which real receipt totals always
  /// have and stray "quantity: 2" or "table 4"-style numbers usually
  /// don't, cutting a lot of false positives before scoring even runs.
  static final _amountPattern =
      RegExp(r'\$?\s?(\d{1,3}(?:[,.]\d{3})*[.,]\d{2})');

  /// Common receipt date shapes: 09/16/2026, 9-16-26, 2026-09-16,
  /// Sep 16 2026 / 16 Sep 2026. Not exhaustive -- a date this misses
  /// just leaves transactionDate null with fieldConfidence['date'] = 0,
  /// which is the honest outcome, not a guess.
  static final _datePatterns = [
    RegExp(r'\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\b'), // MM/DD/YYYY or DD/MM/YYYY
    RegExp(r'\b(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})\b'), // YYYY-MM-DD
    RegExp(
      r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+(\d{1,2}),?\s+(\d{2,4})\b',
      caseSensitive: false,
    ),
  ];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Runs ML Kit once against a captured receipt photo. [imagePath] is a
  /// local file path -- same as what image_picker/camera already hand
  /// back elsewhere in this app (OdometerCaptureService's own capture
  /// flow), no new capture plumbing needed to call this.
  Future<ReceiptScanResult> scanReceipt(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(inputImage);

    // One flat list of (text, y-position) for every line ML Kit found,
    // top-to-bottom -- most of the heuristics below care about a line's
    // vertical position on the receipt (merchant name is topmost, total
    // is usually near the bottom) more than which "block" ML Kit grouped
    // it into.
    final lines = <({String text, double top})>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        lines.add((text: line.text, top: line.boundingBox.top.toDouble()));
      }
    }
    lines.sort((a, b) => a.top.compareTo(b.top));

    final confidence = <String, double>{};

    final merchant = _extractMerchant(lines, confidence);
    final date = _extractDate(recognized.text, confidence);
    final subtotal = _extractAmount(lines, _subtotalKeywords, 'subtotal', confidence);
    final tax = _extractAmount(lines, _taxKeywords, 'tax', confidence);
    final total = _extractAmount(lines, _totalKeywords, 'total', confidence);

    return ReceiptScanResult(
      merchantName: merchant,
      transactionDate: date,
      subtotal: subtotal,
      tax: tax,
      total: total,
      fieldConfidence: confidence,
      rawText: recognized.text,
    );
  }

  void dispose() => _recognizer.close();

  // ── Merchant name ────────────────────────────────────────────────────────

  // Honest limitation, disclosed rather than hidden: unlike total/tax/
  // subtotal (anchored to a real keyword printed on the receipt),
  // there's no universal "this is the merchant name" marker -- every
  // vendor's receipt just puts it at the top, in whatever font size
  // their POS system uses. Topmost non-empty line is the same simple
  // heuristic every receipt-scanning app starts with; it's right often
  // enough to be useful and deliberately scored LOWER than the
  // keyword-anchored fields below, so a caller building UI on top of
  // this knows to treat it as a starting guess, not a confirmed read.
  String? _extractMerchant(
    List<({String text, double top})> lines,
    Map<String, double> confidence,
  ) {
    for (final line in lines) {
      final trimmed = line.text.trim();
      // Skip lines that are just noise (single characters, pure
      // punctuation) -- real store names are at least a couple of
      // letters.
      if (trimmed.length < 3) continue;
      if (!RegExp(r'[A-Za-z]{2,}').hasMatch(trimmed)) continue;
      confidence['merchant'] = 0.45;
      return trimmed;
    }
    confidence['merchant'] = 0.0;
    return null;
  }

  // ── Date ──────────────────────────────────────────────────────────────────

  DateTime? _extractDate(String fullText, Map<String, double> confidence) {
    for (final pattern in _datePatterns) {
      final match = pattern.firstMatch(fullText);
      if (match == null) continue;
      final parsed = _tryParseDateMatch(match);
      if (parsed != null) {
        confidence['date'] = 0.75;
        return parsed;
      }
    }
    confidence['date'] = 0.0;
    return null;
  }

  DateTime? _tryParseDateMatch(RegExpMatch match) {
    try {
      final groups = match.groups([1, 2, 3]);
      if (groups.any((g) => g == null)) return null;

      // Month-name pattern (3rd regex): group(1) is the month name.
      if (RegExp(r'^[A-Za-z]').hasMatch(groups[0]!)) {
        const months = {
          'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
          'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
        };
        final monthKey = groups[0]!.toLowerCase().substring(0, 3);
        final month = months[monthKey];
        if (month == null) return null;
        final day = int.tryParse(groups[1]!);
        var year = int.tryParse(groups[2]!);
        if (day == null || year == null) return null;
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      }

      final n1 = int.tryParse(groups[0]!);
      final n2 = int.tryParse(groups[1]!);
      var n3 = int.tryParse(groups[2]!);
      if (n1 == null || n2 == null || n3 == null) return null;

      // YYYY-MM-DD pattern (2nd regex): first group is already a 4-digit
      // year (n1 > 31 reliably distinguishes it from a day-first date).
      if (n1 > 31) return DateTime(n1, n2, n3);

      // MM/DD/YYYY vs DD/MM/YYYY (1st regex) is genuinely ambiguous
      // without knowing the receipt's country -- US-format (MM/DD) is
      // the more common default for this app's current user base
      // (IRS-mileage-deduction context), used as the tiebreak when both
      // readings are structurally valid (month <= 12 either way).
      if (n3 < 100) n3 += 2000;
      if (n1 <= 12) return DateTime(n3, n1, n2); // MM/DD/YYYY
      if (n2 <= 12) return DateTime(n3, n2, n1); // DD/MM/YYYY (n1 > 12, must be the day)
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Amounts (total / subtotal / tax) ─────────────────────────────────────

  // Same keyword-anchoring idea across all three fields: find a line
  // that PRINTS the field's own label (a real signal the receipt itself
  // provides, unlike merchant-name guessing above), then pull the
  // clearest currency amount from that same line or, if the receipt's
  // layout puts the label and value on separate lines, the line right
  // after it.
  double? _extractAmount(
    List<({String text, double top})> lines,
    List<String> keywords,
    String fieldName,
    Map<String, double> confidence,
  ) {
    for (var i = 0; i < lines.length; i++) {
      final lower = lines[i].text.toLowerCase();
      final matchedKeyword = keywords.any((k) => lower.contains(k));
      if (!matchedKeyword) continue;

      // "grand total" contains "total" -- when scanning for subtotal
      // specifically, a line that's actually the grand-total line must
      // not be mistaken for it. Cheap guard: subtotal/tax lookups skip
      // any line that ALSO matches a total keyword.
      if (fieldName != 'total' &&
          _totalKeywords.any((k) => lower.contains(k))) {
        continue;
      }

      final sameLine = _amountPattern.firstMatch(lines[i].text);
      if (sameLine != null) {
        confidence[fieldName] = 0.85;
        return _parseAmount(sameLine.group(1)!);
      }

      if (i + 1 < lines.length) {
        final nextLine = _amountPattern.firstMatch(lines[i + 1].text);
        if (nextLine != null) {
          confidence[fieldName] = 0.65;
          return _parseAmount(nextLine.group(1)!);
        }
      }
    }

    // No labeled line found at all. For 'total' only (the field that
    // matters most): fall back to the largest dollar amount anywhere on
    // the receipt -- on a real receipt, the total is almost always the
    // single biggest number printed, even when the label itself doesn't
    // match any keyword this service knows. Explicitly NOT done for
    // subtotal/tax -- there's no equivalent "it's probably the biggest
    // number" signal for those, guessing would just be wrong.
    if (fieldName == 'total') {
      double? largest;
      for (final line in lines) {
        for (final match in _amountPattern.allMatches(line.text)) {
          final value = _parseAmount(match.group(1)!);
          if (value != null && (largest == null || value > largest)) {
            largest = value;
          }
        }
      }
      if (largest != null) {
        confidence[fieldName] = 0.35;
        return largest;
      }
    }

    confidence[fieldName] = 0.0;
    return null;
  }

  double? _parseAmount(String raw) {
    // Normalize "1,234.56" and "1.234,56" both to a plain double --
    // strip thousands separators, keep only the final decimal marker.
    final cleaned = raw.replaceAll(RegExp(r'\$|\s'), '');
    final lastDot = cleaned.lastIndexOf('.');
    final lastComma = cleaned.lastIndexOf(',');
    final decimalIndex = lastDot > lastComma ? lastDot : lastComma;
    if (decimalIndex == -1) return double.tryParse(cleaned);

    final whole = cleaned
        .substring(0, decimalIndex)
        .replaceAll(RegExp(r'[.,]'), '');
    final fraction = cleaned.substring(decimalIndex + 1);
    return double.tryParse('$whole.$fraction');
  }
}
