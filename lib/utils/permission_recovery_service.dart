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
import 'package:shared_preferences/shared_preferences.dart';

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

  // ============================================================
  // AVISO PASIVO LIMITADO
  // ============================================================
  /// BUG FIX (pedido explícito 2026-09-16: "que no se pidan los permisos una
  /// y otra vez, una vez basta").
  ///
  /// DashboardScreen.didChangeAppLifecycleState llamaba a showRecoveryDialog
  /// en CADA `resumed` -- es decir, cada vez que el conductor vuelve a la app
  /// desde donde sea (Uber, el home, una llamada). Con un permiso crítico
  /// revocado, eso significaba el mismo diálogo decenas de veces al día en la
  /// pantalla principal. Insoportable, y encima entrena al usuario a
  /// descartarlo sin leerlo, que es justo lo contrario de lo que se busca.
  ///
  /// Este aviso es PASIVO (nadie lo pidió, salta solo al volver a la app), así
  /// que se limita: una vez por sesión de app y, además, una vez cada 24 h
  /// aunque reinicie. Las comprobaciones que sí son PRECONDICIÓN de una acción
  /// que el usuario acaba de iniciar -- arrancar un viaje, armar auto-detect,
  /// terminar el onboarding -- siguen llamando a showRecoveryDialog directo,
  /// sin límite: ahí no es una molestia, es la respuesta a lo que pidió hacer.
  static const String _lastNagKey = 'controlmiles_permission_nag_last_ms';
  static const Duration _nagCooldown = Duration(hours: 24);
  static bool _nagShownThisSession = false;

  static Future<void> showRecoveryDialogThrottled(BuildContext context) async {
    if (_nagShownThisSession) return;

    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_lastNagKey) ?? 0;
    final elapsed =
        DateTime.now().millisecondsSinceEpoch - lastMs;
    if (lastMs != 0 && elapsed < _nagCooldown.inMilliseconds) {
      // Ya avisado hace poco: marcar la sesión igualmente para no volver a
      // consultar prefs en cada resume de este mismo arranque.
      _nagShownThisSession = true;
      return;
    }

    _nagShownThisSession = true;
    await prefs.setInt(_lastNagKey, DateTime.now().millisecondsSinceEpoch);

    if (!context.mounted) return;
    await showRecoveryDialog(context);
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