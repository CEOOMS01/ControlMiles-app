// Olympus Mont Systems LLC - ControlMiles
// lib/views/splash_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _performFlightCheck();
  }

  Future<void> _performFlightCheck() async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);

      // 1) Esperar inicialización global con TIEMPO LÍMITE (Evita loops infinitos)
      const int maxRetries = 10; // 5 segundos máximo (10 * 500ms)
      int currentRetry = 0;

      while (!appState.isInitialized && currentRetry < maxRetries) {
        await Future.delayed(const Duration(milliseconds: 500));
        currentRetry++;
      }

      if (!mounted) return;

      // Si no inicializó a tiempo, NO te quedes anclado: manda a Login
      if (!appState.isInitialized) {
        debugPrint(
            "[Splash Warning]: AppState no inicializó a tiempo. Redirect -> Login");
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      // 2) Splash SOLO resuelve ruta inicial (SIN permisos aquí)
      // BUG FIX (verificado en DB, Fleet Phase 2): antes esta llamada no
      // pasaba nada de Fleet -- un fleet_admin/fleet_driver que reabría la
      // app con una sesión ya activa (sin pasar por LoginScreen, que sí
      // tenía su propio chequeo) siempre aterrizaba en el Dashboard de Gig.
      // getInitialRoute() ahora es la única fuente de verdad para esta
      // decisión (login_screen.dart y welcome_page.dart también la usan).
      final targetRoute = AppRoutes.getInitialRoute(
        isAuthenticated: appState.isAuthenticated,
        onboardingCompleted: appState.permissionsCompleted,
        hasPendingInvites: appState.hasPendingInvites,
        accountTypeChosen: appState.accountTypeChosen,
        isFleetAdmin: appState.isFleetAdmin,
        hasSeenRoleChooser: appState.hasSeenRoleChooser,
      );

      Navigator.pushReplacementNamed(context, targetRoute);

    } catch (e) {
      // Si algo falla (ej. config, supabase, etc.), evita atrapar al usuario.
      debugPrint("[Splash Error Fatal]: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("System initializing. Redirecting..."),
          backgroundColor: Colors.red,
        ),
      );

      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    // BUG FIX (pedido explícito, brand color unificado): esta pantalla
    // fuerza fondo oscuro (Slate 900) sin importar el tema del sistema --
    // Theme.of(context) tomaría el primary de modo claro si el
    // dispositivo está en claro, arriesgando contraste contra este fondo
    // fijo. Se deriva el scheme oscuro explícito del mismo seed de marca
    // (ver lib/theme/app_colors.dart), no del ThemeData activo.
    // BUG FIX (pedido explícito, azul muy saturado en oscuro): esta
    // pantalla es funcionalmente "modo oscuro" siempre (fondo fijo Slate
    // 900), así que usa kBrandSeedDark -- el mismo seed atenuado que
    // main.dart ahora usa para darkTheme -- en vez de kBrandSeed.
    final darkPrimary = ColorScheme.fromSeed(
      seedColor: kBrandSeedDark,
      brightness: Brightness.dark,
    ).primary;

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Slate 900
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo de Olympus Mont Systems
            Image.asset(
              'assets/images/logo_olympus.png',
              width: 140,
              height: 140,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.hexagon_outlined,
                size: 100,
                color: darkPrimary,
              ),
            ),
            const SizedBox(height: 30),

            // Título Principal
            const Text(
              "OLYMPUS MONT SYSTEMS",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 12),

            // Subtítulo
            Text(
              "SECURE / AUDIT / PROGRAMS",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.blue.shade200,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 50),

            // Indicador de Carga
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(darkPrimary),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}