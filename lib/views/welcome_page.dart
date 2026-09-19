// ================================================================
// Olympus Mont Systems LLC - ControlMiles
// lib/views/welcome_page.dart - VERSIÓN FINAL OPTIMIZADA
// ================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';   // ← IMPORT OBLIGATORIO

import 'package:shared_preferences/shared_preferences.dart';

import '../logic/app_state.dart';
import '../routes/app_routes.dart';
import '../services/gig_app_detection_service.dart';
import '../utils/permission_recovery_service.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _isProcessing = false;
  bool _acceptedTerms = false;

  Future<bool> _requestPermissionsFlow() async {
    final hasPermissions = await PermissionRecoveryService.hasCriticalPermissions();
    if (hasPermissions) return true;

    return await _requestAllPermissions();
  }

  // REAL BUG FIX (2026-08-28, "página de permisos no está 100% funcional"):
  // background location (locationAlways) is NOT a simple "tap Allow"
  // permission on modern Android -- since Android 11, the standard runtime
  // dialog often can't grant "Allow all the time" directly at all; the OS
  // routes the user to Settings instead, and .request() can legitimately
  // come back as plain `denied` (not `isPermanentlyDenied`) even on the
  // very first attempt, with no dialog ever shown for it. The old code
  // only ever opened Settings when isPermanentlyDenied was true -- on any
  // device/OS version where that flag never gets set this way, the whole
  // onboarding flow silently dead-ended: same generic orange snackbar
  // every retry, no explanation, no path forward. Now ALWAYS offers the
  // real recovery dialog (PermissionRecoveryService.showRecoveryDialog --
  // explains exactly what's needed, has a working "Open Settings" button)
  // whenever locationAlways specifically isn't granted, regardless of the
  // permanently-denied flag.
  Future<bool> _requestAllPermissions() async {
    var status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      if (status.isPermanentlyDenied) await PermissionRecoveryService.openAppSettings();
      return false;
    }

    status = await Permission.locationAlways.request();
    if (!status.isGranted) {
      if (mounted) await PermissionRecoveryService.showRecoveryDialog(context);
      return false;
    }

    await Permission.camera.request();
    await Permission.activityRecognition.request();
    await Permission.notification.request();

    // BUG FIX (real root cause, 2026-09-19): "los avisos solo aparecen al
    // abrir la app" persisted even with locationAlways + exact-alarm
    // scheduling correctly granted, because most Android OEMs freeze a
    // backgrounded app's process (and its pending alarms/notifications)
    // under their own battery manager, independent of anything this app
    // requests from AlarmManager. This shows the real system "allow
    // ControlMiles to ignore battery optimizations?" dialog -- best-effort,
    // like camera/activityRecognition/notification above: never blocks
    // onboarding, and a user who denies it can still grant it later from
    // Settings (see SettingsScreen's background-reliability row).
    await Permission.ignoreBatteryOptimizations.request();

    await _requestUsageAccessOnce();

    return true;
  }

  /// Usage Access (PACKAGE_USAGE_STATS) -- lo que permite detectar qué gig
  /// app está abierta. Pedido explícito (2026-09-16): que se pida AQUÍ, en
  /// los permisos posteriores al lanzamiento, y una sola vez.
  ///
  /// Tres diferencias con los de arriba, y todas importan:
  ///
  /// 1. No es un permiso de runtime. No existe diálogo del sistema: la única
  ///    forma de concederlo es abrir Ajustes > Acceso de uso. Por eso aquí se
  ///    explica primero y se lleva al usuario allí, en vez de llamar a
  ///    .request() como con los demás.
  ///
  /// 2. NO bloquea el onboarding. Solo hace falta para la detección
  ///    automática (Premium); exigirlo para terminar el alta dejaría tirado a
  ///    todo el que no la use. Se pregunta, se respeta la respuesta, y el
  ///    flujo continúa igual.
  ///
  /// 3. Se pregunta UNA VEZ. La bandera se escribe pase lo que pase --
  ///    concedido, rechazado o cerrado -- porque el usuario ya tomó su
  ///    decisión y repetirla en cada arranque es justo lo que se pidió
  ///    evitar. Si más tarde activa auto-detect sin haberlo concedido, ahí sí
  ///    se le vuelve a plantear: no es insistir, es que la función que acaba
  ///    de encender no puede funcionar sin esto (ver
  ///    AutoTripDetectionService.requestEnable). Y siempre queda disponible
  ///    en Ajustes > Detección de app activa.
  static const String _usageAccessAskedKey = 'controlmiles_usage_access_asked';

  Future<void> _requestUsageAccessOnce() async {
    if (!GigAppDetectionService.instance.isSupported) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_usageAccessAskedKey) ?? false) return;
    if (await GigAppDetectionService.instance.hasUsageAccess()) {
      await prefs.setBool(_usageAccessAskedKey, true);
      return;
    }

    if (!mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final appState = context.read<AppState>();
        return AlertDialog(
          title: Text(appState.tr('usage_access')),
          content: Text(appState.tr('usage_access_onboarding_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(appState.tr('later')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(appState.tr('open_settings')),
            ),
          ],
        );
      },
    );

    // Marcada ANTES de abrir Ajustes a propósito: el usuario ya respondió.
    // Si vuelve sin concederlo, no se le pregunta otra vez aquí.
    await prefs.setBool(_usageAccessAskedKey, true);

    if (open == true) {
      await GigAppDetectionService.instance.openUsageAccessSettings();
    }
  }

  Future<void> _completeOnboarding(AppState appState) async {
    if (_isProcessing || !_acceptedTerms) return;

    setState(() => _isProcessing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      final permissionsOk = await _requestPermissionsFlow();
      if (!mounted) return;

      if (!permissionsOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appState.tr('permissions_required')),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await _markWelcomeSeen(user.id);
      appState.completePermissionsSetup();
      await appState.fetchAccountTypeChosen();
      await appState.fetchPendingInvites();

      if (!mounted) return;

      // Role-chooser fast path: a user who already picked a role on
      // RoleChooserScreen (before signup) shouldn't be asked the same
      // Gig/Fleet question again via AccountTypeScreen. A real pending
      // invite still wins over this -- someone might have been invited to
      // a DIFFERENT fleet while finishing permissions setup, and that
      // takes priority regardless of what they picked upfront.
      final pendingRole = appState.pendingIntendedRole;
      if (pendingRole != null && !appState.accountTypeChosen && !appState.hasPendingInvites) {
        if (pendingRole == 'fleet_admin') {
          await appState.clearPendingIntendedRole();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, AppRoutes.createOrganization);
          return;
        }
        if (pendingRole == 'fleet_driver') {
          await appState.clearPendingIntendedRole();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, AppRoutes.claimDriverSlot);
          return;
        }
        // 'gig' -- no extra screen needed, just mark the choice made and
        // fall through to the normal routing below (resolves to dashboard).
        await appState.completeAccountTypeChoice();
        await appState.clearPendingIntendedRole();
        if (!mounted) return;
      }

      // Fleet Phase 2: same centralized routing decision as
      // login_screen.dart/splash_page.dart -- a first-time user might
      // already have a pending fleet invite waiting (sent while they were
      // still finishing permissions setup).
      final targetRoute = AppRoutes.getInitialRoute(
        isAuthenticated: true,
        onboardingCompleted: true,
        hasPendingInvites: appState.hasPendingInvites,
        accountTypeChosen: appState.accountTypeChosen,
        isFleetAdmin: appState.isFleetAdmin,
        isFleetDriver: appState.isFleetDriver,
      );
      Navigator.pushReplacementNamed(context, targetRoute);
    } catch (e) {
      debugPrint('[WelcomePage Error]: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appState.tr('something_went_wrong')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _markWelcomeSeen(String userId) async {
  try {
    await Supabase.instance.client
        .from('user_onboarding')
        .upsert({
          'user_id': userId,
          'welcome_seen': true,
          'welcome_seen_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id');
  } catch (e) {
    debugPrint('[WelcomePage] Warning: Could not mark welcome as seen: $e');
    // No bloqueamos el flujo si falla, solo lo logueamos
  }
}

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              Column(
                children: [
                  Image.asset(
                    'assets/images/logo_olympus.png',
                    height: 70,
                    errorBuilder: (_, _, _) => Icon(Icons.shield_rounded, size: 60, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    appState.tr('olympus_mont_systems'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appState.tr('secure_audit_programs'),
                    style: TextStyle(fontSize: 12, color: subTextColor),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appState.tr('permissions_required'),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      appState.tr('permissions_description'),
                      style: TextStyle(color: subTextColor),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  children: [
                    _PermissionTile(icon: Icons.location_on, title: appState.tr('location_access'), desc: appState.tr('location_desc')),
                    _PermissionTile(icon: Icons.camera_alt, title: appState.tr('camera'), desc: appState.tr('camera_desc')),
                    _PermissionTile(icon: Icons.directions_walk, title: appState.tr('motion_detection'), desc: appState.tr('motion_desc')),
                    _PermissionTile(icon: Icons.notifications, title: appState.tr('notifications'), desc: appState.tr('notifications_desc')),
                    // Android-only: Usage Access no es un permiso de runtime,
                    // se concede desde Ajustes del sistema. Se lista aquí para
                    // que el cliente sepa qué se le va a pedir antes de que le
                    // aparezca la pantalla de Ajustes.
                    if (GigAppDetectionService.instance.isSupported)
                      _PermissionTile(icon: Icons.apps_rounded, title: appState.tr('usage_access'), desc: appState.tr('usage_access_desc')),
                  ],
                ),
              ),

              Row(
                children: [
                  Checkbox(
                    value: _acceptedTerms,
                    onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  Expanded(
                    child: Text(
                      appState.tr('accept_terms'),
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isProcessing || !_acceptedTerms) ? null : () => _completeOnboarding(appState),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          appState.tr('continue').toUpperCase(),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _PermissionTile({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}