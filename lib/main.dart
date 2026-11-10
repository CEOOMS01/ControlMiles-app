// Olympus Mont Systems LLC - ControlMiles
// lib/main.dart - PRODUCTION READY (ASSEMBLY POINT + DARK MODE)

import 'dart:async';
import 'services/play_billing_service.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Observador de ciclo de vida
import 'observers/app_lifecycle_observer.dart';
import 'services/supabase_bootstrap.dart';
import 'services/cgc_monitor_service.dart';

// Rutas, Estado e Internacionalización
import 'routes/app_routes.dart';
import 'logic/app_state.dart';
import 'i18n/app_texts.dart';
import 'theme/app_colors.dart';
import 'theme/cm_colors.dart';
import 'theme/screen_fit.dart';

// Servicios de Hardware y Fondo
import 'tracking/drive_wake.dart';
import 'tracking/background_gps_service.dart';
import 'tracking/auto_trip_detection_service.dart';
import 'services/notification_service.dart';

// Screens & Views
import 'services/startup_router.dart';
import 'widgets/brand_loader.dart';
import 'views/welcome_page.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/odometer_capture_screen.dart';
import 'screens/trips_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'views/my_work_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/vehicle_screen.dart';

// GlobalKey usado por NotificationService para navegar a Reports cuando se
// toca la notificación de resumen semanal, sin depender de un BuildContext
// específico (la notificación puede llegar con cualquier pantalla abierta,
// o con la app cerrada).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Cold-start timing (debug log only): how long each step of opening the app takes.
final Stopwatch startupWatch = Stopwatch();
void startupMark(String label) => debugPrint('[StartupTiming] $label ${startupWatch.elapsedMilliseconds} ms');

Future<void> main() async {
  startupWatch.start();
  // Draws the app scaled to stock-size phones (lib/theme/screen_fit.dart).
  ScreenFitBinding.ensureInitialized();

  // BUG FIX (2026-08-29, real bug the user actually saw): DateFormat
  // patterns with a month name ('MMMM', used by Reports/History's
  // month-divider headers) always rendered in English regardless of the
  // in-app language, even though MaterialApp.locale is correctly bound to
  // appState.currentLanguage below -- confirmed live on-device (Spanish
  // UI, "AUGUST 2026" divider). Flutter's MaterialApp locale binding does
  // NOT automatically initialize package:intl's per-locale date-symbol
  // data for arbitrary DateFormat patterns; that has to be done
  // explicitly. Loads all 11 supported languages' month/day name data
  // once at startup (synchronous, bundled in the intl package, no network
  // or asset I/O) so DateFormat(pattern, appState.currentLanguage.code)
  // works correctly everywhere it's used.
  // (2026-11-05, cold-start speed) loaded in the background while the first frame
  // is drawn; the start-up screen waits for it before opening any real screen.
  // (2026-11-05, second pass) only the saved language blocks the start-up
  // screen; the other ten load after the first screen is up (see
  // _startBackgroundServices), long before anyone can change the language.
  dateFormatsReady = _loadActiveLanguageDates();

  // CGC Core crash monitoring (see cgc_monitor_service.dart): both hooks
  // wired as early as possible, before Supabase/anything else that could
  // itself throw during boot. FlutterError.onError still calls
  // presentError so errors keep showing in debug console/red-screen as
  // before -- this only ADDS forwarding, doesn't replace existing
  // behavior. PlatformDispatcher.onError catches uncaught async errors
  // outside Flutter's own framework zone (the current recommended
  // replacement for wrapping runApp in runZonedGuarded).
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    CgcMonitorService.reportError(
      message: details.exceptionAsString(),
      stack: details.stack?.toString(),
    );
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    CgcMonitorService.reportError(message: error.toString(), stack: stack.toString());
    return true;
  };

  // Inicializar Supabase
  //
  // 2026-08-24 security hardening: la sesión (access + refresh token) ya
  // NO se persiste con el LocalStorage por defecto (shared_preferences,
  // sin cifrar) -- ver services/secure_supabase_storage.dart. Combinado
  // con android:allowBackup=false (AndroidManifest.xml), un `adb backup`
  // sobre un teléfono robado/desbloqueado ya no puede extraer un token de
  // sesión utilizable.
  // (shared with the headless isolate: see services/supabase_bootstrap.dart)
  // Not awaited (2026-11-05, cold-start speed): opening the Android Keystore for
  // the saved session took a good part of the 4 s before the first frame. It now
  // runs while the first frame is drawn and in parallel with the saved settings;
  // AppState waits for it before it says it is initialized, so no screen touches
  // the client early.
  unawaited(SupabaseBootstrap.ensure().then(
    (_) => startupMark('supabase ready'),
    onError: (Object e) => debugPrint('[Main] Supabase init failed: $e'),
  ));

  startupMark('before runApp');
  // Inyectar el Estado Global
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const ControlMilesApp(),
    ),
  );

  // Everything below used to run BEFORE the first frame (7-8 s to open the app).
  // None of it is needed to draw the start-up screen, so it now runs right after.
  // A started-in-the-background engine draws no frame, so a timer starts the
  // services there; with a screen the first frame does, whichever comes first.
  var servicesStarted = false;
  void startServices() {
    if (servicesStarted) return;
    servicesStarted = true;
    unawaited(_startBackgroundServices());
  }
  WidgetsBinding.instance.addPostFrameCallback((_) => startServices());
  Timer(const Duration(seconds: 3), startServices);
}

