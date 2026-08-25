// ================================================================
// Olympus Mont Systems LLC - ControlMiles
// lib/utils/permission_recovery_service.dart - VERSIÓN FINAL CORREGIDA
// ================================================================

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';   // ← Importante
import 'package:provider/provider.dart';

import '../logic/app_state.dart';

class PermissionRecoveryService {
  /// Verifica si los permisos críticos están concedidos
  static Future<bool> hasCriticalPermissions() async {
    final locationWhenInUse = await Permission.locationWhenInUse.status;
    final locationAlways = await Permission.locationAlways.status;
    final camera = await Permission.camera.status;
    final activity = await Permission.activityRecognition.status;

    return locationAlways.isGranted &&
           camera.isGranted &&
           activity.isGranted &&
           locationWhenInUse.isGranted;
  }

  /// Abre la configuración de la app (CORRECTO)
  static Future<void> openAppSettings() async {
    await openAppSettings();   // ← Función global de permission_handler
  }

  /// Muestra diálogo de recuperación de permisos con i18n
  static Future<void> showRecoveryDialog(BuildContext context) async {
    if (!context.mounted) return;

    final appState = context.read<AppState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(appState.tr('permission_required') ?? 'Permisos requeridos'),
        content: Text(
          appState.tr('location_always_needed') ??
              'ControlMiles necesita "Ubicación siempre" para rastrear millas en segundo plano.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(appState.tr('cancel') ?? 'Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: Text(appState.tr('open_settings') ?? 'Abrir Ajustes'),
          ),
        ],
      ),
    );
  }
}