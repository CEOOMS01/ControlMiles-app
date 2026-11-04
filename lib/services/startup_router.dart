// Olympus Mont Systems LLC - ControlMiles
// lib/services/startup_router.dart
//
// Where the app opens (2026-11-04): replaces the old splash page. There is no
// screen of its own any more -- the system launch screen is the only splash --
// this only decides the first route once the app state is ready.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/app_state.dart';
import '../routes/app_routes.dart';
import 'local_storage_service.dart';
import 'login_prefs.dart';

/// Route to open on a cold start. Never throws: any failure falls back to login.
Future<String> resolveStartRoute(AppState appState) async {
  try {
    // 1) Esperar inicialización global con TIEMPO LÍMITE (Evita loops infinitos)
    const int maxRetries = 10; // 5 segundos máximo (10 * 500ms)
    int currentRetry = 0;

    while (!appState.isInitialized && currentRetry < maxRetries) {
      await Future.delayed(const Duration(milliseconds: 500));
      currentRetry++;
    }

    // Si no inicializó a tiempo, NO te quedes anclado: manda a Login
    if (!appState.isInitialized) {
      debugPrint(
          "[Startup]: AppState no inicializó a tiempo. Redirect -> Login");
      return AppRoutes.login;
    }

    // 1b) "Stay signed in" off (2026-09-29): this only runs on a
    // cold start of the app, i.e. the app was closed -- so the session
    // ends here. Never while a trip is being recorded: that trip (and
    // the background tracking behind it) must not be cut off.
    if (appState.isAuthenticated &&
        !await LoginPrefs.staySignedIn() &&
        !await LocalStorageService.hasActiveTrip()) {
      await appState.signOutAndClear();
      return AppRoutes.login;
    }

    // 2) Solo resuelve la ruta inicial (SIN permisos aquí)
    // BUG FIX (verificado en DB, Fleet Phase 2): antes esta llamada no
    // pasaba nada de Fleet -- un fleet_admin/fleet_driver que reabría la
    // app con una sesión ya activa (sin pasar por LoginScreen, que sí
    // tenía su propio chequeo) siempre aterrizaba en el Dashboard de Gig.
    // getInitialRoute() ahora es la única fuente de verdad para esta
    // decisión (login_screen.dart y welcome_page.dart también la usan).
    // This device's flag can be missing (cleared on sign-out) for an account
    // that already finished the permission steps: ask the server before
    // sending a returning user back through them.
    var onboardingDone = appState.permissionsCompleted;
    final authUser = Supabase.instance.client.auth.currentUser;
    if (!onboardingDone && appState.isAuthenticated && authUser != null) {
      try {
        final row = await Supabase.instance.client
            .from('user_onboarding')
            .select('welcome_seen')
            .eq('user_id', authUser.id)
            .maybeSingle();
        if (row?['welcome_seen'] == true) {
          onboardingDone = true;
          await appState.completePermissionsSetup();
        }
      } catch (e) {
        debugPrint('[Startup] welcome_seen check failed: $e');
      }
    }

    final targetRoute = AppRoutes.getInitialRoute(
      isAuthenticated: appState.isAuthenticated,
      onboardingCompleted: onboardingDone,
    );

    return targetRoute;
  } catch (e) {
    // Never trap the user (config, supabase...): go to login.
    debugPrint('[Startup] failed: $e');
    return AppRoutes.login;
  }
}