/// Completes when every language's date names are loaded; the start-up screen
/// waits for it so no screen formats a date before its data exists.
late Future<void> dateFormatsReady;

Future<void> _loadActiveLanguageDates() async {
  var code = AppLanguage.en.code;
  try {
    final saved = (await SharedPreferences.getInstance()).getString('controlmiles_lang');
    if (saved != null) code = AppLanguageExtension.fromCode(saved).code;
  } catch (_) {}
  await initializeDateFormatting(code);
  startupMark('dates ready');
}

Future<void> _startBackgroundServices() async {
  // Let the first real screen (dashboard / login) draw and settle before the
  // heavy native set-up (GPS engine, notification channels, time zones) starts
  // competing with it for the main thread.
  await Future<void>.delayed(const Duration(milliseconds: 1200));
  try {
    await SupabaseBootstrap.ensure();
  } catch (_) {}

  // The other languages' date names (the saved one is already loaded).
  try {
    await Future.wait([
      for (final lang in AppLanguage.values) initializeDateFormatting(lang.code),
    ]);
  } catch (e) {
    debugPrint('[Main] Warning: date formats failed: $e');
  }

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

  // Premium auto-detect: re-arm the motion-listening service on cold
  // start if the user already had it on -- mirrors NotificationService's
  // own re-scheduling of the weekly reminder above.
  try {
    await AutoTripDetectionService.instance.restoreFromPrefs();
  } catch (e) {
    debugPrint('[Main] Warning: AutoTripDetectionService restore failed: $e');
  }

  // The work-place reminders are gone: drop any geofences an older version left behind.
  try {
    await BackgroundGpsService.removeLegacyWorkPlaceGeofences();
  } catch (e) {
    debugPrint('[Main] Warning: removing old work places failed: $e');
  }
  // One engine for screens and trips (2026-11-07): Android may have started this
  // engine with no screen (a drive began, or a trip carries on with the app
  // closed). The open trip is picked up and DriveWakeService keeps the engine alive
  // while a trip or a drive check needs it.
  await TripHost.start();
  startupMark('background services ready');
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
    // Listen from app start so a Google Play purchase finished while the
    // app was closed is still verified and completed.
    // (waits for the Supabase client, which now starts alongside the first frame)
    final appState = context.read<AppState>();
    SupabaseBootstrap.ensure().then<void>((_) {
      if (!mounted) return;
      PlayBillingService.instance.start(onVerified: () => appState.fetchUserProfile());
    }, onError: (Object e) {
      debugPrint('[Main] Play billing not started: $e');
    });
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

      // RTL Support + screen fit (2026-10-18, testers on stock phones saw
      // every screen too big): text scale clamp and compact density, see
      // ScreenFitScope.
      builder: (context, child) {
        return ScreenFitScope(
          child: Directionality(
            textDirection: appState.currentLanguage.textDirection,
            child: child!,
          ),
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
      // Warm palette (2026-10-09, lib/theme/cm_colors.dart): the website's
      // cream / ink / brand blue / amber instead of white and slate. Still
      // one seed (the brand blue) so Material 3 derives consistent roles;
      // only the page/card surfaces and shapes are set on top.
      theme: _cmTheme(Brightness.light),
      darkTheme: _cmTheme(Brightness.dark),

      themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      // ========================================================

      // RUTAS
      home: const _StartupGate(),
      routes: _appRoutes,

      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) {
          final appState = Provider.of<AppState>(context, listen: false);
          return Scaffold(
            appBar: AppBar(title: Text(appState.tr('navigation_error_title'))),
            body: Center(
              child: Text(
                appState.tr('route_not_found_message').replaceFirst('{route}', settings.name ?? '?'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          );
        },
      ),
    );
  }
}

ThemeData _cmTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: dark ? kBrandSeedDark : CmColors.blue,
    brightness: brightness,
  ).copyWith(
    surface: dark ? CmColors.nightCard : Colors.white,
    tertiary: CmColors.amber,
    outlineVariant: dark ? CmColors.ink : CmColors.sand,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: dark ? CmColors.night : CmColors.cream,
    cardColor: dark ? CmColors.nightCard : Colors.white,
    dividerColor: dark ? CmColors.ink : CmColors.sand,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? CmColors.nightCard : CmColors.cream,
      foregroundColor: dark ? Colors.white : CmColors.nightInk,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: dark ? CmColors.nightCard : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: dark ? CmColors.ink : CmColors.sand),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: const StadiumBorder()),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: const StadiumBorder(), elevation: 0),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? CmColors.nightCard : CmColors.cream,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? CmColors.nightCard : CmColors.cream,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? CmColors.creamDeep : CmColors.nightInk,
      contentTextStyle: TextStyle(color: dark ? CmColors.nightInk : CmColors.cream),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? CmColors.nightCard : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: dark ? CmColors.ink : CmColors.sand),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: dark ? CmColors.ink : CmColors.sand),
      ),
    ),
  );
}

