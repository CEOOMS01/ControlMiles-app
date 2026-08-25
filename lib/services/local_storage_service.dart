// Olympus Mont Systems LLC - ControlMiles
// lib/services/local_storage_service.dart
// VERSIÓN MEJORADA - OFFLINE BUFFER + SYNC INTELIGENTE

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class LocalStorageService {
  static const String _prefix = 'controlmiles_';

  // Claves principales
  static const String _keyActiveSessionId = '${_prefix}active_session_id';
  static const String _keyActiveSectionId = '${_prefix}active_section_id';
  static const String _keyGigApp = '${_prefix}current_gig_app';
  static const String _keyTotalSessionMiles = '${_prefix}total_session_miles';
  static const String _keyTotalSectionMiles = '${_prefix}total_section_miles';
  static const String _keyIsPaused = '${_prefix}is_paused';
  static const String _keyLastSyncTime = '${_prefix}last_sync_time';
  static const String _keyOfflineBuffer = '${_prefix}offline_buffer'; // Para datos más complejos

  // BUG FIX (recuperación 100% offline): antes el checkpoint no guardaba
  // user_id ni la hora de inicio de la sección, así que reconstruir
  // `activeSection` tras perder el estado en memoria (app matada por el SO)
  // siempre necesitaba un query a la DB — si además no había señal en ese
  // momento, la recuperación fallaba y ese tramo del viaje se perdía. Con
  // estos dos campos, TrackingController puede reconstruir la sección
  // completa sin red.
  static const String _keyUserId = '${_prefix}user_id';
  static const String _keySectionStartTime = '${_prefix}section_start_time';

  // BUG FIX (pausa no sobrevive reinicio): la duración "confirmada" de la
  // sección (tiempo activo ya bancado en la última pausa/resume) también
  // se guarda localmente. Sin esto, si la app muere y se recupera 100%
  // offline (ver _hydrateSectionFromLocalCheckpoint en TrackingController),
  // esa base se perdía y el conteo de tiempo volvía a arrancar de cero,
  // borrando todo lo manejado antes del reinicio.
  static const String _keySectionDurationSeconds = '${_prefix}section_duration_seconds';

  // =============================================
  // GUARDAR CHECKPOINT (se llama frecuentemente)
  // =============================================
  static Future<void> saveTripCheckpoint({
    required String sessionId,
    required String sectionId,
    required String userId,
    required String gigApp,
    required DateTime sectionStartTime,
    required int sectionDurationSeconds,
    required double totalSessionMiles,
    required double totalSectionMiles,
    required bool isPaused,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await Future.wait([
      prefs.setString(_keyActiveSessionId, sessionId),
      prefs.setString(_keyActiveSectionId, sectionId),
      prefs.setString(_keyUserId, userId),
      prefs.setString(_keyGigApp, gigApp),
      prefs.setString(_keySectionStartTime, sectionStartTime.toIso8601String()),
      prefs.setInt(_keySectionDurationSeconds, sectionDurationSeconds),
      prefs.setDouble(_keyTotalSessionMiles, totalSessionMiles),
      prefs.setDouble(_keyTotalSectionMiles, totalSectionMiles),
      prefs.setBool(_keyIsPaused, isPaused),
      prefs.setString(_keyLastSyncTime, DateTime.now().toIso8601String()),
    ]);

    _logDebug('Checkpoint saved locally');
  }

  // =============================================
  // GUARDAR BUFFER OFFLINE (para cuando no hay señal)
  // =============================================
  static Future<void> saveOfflineBuffer({
    required String sectionId,
    required double milesToAdd,
    required DateTime timestamp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final buffer = await getOfflineBuffer();

    buffer.add({
      'sectionId': sectionId,
      'miles': milesToAdd,
      'timestamp': timestamp.toIso8601String(),
    });

    await prefs.setString(_keyOfflineBuffer, jsonEncode(buffer));
    _logDebug('Offline buffer updated: +${milesToAdd.toStringAsFixed(3)} miles');
  }

  // Obtener buffer de millas offline
  static Future<List<Map<String, dynamic>>> getOfflineBuffer() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyOfflineBuffer);

    if (jsonString == null || jsonString.isEmpty) return [];

    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  // Limpiar buffer después de sincronizar
  static Future<void> clearOfflineBuffer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOfflineBuffer);
  }

  // =============================================
  // RECUPERAR ESTADO (para initializeOrRecover)
  // =============================================
  static Future<Map<String, dynamic>?> getRecoverableState() async {
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey(_keyActiveSessionId)) return null;

    try {
      return {
        'sessionId': prefs.getString(_keyActiveSessionId),
        'sectionId': prefs.getString(_keyActiveSectionId),
        'userId': prefs.getString(_keyUserId),
        'gigApp': prefs.getString(_keyGigApp),
        'sectionStartTime': prefs.getString(_keySectionStartTime),
        'sectionDurationSeconds': prefs.getInt(_keySectionDurationSeconds) ?? 0,
        'totalSessionMiles': prefs.getDouble(_keyTotalSessionMiles) ?? 0.0,
        'totalSectionMiles': prefs.getDouble(_keyTotalSectionMiles) ?? 0.0,
        'isPaused': prefs.getBool(_keyIsPaused) ?? false,
        'lastSyncTime': prefs.getString(_keyLastSyncTime),
        'hasOfflineData': (await getOfflineBuffer()).isNotEmpty,
      };
    } catch (e) {
      _logError('Failed to recover local state');
      return null;
    }
  }

  // =============================================
  // LIMPIEZA (al finalizar viaje correctamente)
  // =============================================
  static Future<void> clearAllCheckpoint() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = [
      _keyActiveSessionId,
      _keyActiveSectionId,
      _keyUserId,
      _keyGigApp,
      _keySectionStartTime,
      _keySectionDurationSeconds,
      _keyTotalSessionMiles,
      _keyTotalSectionMiles,
      _keyIsPaused,
      _keyLastSyncTime,
      _keyOfflineBuffer,
    ];

    for (var key in keys) {
      await prefs.remove(key);
    }
    _logDebug('All local checkpoints cleared');
  }

  // =============================================
  // UTILIDADES
  // =============================================
  static Future<bool> hasActiveTrip() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyActiveSessionId);
  }

  static Future<void> updateTotalMiles(double newTotalSectionMiles, double newTotalSessionMiles) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setDouble(_keyTotalSectionMiles, newTotalSectionMiles),
      prefs.setDouble(_keyTotalSessionMiles, newTotalSessionMiles),
    ]);
  }

  static void _logDebug(String message) {
    debugPrint('[LocalStorageService] $message');
  }

  static void _logError(String message) {
    debugPrint('[LocalStorageService ERROR] $message');
  }
}