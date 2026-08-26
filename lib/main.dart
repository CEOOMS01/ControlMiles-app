// Olympus Mont Systems LLC - ControlMiles
// lib/main.dart - PRODUCTION READY (ASSEMBLY POINT + DARK MODE)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Observador de ciclo de vida
import 'observers/app_lifecycle_observer.dart';
import 'services/secure_supabase_storage.dart';

// Rutas, Estado e Internacionalización
import 'routes/app_routes.dart';
import 'logic/app_state.dart';
import 'i18n/app_texts.dart';
import 'theme/app_colors.dart';

// Servicios de Hardware y Fondo
import 'tracking/background_gps_service.dart';
import 'services/notification_service.dart';

// Screens & Views
import 'views/splash_page.dart';
import 'views/welcome_page.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/odometer_capture_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/vehicle_screen.dart';
import 'screens/role_chooser_screen.dart';
import 'screens/account_type_screen.dart';
import 'screens/create_organization_screen.dart';
import 'screens/claim_driver_slot_screen.dart';
import 'screens/fleet_dashboard_screen.dart';
import 'screens/fleet_roster_screen.dart';
import 'screens/fleet_live_map_screen.dart';
import 'screens/fleet_state_mileage_screen.dart';
import 'screens/pending_invite_screen.dart';

// GlobalKey usado por NotificationService para navegar a Reports cuando se
// toca la notificación de resumen semanal, sin depender de un BuildContext
// específico (la notificación puede llegar con cualquier pantalla abierta,
// o con la app cerrada).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase
  //
  // 2026-08-24 security hardening: la sesión (access + refresh token) ya
  // NO se persiste con el LocalStorage por defecto (shared_preferences,
  // sin cifrar) -- ver services/secure_supabase_storage.dart. Combinado
  // con android:allowBackup=false (AndroidManifest.xml), un `adb backup`
  // sobre un teléfono robado/desbloqueado ya no puede extraer un token de
  // sesión utilizable.
  const supabaseUrl = 'https://zuujwmcftycmdaxesdya.supabase.co';
  final persistSessionKey =
      'sb-${Uri.parse(supabaseUrl).host.split(".").first}-auth-token';

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp1dWp3bWNmdHljbWRheGVzZHlhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2MTA1MjUsImV4cCI6MjA5MTE4NjUyNX0.hdkU3aFdjJzoKPFjLoBSlSA0aq2zrpF2O6wwmz1dfVA',
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureSupabaseLocalStorage(
        persistSessionKey: persistSessionKey,
      ),
      pkceAsyncStorage: SecureGotrueAsyncStorage(),
    ),
  );

  // Inicializar Background GPS Service
  try {
    await BackgroundGpsService.initialize();
    debugPrint('[Main] BackgroundGpsService initialized successfully');
  } catch (e) {
    debugPrint('[Main] Warning: BackgroundGpsService failed to initialize: $e');
  }

  // Inicializar Notificaciones Locales (recordatorio de viaje olvidado +
  // resumen semanal — ver notification_service.dart). No debe bloquear el
  // arranque de la app si el dispositivo rechaza el permiso o algo falla.
  try {
    await NotificationService.instance.init(navigatorKey: navigatorKey);
    debugPrint('[Main] NotificationService initialized successfully');
  } catch (e) {
    debugPrint('[Main] Warning: NotificationService failed to initialize: $e');
  }

  // Inyectar el Estado Global
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const ControlMilesApp(),
    ),
  );
}

class ControlMilesApp extends StatefulWidget {
  const ControlMilesApp({super.key});

  @override
  State<ControlMilesApp> createState() => _ControlMilesAppState();
}

class _ControlMilesAppState extends State<ControlMilesApp> {
  final AppLifecycleObserver _lifecycleObserver = AppLifecycleObserver();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'ControlMiles',
      debugShowCheckedModeBanner: false,

      // LOCALIZACIÓN
      locale: Locale(appState.currentLanguage.code),
      supportedLocales: AppLanguage.values.map((l) => Locale(l.code)).toList(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // RTL Support
      builder: (context, child) {
        return Directionality(
          textDirection: appState.currentLanguage.textDirection,
          child: child!,
        );
      },

      // ==================== THEME + DARK MODE ====================
      // BUG FIX (pedido explícito): antes el seed era 0xFF2563EB (un azul
      // que ni siquiera coincidía con el logo real -- verificado pixel a
      // pixel). Ahora usa kBrandSeed (#3E93CA, el color exacto del logo,
      // ver lib/theme/app_colors.dart), como ÚNICA fuente del ColorScheme.
      // Deliberadamente NO se pisan primary/secondary/surface a mano acá
      // encima del fromSeed(): mezclar seed + overrides manuales rompe la
      // relación entre onPrimary/primaryContainer/etc. que Material 3
      // deriva del seed, y termina en un look que no combina consigo
      // mismo. Se deja que M3 derive el set completo de roles.
      theme: ThemeData(
        colorSchemeSeed: kBrandSeed,
        useMaterial3: true,
        fontFamily: 'Inter',
        brightness: Brightness.light,
      ),

      darkTheme: ThemeData(
        // BUG FIX (pedido explícito): kBrandSeed resaltaba demasiado en
        // modo oscuro -- kBrandSeedDark es el mismo azul desaturado (ver
        // lib/theme/app_colors.dart), pasado igual a fromSeed() para que
        // M3 derive todos los roles de forma consistente. Modo claro
        // sigue con kBrandSeed sin cambios.
        colorSchemeSeed: kBrandSeedDark,
        useMaterial3: true,
        fontFamily: 'Inter',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020617),
        cardColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
        ),
      ),

      themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      // ========================================================

      // RUTAS
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashPage(),
        AppRoutes.roleChooser: (_) => const RoleChooserScreen(),
        AppRoutes.login: (context) {
          final args = ModalRoute.of(context)!.settings.arguments as bool?;
          return LoginScreen(startInSignupMode: args ?? false);
        },
        AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
        AppRoutes.resetPassword: (context) {
          final email = ModalRoute.of(context)!.settings.arguments as String? ?? '';
          return ResetPasswordScreen(email: email);
        },
        AppRoutes.welcome: (_) => const WelcomePage(),
        AppRoutes.accountType: (_) => const AccountTypeScreen(),
        AppRoutes.createOrganization: (_) => const CreateOrganizationScreen(),
        AppRoutes.claimDriverSlot: (_) => const ClaimDriverSlotScreen(),
        AppRoutes.fleetDashboard: (_) => const FleetDashboardScreen(),
        AppRoutes.fleetRoster: (_) => const FleetRosterScreen(),
        AppRoutes.fleetLiveMap: (_) => const FleetLiveMapScreen(),
        AppRoutes.fleetStateMileage: (_) => const FleetStateMileageScreen(),
        AppRoutes.pendingInvite: (_) => const PendingInviteScreen(),
        AppRoutes.dashboard: (_) => const DashboardScreen(),
        AppRoutes.profile: (_) => const ProfileScreen(),
        AppRoutes.reports: (_) => const ReportsScreen(),
        AppRoutes.history: (_) => const HistoryScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
        AppRoutes.vehicle: (_) => const VehicleScreen(),
        AppRoutes.odometerCapture: (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return OdometerCaptureScreen(
            isStart: args?['isStart'] ?? true,
            sessionId: args?['sessionId'] ?? '',
          );
        },
      },

      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("Error de Navegación")),
          body: Center(
            child: Text(
              "Route ${settings.name} not found.\nContact Olympus Mont Systems.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }
}