/// Invisible first page: waits for the app state, asks [resolveStartRoute]
/// where to go and replaces itself. Shows only the app background meanwhile.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  @override
  void initState() {
    super.initState();
    startupMark('splash shown');
    _go();
  }

  // The wheel and its line are the start-up screen: they stay up for at least
  // a beat, so the turn is seen even when the app is ready at once.
  static const _minShown = Duration(milliseconds: 400);

  Future<void> _go() async {
    final appState = context.read<AppState>();
    final results = await Future.wait<Object?>([
      resolveStartRoute(appState),
      Future<void>.delayed(_minShown),
      dateFormatsReady,
    ]);
    startupMark('route resolved');
    if (!mounted) return;
    // No slide: the start-up screen and the screen that follows share the same logo,
    // so a slide would show two logos moving past each other.
    final route = results.first! as String;
    final builder = _appRoutes[route];
    if (builder == null) {
      Navigator.pushReplacementNamed(context, route);
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        settings: RouteSettings(name: route),
        pageBuilder: (ctx, _, _) => builder(ctx),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BrandSplash(tagline: context.watch<AppState>().tr('splash_tagline'));
}

/// Every named route of the app (also used by the start-up screen, which opens its
/// route without an animation).
final Map<String, WidgetBuilder> _appRoutes = {
  AppRoutes.login: (context) {
    // 'signup' starting mode.
    final args = ModalRoute.of(context)!.settings.arguments as String?;
    return LoginScreen(startInSignupMode: args == 'signup');
  },
  AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
  AppRoutes.resetPassword: (context) {
    final email = ModalRoute.of(context)!.settings.arguments as String? ?? '';
    return ResetPasswordScreen(email: email);
  },
  AppRoutes.welcome: (_) => const WelcomePage(),
  // Gig: the product tour lives inside the dashboard (product_tour.dart).
  AppRoutes.dashboard: (_) => const DashboardScreen(),
  AppRoutes.profile: (_) => const ProfileScreen(),
  AppRoutes.reports: (_) => const ReportsScreen(),
  AppRoutes.history: (_) => const TripsScreen(),
  AppRoutes.settings: (_) => const ProfileScreen(),
  AppRoutes.myWork: (_) => const MyWorkScreen(),
  AppRoutes.accountTracking: (_) => const SettingsScreen(section: AccountSection.tracking),
  AppRoutes.vehiclesReports: (_) => const SettingsScreen(section: AccountSection.vehiclesReports),
  AppRoutes.accountPreferences: (_) => const SettingsScreen(section: AccountSection.preferences),
  AppRoutes.helpLegal: (_) => const SettingsScreen(section: AccountSection.help),
  AppRoutes.subscription: (_) => const SubscriptionScreen(),
  AppRoutes.vehicle: (_) => const VehicleScreen(),
  AppRoutes.odometerCapture: (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    return OdometerCaptureScreen(
      isStart: args?['isStart'] ?? true,
      sessionId: args?['sessionId'] ?? '',
    );
  },
};
