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

    return isValidByteSize(file.lengthSync());
  }

  /// Same bounds as [isValidFileSize], but against an in-memory byte count
  /// -- used after client-side compression, where there's no longer a file
  /// on disk matching the uploaded bytes.
  static bool isValidByteSize(int bytes) {

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

    return "$folderPrefix$userId/vehicle_$vehicleId/section_$sectionId/$safeName";
  }

}