// Olympus Mont Systems LLC - ControlMiles
// lib/services/odometer_capture_service.dart
// PRODUCTION READY v2.1 — EVIDENCIA Y CIERRE DE SESIÓN SEGURO

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'audit_service.dart';
import '../config/app_config.dart';
import '../i18n/app_texts.dart';

class OdometerCaptureService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Client-side compression before upload (real production-readiness gap,
  // found during the OCR/odometer review: raw camera bytes at
  // ResolutionPreset.high went straight to Storage, with only a post-hoc
  // 50KB-8MB size gate that REJECTS an oversized photo outright instead of
  // shrinking it -- a real cost/reliability concern on a field app over
  // cellular data). Files already reasonably small are left untouched --
  // no point spending CPU compressing something that's already fine, and
  // it avoids any risk of compression making a small/simple image bigger.
  static const int _kCompressionSkipThresholdBytes = 900 * 1024; // ~900KB
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
      // Only trust the compressed result if it actually helped -- never
      // upload something bigger than what we started with.
      if (compressed.isNotEmpty && compressed.length < original.length) {
        return compressed;
      }
    } catch (e) {
      debugPrint('[ControlMiles] Odometer photo compression failed, uploading original: $e');
    }
    return original;
  }

  /// Procesa la evidencia (foto + valor) y, si sessionId no es null,
  /// actualiza la sesión en Supabase.
  ///
  /// sessionId == null es el caso "standalone" (explicit user requirement:
  /// captura de odómetro al ACTIVAR la detección automática, antes de que
  /// exista cualquier sesión/viaje real) -- sube y valida la evidencia
  /// exactamente igual (mismo hash, misma validación de tamaño/formato),
  /// pero no toca sessions ni audit_events (audit_events.session_id es
  /// NOT NULL en DB, así que no hay forma de loguear un evento sin una
  /// sesión real de todas formas). El caller (AutoTripDetectionService)
  /// es responsable de cachear el resultado y aplicarlo a cada sesión
  /// real que se cree después, incluyendo su propio evento de auditoría
  /// -- ver TrackingController.applyCachedShiftStartOdometer.
  Future<Map<String, dynamic>> processEvidence({
    String? sessionId,
    required File file,
    required double odometerValue,
    required bool isStart,
    required AppLanguage language,
    bool ocrSource = false,
    double? ocrConfidence,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception(AppTexts.get('auth_session_expired', language.code));
      }

      final userId = user.id;

      if (sessionId != null) {
        // ──────────────────────────────────────────────────────────────────
        // 1. VALIDACIÓN / CREACIÓN DE SESIÓN (Source of Truth)
        // ──────────────────────────────────────────────────────────────────
        final sessionResponse = await _supabase
            .from('sessions')
            .select('id, is_closed, start_odometer_value')
            .eq('id', sessionId)
            .maybeSingle();

        if (isStart) {
          if (sessionResponse != null && sessionResponse['is_closed'] == true) {
            throw Exception(AppTexts.get('session_already_closed', language.code));
          }

          // Si no existe la sesión al empezar, la creamos inmediatamente
          if (sessionResponse == null) {
            await _supabase.from('sessions').insert({
              'id': sessionId,
              'user_id': userId,
              'start_time': DateTime.now().toIso8601String(),
              'session_status': 'active',
              'is_closed': false,
              'total_miles': 0.0,
            });
            debugPrint('[ControlMiles] Nueva sesión creada: $sessionId');
          }
        } else {
          // Para ODOMETER_END, la sesión DEBE existir
          if (sessionResponse == null) {
            throw Exception(AppTexts.get('session_not_found', language.code));
          }
          if (sessionResponse['is_closed'] == true) {
            throw Exception(AppTexts.get('session_already_finalized', language.code));
          }

          // Validación lógica: El odómetro final no puede ser menor al inicial
          final dynamic rawStart = sessionResponse['start_odometer_value'];
          if (rawStart != null) {
            final double startValue = (rawStart is num) ? rawStart.toDouble() : double.parse(rawStart.toString());
            if (odometerValue < startValue) {
              throw Exception(AppTexts.get('odometer_end_less_than_start', language.code));
            }
          }
        }

        // ──────────────────────────────────────────────────────────────────
        // 2. PROTECCIÓN CONTRA DUPLICADOS
        // ──────────────────────────────────────────────────────────────────
        final existingAudit = await _supabase
            .from('audit_events')
            .select('id')
            .eq('session_id', sessionId)
            .eq('event_type', isStart ? 'ODOMETER_START' : 'ODOMETER_END')
            .maybeSingle();

        if (existingAudit != null) {
          throw Exception(AppTexts.get('duplicate_capture', language.code));
        }
      }

      // ────────────────────────────────────────────────────────────────────
      // 3. PROCESAMIENTO DE ARCHIVO Y SUBIDA A STORAGE
      // ────────────────────────────────────────────────────────────────────
      // BUG FIX: AppConfig.isValidFileSize / isValidExtension ya existían
      // con las reglas definidas (8MB máx, 50KB mín, jpg/jpeg/png) pero nada
      // las llamaba — cualquier archivo, de cualquier tamaño o formato, se
      // subía directo a Storage sin chequeo. Extensión se valida antes de
      // leer los bytes; el tamaño se valida DESPUÉS de comprimir (ver
      // _compressForUpload), ya que ahora eso es lo que realmente se sube.
      if (!AppConfig.isValidExtension(file.path)) {
        throw Exception(
          AppTexts.get('photo_format_not_supported', language.code)
              .replaceFirst('{formats}', AppConfig.allowedImageFormats.join(', ')),
        );
      }

      final rawBytes = await file.readAsBytes();
      final bytes = await _compressForUpload(rawBytes);

      if (!AppConfig.isValidByteSize(bytes.lengthInBytes)) {
        throw Exception(
          AppTexts.get('photo_size_out_of_range', language.code)
              .replaceFirst('{min}', AppConfig.minPhotoSizeKb.toString())
              .replaceFirst('{max}', AppConfig.maxPhotoSizeMb.toString()),
        );
      }

      final fileHash = sha256.convert(bytes).toString();
      final fileName = 'odo_${isStart ? 'start' : 'end'}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = '$userId/$fileName';

      // Subida al bucket definido en AppConfig
      await _supabase.storage
          .from(AppConfig.evidenceBucket)
          .uploadBinary(storagePath, bytes, retryAttempts: 3);

      final publicUrl = _supabase.storage
          .from(AppConfig.evidenceBucket)
          .getPublicUrl(storagePath);

      if (sessionId != null) {
        // ──────────────────────────────────────────────────────────────────
        // 4. LOG DE AUDITORÍA (Inmutable) -- solo con sesión real, ver el
        // comentario del propio método sobre por qué (audit_events.
        // session_id es NOT NULL).
        // ──────────────────────────────────────────────────────────────────
        await AuditService.logAuditEvent(
          sessionId: sessionId,
          eventType: isStart ? 'ODOMETER_START' : 'ODOMETER_END',
          payload: {
            'odometer_value': odometerValue,
            'image_url': publicUrl,
            'file_hash': fileHash,
            'is_start': isStart,
            'ocr_source': ocrSource,
            'ocr_confidence': ocrConfidence,
          },
        );

        // ──────────────────────────────────────────────────────────────────
        // 5. PARCHE DE LA FILA DE SESIÓN (Columnas de acceso rápido)
        // ──────────────────────────────────────────────────────────────────
        final Map<String, dynamic> sessionPatch = isStart
            ? {
                'start_odometer_value': odometerValue,
                'start_odometer_image_url': publicUrl,
              }
            : {
                'end_odometer_value': odometerValue,
                'end_odometer_image_url': publicUrl,
                // Si es el final, podríamos opcionalmente marcar is_closed aquí,
                // o dejar que la lógica de negocio lo haga en otro paso.
              };

        await _supabase
            .from('sessions')
            .update(sessionPatch)
            .eq('id', sessionId);

        debugPrint('[ControlMiles] Registro completado exitosamente para $sessionId');
      } else {
        debugPrint('[ControlMiles] Evidencia standalone subida (sin sesión): $fileHash');
      }

      return {
        'success': true,
        'odometer_value': odometerValue,
        'imageUrl': publicUrl,
        'hash': fileHash,
        'sessionId': sessionId,
        'ocr_source': ocrSource,
      };
    } catch (e) {
      debugPrint('[ControlMiles ERROR] Falló el procesamiento de evidencia: $e');
      rethrow;
    }
  }

  /// Aplica a una sesión REAL recién creada un odómetro ya capturado antes
  /// (la lectura de inicio de turno, ver AutoTripDetectionService) --
  /// explicit user requirement: no se vuelve a pedir foto en cada viaje
  /// auto-detectado del mismo turno. No sube ningún archivo nuevo (la foto
  /// ya está en Storage desde la captura standalone original) -- solo
  /// parchea la fila de la sesión y deja un evento de auditoría HONESTO
  /// sobre el origen del dato: carried_forward_from_shift_start=true, para
  /// que el rastro de auditoría nunca finja que fue una foto fresca de
  /// este viaje específico.
  Future<void> applyCarriedForwardStartOdometer({
    required String sessionId,
    required double odometerValue,
    required String odometerImageUrl,
  }) async {
    await _supabase.from('sessions').update({
      'start_odometer_value': odometerValue,
      'start_odometer_image_url': odometerImageUrl,
    }).eq('id', sessionId);

    await AuditService.logAuditEvent(
      sessionId: sessionId,
      eventType: 'ODOMETER_START',
      payload: {
        'odometer_value': odometerValue,
        'image_url': odometerImageUrl,
        'is_start': true,
        'carried_forward_from_shift_start': true,
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // WEEKLY ODOMETER CHECKPOINTS (explicit user request, 2026-09-03)
  // ══════════════════════════════════════════════════════════════════════
  // Odometer evidence moves from "every session" to a fixed Mon-Sun
  // calendar week per vehicle. The write path is the SECURITY DEFINER RPC
  // submit_vehicle_odometer_checkpoint (migration
  // 20260903120000_vehicle_weekly_odometer_checkpoints.sql) -- it enforces
  // server-side, not just here, that a reading can never be entered below
  // vehicles.odometer already on file (covers OCR failure -> manual entry
  // just as much as a real OCR read), and it's the only thing that keeps
  // vehicles.odometer itself current going forward (that column used to be
  // written once at vehicle creation and frozen forever).

  /// Monday (ISO) of the calendar week containing [date] -- DateTime.weekday
  /// already uses the same Monday=1..Sunday=7 numbering as Postgres'
  /// isodow(), so this must stay in lockstep with the SQL side's own
  /// `p_capture_date - (isodow - 1)` computation.
  DateTime mondayOf(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  /// True when this vehicle's current calendar week has no start reading
  /// yet -- the trip-start flow uses this to decide whether to ask for a
  /// photo at all. False means the week is already covered (whether via a
  /// fresh capture earlier this week or a roll-forward from last week's
  /// missed close) and starting a trip needs zero odometer friction.
  Future<bool> needsCheckpointStartThisWeek(String vehicleId) async {
    final monday = mondayOf(DateTime.now());
    final row = await _supabase
        .from('vehicle_odometer_checkpoints')
        .select('start_odometer_value')
        .eq('vehicle_id', vehicleId)
        .eq('week_start_date', monday.toIso8601String().split('T')[0])
        .maybeSingle();
    return row == null || row['start_odometer_value'] == null;
  }

  /// This vehicle's already-captured reading for the current calendar
  /// week (start value + its photo), or null if the week hasn't started
  /// yet. Used to skip auto-detect's activation-time camera prompt when
  /// this week is already covered -- see AutoTripDetectionService.requestEnable.
  Future<({double value, String imageUrl})?> currentWeekStartReading(
    String vehicleId,
  ) async {
    final monday = mondayOf(DateTime.now());
    final row = await _supabase
        .from('vehicle_odometer_checkpoints')
        .select('start_odometer_value, start_odometer_image_url')
        .eq('vehicle_id', vehicleId)
        .eq('week_start_date', monday.toIso8601String().split('T')[0])
        .maybeSingle();
    final value = row?['start_odometer_value'];
    final imageUrl = row?['start_odometer_image_url'] as String?;
    if (value == null || imageUrl == null) return null;
    return (value: (value as num).toDouble(), imageUrl: imageUrl);
  }

  /// True when this vehicle's current calendar week still has no closing
  /// reading -- used to offer (never block on) the weekly closing photo
  /// after a trip ends.
  Future<bool> needsCheckpointEndThisWeek(String vehicleId) async {
    final monday = mondayOf(DateTime.now());
    final row = await _supabase
        .from('vehicle_odometer_checkpoints')
        .select('start_odometer_value, end_odometer_value')
        .eq('vehicle_id', vehicleId)
        .eq('week_start_date', monday.toIso8601String().split('T')[0])
        .maybeSingle();
    if (row == null) return false; // nothing started this week yet -- start takes priority, not end
    return row['start_odometer_value'] != null && row['end_odometer_value'] == null;
  }

  /// Uploads a fresh photo (same validation/hash/Storage path as
  /// [processEvidence]) and records it as a weekly checkpoint reading via
  /// the RPC -- the RPC decides on the server whether this fills the
  /// week's start, its end, or rolls forward to close last week's still-
  /// open end, and it's the single place vehicles.odometer gets updated.
  Future<Map<String, dynamic>> processWeeklyCheckpoint({
    required String vehicleId,
    required File file,
    required double odometerValue,
    required AppLanguage language,
    bool ocrSource = false,
    double? ocrConfidence,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception(AppTexts.get('auth_session_expired', language.code));
    }

    // BUG FIX (found during OCR/odometer production-readiness review): this
    // duplicated processEvidence's file-size/extension checks but with
    // hardcoded SPANISH exception text instead of going through
    // AppTexts.get(..., language.code) like processEvidence does -- a user
    // on any other language would see Spanish text here regardless of
    // their app language setting. Extension is checked before compression
    // (fail fast); size is checked after, against the compressed bytes --
    // same reasoning as processEvidence.
    if (!AppConfig.isValidExtension(file.path)) {
      throw Exception(
        AppTexts.get('photo_format_not_supported', language.code)
            .replaceFirst('{formats}', AppConfig.allowedImageFormats.join(', ')),
      );
    }

    final rawBytes = await file.readAsBytes();
    final bytes = await _compressForUpload(rawBytes);

    if (!AppConfig.isValidByteSize(bytes.lengthInBytes)) {
      throw Exception(
        AppTexts.get('photo_size_out_of_range', language.code)
            .replaceFirst('{min}', AppConfig.minPhotoSizeKb.toString())
            .replaceFirst('{max}', AppConfig.maxPhotoSizeMb.toString()),
      );
    }
    final fileHash = sha256.convert(bytes).toString();
    final fileName = 'odo_weekly_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = '${user.id}/$fileName';

    await _supabase.storage
        .from(AppConfig.evidenceBucket)
        .uploadBinary(storagePath, bytes, retryAttempts: 3);

    final publicUrl = _supabase.storage
        .from(AppConfig.evidenceBucket)
        .getPublicUrl(storagePath);

    final checkpoint = await _supabase.rpc('submit_vehicle_odometer_checkpoint', params: {
      'p_vehicle_id': vehicleId,
      'p_odometer_value': odometerValue,
      'p_odometer_image_url': publicUrl,
      'p_file_hash': fileHash,
      'p_ocr_source': ocrSource,
      'p_ocr_confidence': ocrConfidence,
    });

    return {
      'success': true,
      'odometer_value': odometerValue,
      'imageUrl': publicUrl,
      'hash': fileHash,
      'checkpoint': checkpoint,
    };
  }

  /// Records a reading that was already captured for real (a photo already
  /// in Storage -- e.g. auto-detect's cached shift-start reading) as this
  /// week's checkpoint, without uploading anything new. Same server-side
  /// floor/roll-forward/vehicles.odometer logic as [processWeeklyCheckpoint].
  Future<void> recordCheckpointFromExistingCapture({
    required String vehicleId,
    required double odometerValue,
    required String odometerImageUrl,
  }) async {
    await _supabase.rpc('submit_vehicle_odometer_checkpoint', params: {
      'p_vehicle_id': vehicleId,
      'p_odometer_value': odometerValue,
      'p_odometer_image_url': odometerImageUrl,
    });
  }

  // SECURITY/BUG FIX (2026-09-04, found during IRS-compliance + security
  // review): the `odometers` Storage bucket is private (verified: RLS
  // policies scope SELECT to the caller's own folder) -- correct, that's
  // exactly what should protect these photos. But every write path in this
  // file (and inspection_service.dart) calls .getPublicUrl() and persists
  // THAT url to sessions/vehicle_odometer_checkpoints/audit_events. A
  // getPublicUrl() link only resolves for a PUBLIC bucket -- for a private
  // one it 400s unconditionally, confirmed live against a real stored
  // object. Every odometer photo ever taken in this app has been
  // permanently unviewable through that stored link; the numeric odometer
  // value itself was never affected (separate column), but the photo
  // evidence the IRS substantiation actually depends on could not be
  // opened by anyone, including the driver.
  //
  // Not reworking the write path (would mean migrating every already-
  // stored URL) -- this resolves a stored link into a real, working, HMAC-
  // signed URL at the moment something needs to display it. Safe to call
  // on old links from before this fix too, since it re-derives the storage
  // path from the URL text itself.
  Future<String?> resolveViewableImageUrl(String storedUrl) async {
    final marker = '/object/public/${AppConfig.evidenceBucket}/';
    final idx = storedUrl.indexOf(marker);
    if (idx == -1) return null;
    final path = storedUrl.substring(idx + marker.length);
    try {
      return await _supabase.storage.from(AppConfig.evidenceBucket).createSignedUrl(path, 3600);
    } catch (e) {
      debugPrint('[ControlMiles] resolveViewableImageUrl failed for $storedUrl: $e');
      return null;
    }
  }

  /// Historial completo de checkpoints (más reciente primero) — usado por
  /// VehicleDetailScreen (pantalla de solo lectura del vehículo, explicit
  /// user requirement) para mostrar la foto inicial y las de cada cierre
  /// semanal, no solo la semana en curso.
  Future<List<Map<String, dynamic>>> listCheckpoints(String vehicleId) async {
    final data = await _supabase
        .from('vehicle_odometer_checkpoints')
        .select()
        .eq('vehicle_id', vehicleId)
        .order('week_start_date', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }
}