// Olympus Mont Systems LLC - ControlMiles
// lib/services/fuel_purchase_service.dart
//
// Fuel purchase capture, piece 2 of the real IFTA build. Upload +
// submit_fuel_purchase RPC call -- same hash/compress/validate shape as
// OdometerCaptureService.processWeeklyCheckpoint, own private
// 'fuel_receipts' bucket (own-folder-only RLS, see migration
// 20260917210000_fuel_purchases.sql) instead of reusing 'odometers',
// since these are a genuinely different evidence type or the bucket name
// itself becomes misleading.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import '../config/app_config.dart';
import '../i18n/app_texts.dart';
import '../models/fuel_purchase.dart';

class FuelPurchaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _bucket = 'fuel_receipts';

  // Same thresholds as OdometerCaptureService's own _compressForUpload --
  // a receipt photo is the same kind of field-camera-capture-over-
  // cellular concern, no reason for a different policy here.
  static const int _kCompressionSkipThresholdBytes = 900 * 1024;
  static const int _kCompressionMinWidth = 1600;
  static const int _kCompressionMinHeight = 1600;
  static const int _kCompressionQuality = 80;

  Future<Uint8List> _compressForUpload(Uint8List original) async {
    if (original.lengthInBytes <= _kCompressionSkipThresholdBytes) {
      return original;
    }
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        original,
        minWidth: _kCompressionMinWidth,
        minHeight: _kCompressionMinHeight,
        quality: _kCompressionQuality,
      );
      if (compressed.isNotEmpty && compressed.length < original.length) {
        return compressed;
      }
    } catch (e) {
      debugPrint('[ControlMiles] Fuel receipt photo compression failed, uploading original: $e');
    }
    return original;
  }

  Future<FuelPurchase> submitFuelPurchase({
    required String vehicleId,
    required File receiptFile,
    required DateTime purchaseDate,
    required double gallons,
    String? stateCode,
    double? pricePerGallonUsd,
    double? totalCostUsd,
    String fuelType = 'diesel',
    required AppLanguage language,
    bool ocrSource = false,
    double? ocrConfidence,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception(AppTexts.get('auth_session_expired', language.code));
    }

    if (!AppConfig.isValidExtension(receiptFile.path)) {
      throw Exception(
        AppTexts.get('photo_format_not_supported', language.code)
            .replaceFirst('{formats}', AppConfig.allowedImageFormats.join(', ')),
      );
    }

    final rawBytes = await receiptFile.readAsBytes();
    final bytes = await _compressForUpload(rawBytes);

    if (!AppConfig.isValidByteSize(bytes.lengthInBytes)) {
      throw Exception(
        AppTexts.get('photo_size_out_of_range', language.code)
            .replaceFirst('{min}', AppConfig.minPhotoSizeKb.toString())
            .replaceFirst('{max}', AppConfig.maxPhotoSizeMb.toString()),
      );
    }

    final fileHash = sha256.convert(bytes).toString();
    final fileName = 'fuel_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = '${user.id}/$fileName';

    await _supabase.storage.from(_bucket).uploadBinary(storagePath, bytes, retryAttempts: 3);
    final publicUrl = _supabase.storage.from(_bucket).getPublicUrl(storagePath);

    final purchaseDateStr =
        '${purchaseDate.year.toString().padLeft(4, '0')}-${purchaseDate.month.toString().padLeft(2, '0')}-${purchaseDate.day.toString().padLeft(2, '0')}';

    final data = await _supabase.rpc('submit_fuel_purchase', params: {
      'p_vehicle_id': vehicleId,
      'p_purchase_date': purchaseDateStr,
      'p_gallons': gallons,
      'p_state_code': stateCode,
      'p_price_per_gallon_usd': pricePerGallonUsd,
      'p_total_cost_usd': totalCostUsd,
      'p_fuel_type': fuelType,
      'p_receipt_image_url': publicUrl,
      'p_file_hash': fileHash,
      'p_ocr_source': ocrSource,
      'p_ocr_confidence': ocrConfidence,
    });

    return FuelPurchase.fromMap(Map<String, dynamic>.from(data as Map));
  }

  /// Same private-bucket signed-URL resolution as
  /// OdometerCaptureService.resolveViewableImageUrl -- getPublicUrl()
  /// links never resolve against a private bucket (verified live there
  /// already); this bucket is private too, so the same fix applies here
  /// from day one rather than being a future gap.
  Future<String?> resolveViewableImageUrl(String storedUrl) async {
    final marker = '/object/public/$_bucket/';
    final idx = storedUrl.indexOf(marker);
    if (idx == -1) return null;
    final path = storedUrl.substring(idx + marker.length);
    try {
      return await _supabase.storage.from(_bucket).createSignedUrl(path, 3600);
    } catch (e) {
      debugPrint('[ControlMiles] resolveViewableImageUrl (fuel) failed for $storedUrl: $e');
      return null;
    }
  }

  Future<List<FuelPurchase>> listForVehicle(String vehicleId, {int limit = 50}) async {
    final data = await _supabase
        .from('fuel_purchases')
        .select()
        .eq('vehicle_id', vehicleId)
        .order('purchase_date', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data).map(FuelPurchase.fromMap).toList();
  }

  Future<void> deleteFuelPurchase(String id) async {
    await _supabase.from('fuel_purchases').delete().eq('id', id);
  }
}
