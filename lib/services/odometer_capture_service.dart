// Olympus Mont Systems LLC - ControlMiles
// lib/services/odometer_capture_service.dart
// PRODUCTION READY v2.1 — EVIDENCIA Y CIERRE DE SESIÓN SEGURO

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'audit_service.dart';
import '../config/app_config.dart';
import '../i18n/app_texts.dart';

class OdometerCaptureService {
  final SupabaseClient _supabase = Supabase.instance.client;

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
            throw Exception("La sesión ya está cerrada y no admite más cambios.");
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
            throw Exception("Error crítico: No se encontró la sesión activa para cerrar.");
          }
          if (sessionResponse['is_closed'] == true) {
            throw Exception("Esta sesión ya fue finalizada anteriormente.");
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
          throw Exception("Ya existe una captura registrada para este evento.");
        }
      }

      // ────────────────────────────────────────────────────────────────────
      // 3. PROCESAMIENTO DE ARCHIVO Y SUBIDA A STORAGE
      // ────────────────────────────────────────────────────────────────────
      // BUG FIX: AppConfig.isValidFileSize / isValidExtension ya existían
      // con las reglas definidas (8MB máx, 50KB mín, jpg/jpeg/png) pero nada
      // las llamaba — cualquier archivo, de cualquier tamaño o formato, se
      // subía directo a Storage sin chequeo. Se valida antes de leer los
      // bytes completos a memoria.
      if (!AppConfig.isValidFileSize(file)) {
        throw Exception(
          'La foto pesa fuera de rango permitido (entre ${AppConfig.minPhotoSizeKb}KB y ${AppConfig.maxPhotoSizeMb}MB). Intenta tomarla de nuevo.',
        );
      }

      if (!AppConfig.isValidExtension(file.path)) {
        throw Exception(
          'Formato de imagen no soportado. Formatos permitidos: ${AppConfig.allowedImageFormats.join(', ')}.',
        );
      }

      final bytes = await file.readAsBytes();
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
}