// ================================================================
// Olympus Mont Systems LLC - ControlMiles
// lib/utils/permission_recovery_service.dart - VERSIÓN FINAL CORREGIDA
// ================================================================

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';   // ← Importante
// BUG FIX (recursión infinita real, encontrada al limpiar warnings de
// flutter analyze en este archivo): PermissionRecoveryService declara su
// propio método estático openAppSettings() -- una llamada SIN calificar a
// openAppSettings() dentro de esta misma clase resuelve al miembro estático
// de la clase, no a la función top-level del paquete (la resolución de
// nombres de Dart prioriza los miembros de la clase envolvente sobre el
// scope de la librería). Eso hacía que openAppSettings() se llamara a sí
// mismo indefinidamente -- un StackOverflowError garantizado la primera vez
// que alguien tocara "Abrir Ajustes" o que welcome_page.dart llamara a este
// método. Import con alias para poder referenciar la función real del
// paquete sin ambigüedad.
import 'package:permission_handler/permission_handler.dart' as ph;
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

  /// Abre la configuración de la app
  static Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }

  /// Muestra diálogo de recuperación de permisos con i18n
  static Future<void> showRecoveryDialog(BuildContext context) async {
    if (!context.mounted) return;

    final appState = context.read<AppState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(appState.tr('permission_required')),
        content: Text(
          appState.tr('location_always_needed'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(appState.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: Text(appState.tr('open_settings')),
          ),
        ],
      ),
    );
  }
}