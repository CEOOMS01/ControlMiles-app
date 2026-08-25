// Olympus Mont Systems LLC - ControlMiles
// lib/config/app_config.dart
// PRODUCTION CONFIGURATION CORE

import 'dart:io';

class AppConfig {

  // ============================================================
  // TRIAL SYSTEM
  // ============================================================

  /// Trial duration for new users
  static const int trialDurationDays = 14;

  /// Check if trial expired
  static bool isTrialExpired(DateTime startDate) {
    final now = DateTime.now();
    return now.isAfter(startDate.add(const Duration(days: trialDurationDays)));
  }

  // ============================================================
  // SUBSCRIPTION PLANS
  // ============================================================

  static const String planBasic = "BASIC";
  static const String planPremium = "PREMIUM";
  static const String planPro = "PRO";

  static String normalizePlan(String plan) {
    return plan.toUpperCase().trim();
  }

  // ============================================================
  // PLAN LIMITS
  // ============================================================

  /// Daily tracking sessions allowed
  static int getDailySessionLimit(String plan) {

    final p = normalizePlan(plan);

    switch (p) {

      case planBasic:
        return 3;

      case planPremium:
        return 999;

      case planPro:
        return 999;

      default:
        return 0;
    }
  }

  // ============================================================
  // FEATURE FLAGS BY PLAN
  // ============================================================

  /// Allows switching between gig apps during tracking
  static bool canUseMultiApp(String plan) {

    final p = normalizePlan(plan);

    return p == planPremium || p == planPro;
  }

  /// Allows registering vehicles
  static bool canUseVehicleRegistry(String plan) {

    final p = normalizePlan(plan);

    return p == planPremium || p == planPro;
  }

  /// Automatic driving detection (future feature)
  static bool canUseAutoDetection(String plan) {

    final p = normalizePlan(plan);

    return p == planPro;
  }

  /// AI / OCR scanning (enabled for now)
  static bool canUseAiScanning(String plan) {

    return true;
  }

  // ============================================================
  // IMAGE VALIDATION
  // ============================================================

  /// Maximum allowed photo size
  static const int maxPhotoSizeMb = 8;

  /// Minimum allowed photo size
  static const int minPhotoSizeKb = 50;

  static const List<String> allowedImageFormats = [
    'jpg',
    'jpeg',
    'png'
  ];

  static const List<String> allowedMimeTypes = [
    'image/jpeg',
    'image/png'
  ];

  /// Validate file size
  static bool isValidFileSize(File file) {

    final bytes = file.lengthSync();

    final maxBytes = maxPhotoSizeMb * 1024 * 1024;
    final minBytes = minPhotoSizeKb * 1024;

    return bytes <= maxBytes && bytes >= minBytes;
  }

  /// Validate extension
  static bool isValidExtension(String fileName) {

    if (!fileName.contains('.')) return false;

    final ext = fileName.split('.').last.toLowerCase();

    return allowedImageFormats.contains(ext);
  }

  // ============================================================
  // SUPABASE STORAGE
  // ============================================================

  static const String evidenceBucket = "odometers";

  static const String folderPrefix = "user_";

  /// Sanitize filenames for storage safety
  static String sanitizeFileName(String fileName) {

    return fileName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .toLowerCase();
  }

  /// Generate secure path for evidence storage
  static String generateEvidencePath({
    required String userId,
    required String vehicleId,
    required String sectionId,
    required String fileName,
  }) {

    final safeName = sanitizeFileName(fileName);

    return "${folderPrefix}${userId}/vehicle_$vehicleId/section_$sectionId/$safeName";
  }

}