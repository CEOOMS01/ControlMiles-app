// Olympus Mont Systems LLC - ControlMiles
// lib/observers/app_lifecycle_observer.dart

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../tracking/tracking_controller.dart';
import '../services/local_storage_service.dart';
import '../services/audit_service.dart';

class AppLifecycleObserver with WidgetsBindingObserver {
  static final AppLifecycleObserver _instance = AppLifecycleObserver._internal();
  factory AppLifecycleObserver() => _instance;
  AppLifecycleObserver._internal();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    debugPrint('[AppLifecycle] State changed to: $state');

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        await _handleAppGoingToBackground();
        break;

      case AppLifecycleState.resumed:
        await _handleAppResumed();
        break;

      case AppLifecycleState.detached:
        await _handleAppDetached();
        break;
    }
  }

  Future<void> _handleAppGoingToBackground() async {
    if (TrackingController.isRunning) {
      final section = TrackingController.activeSection;
      debugPrint('[AppLifecycle] App going to background - saving checkpoint');
      await LocalStorageService.saveTripCheckpoint(
        sessionId: TrackingController.activeSessionId ?? '',
        sectionId: section?.id ?? '',
        userId: section?.userId ?? '',
        gigApp: TrackingController.currentGigApp ?? 'custom',
        sectionStartTime: section?.startTime ?? DateTime.now(),
        sectionDurationSeconds: TrackingController.elapsedSectionDuration.inSeconds,
        totalSessionMiles: TrackingController.activeDistance,
        totalSectionMiles: TrackingController.activeDistance,
        isPaused: TrackingController.isPaused,
      );
    }
  }

  Future<void> _handleAppResumed() async {
    try {
      // Recuperar estado del tracking
      await TrackingController.initializeOrRecover();

      // BUG FIX: antes esto detectaba el buffer offline, lo logueaba, y lo
      // borraba sin sincronizar nada — las millas ya llegan a la DB por el
      // smart-sync normal en cuanto vuelve la conexión, pero el registro
      // detallado (cuánto se manejó y cuándo, mientras estaba offline) se
      // perdía para siempre. Ahora se verifica conectividad real primero, y
      // si no hay conexión el buffer se conserva para el siguiente intento
      // en vez de borrarse a ciegas.
      final buffer = await LocalStorageService.getOfflineBuffer();
      if (buffer.isNotEmpty) {
        final results = await Connectivity().checkConnectivity();
        final hasConnection = !results.contains(ConnectivityResult.none);

        if (hasConnection) {
          await _syncOfflineBuffer(buffer);
        } else {
          debugPrint(
              '[AppLifecycle] ${buffer.length} offline entries pending - still no connection, keeping buffer');
        }
      }

      debugPrint('[AppLifecycle] App resumed - state restored');
    } catch (e) {
      debugPrint('[AppLifecycle ERROR] Error on resume: $e');
    }
  }

  /// Registra en el audit log el resumen de millas acumuladas mientras el
  /// dispositivo estaba sin conexión, agrupado por sección (un evento por
  /// sección en vez de uno por cada tick GPS offline, para no saturar el
  /// audit log). Solo se limpia el buffer local si el registro se guardó
  /// con éxito — si falla, se conserva para reintentar después.
  Future<void> _syncOfflineBuffer(List<Map<String, dynamic>> buffer) async {
    debugPrint('[AppLifecycle] Syncing ${buffer.length} offline entries...');
    try {
      final bySection = <String, List<Map<String, dynamic>>>{};
      for (final entry in buffer) {
        final sectionId = entry['sectionId'] as String? ?? '';
        if (sectionId.isEmpty) continue;
        bySection.putIfAbsent(sectionId, () => []).add(entry);
      }

      final sessionId = TrackingController.activeSessionId;
      if (sessionId != null) {
        for (final item in bySection.entries) {
          final sectionId = item.key;
          final entries = item.value;
          final totalMiles = entries.fold<double>(
            0.0,
            (sum, e) => sum + ((e['miles'] as num?)?.toDouble() ?? 0.0),
          );

          await AuditService.logEvent(
            sessionId: sessionId,
            sectionId: sectionId,
            eventType: 'OFFLINE_BUFFER_SYNCED',
            payload: {
              'entries': entries.length,
              'miles': totalMiles,
              'first_timestamp': entries.first['timestamp'],
              'last_timestamp': entries.last['timestamp'],
            },
          );
        }
      }

      await LocalStorageService.clearOfflineBuffer();
      debugPrint('[AppLifecycle] Offline buffer synced and cleared');
    } catch (e) {
      // Si falla el sync, NO se borra el buffer — se pierde el registro si
      // se limpia sin haber quedado guardado en ningún lado.
      debugPrint('[AppLifecycle ERROR] Offline buffer sync failed, keeping buffer: $e');
    }
  }

  Future<void> _handleAppDetached() async {
    if (TrackingController.isRunning || TrackingController.activeSessionId != null) {
      final section = TrackingController.activeSection;
      debugPrint('[AppLifecycle] App being detached - saving final checkpoint');
      await LocalStorageService.saveTripCheckpoint(
        sessionId: TrackingController.activeSessionId ?? '',
        sectionId: section?.id ?? '',
        userId: section?.userId ?? '',
        gigApp: TrackingController.currentGigApp ?? 'custom',
        sectionStartTime: section?.startTime ?? DateTime.now(),
        sectionDurationSeconds: TrackingController.elapsedSectionDuration.inSeconds,
        totalSessionMiles: TrackingController.activeDistance,
        totalSectionMiles: TrackingController.activeDistance,
        isPaused: true,
      );
    }
  }
}
