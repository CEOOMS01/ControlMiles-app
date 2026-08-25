// Olympus Mont Systems LLC - ControlMiles
// lib/routes/app_routes.dart - VERSIÓN MEJORADA CON ONBOARDING

import 'package:flutter/material.dart';

/// Clase centralizada para gestionar todas las rutas de la aplicación
/// Evita hardcodear strings de rutas en múltiples lugares
/// Proporciona generación de rutas dinámicas y validación
class AppRoutes {
  // ============================================================
  // RUTAS DE AUTENTICACIÓN Y ONBOARDING
  // ============================================================
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String splash = '/splash';
  static const String welcome = '/welcome'; // Nueva ruta de bienvenida y permisos

  // ============================================================
  // FLEET MODULE -- ControlMiles Gig / ControlMiles Fleet
  // ============================================================
  static const String accountType = '/account-type';
  static const String createOrganization = '/create-organization';
  static const String fleetDashboard = '/fleet-dashboard';
  static const String fleetRoster = '/fleet-roster';
  // Fleet Phase 3: no dedicated fleetDriverHome route -- a fleet_driver
  // lands on `dashboard`, the SAME screen Gig uses. See
  // VehicleService.getActiveOrAssignedVehicle: the only real difference is
  // which vehicle that screen resolves, not a separate screen/flow.
  static const String pendingInvite = '/pending-invite';

  // ============================================================
  // RUTAS PRINCIPALES
  // ============================================================
  static const String home = '/home';
  static const String dashboard = '/dashboard';

  // ============================================================
  // RUTAS DE SEGUIMIENTO
  // ============================================================
  static const String tracking = '/tracking';
  static const String trackingActive = '/tracking-active';
  static const String tripDetails = '/trip-details';
  static const String odometerCapture = '/odometer-capture';

  // ============================================================
  // RUTAS DE HISTORIAL Y REPORTES
  // ============================================================
  static const String history = '/history';
  static const String reports = '/reports';
  static const String tripHistory = '/trip-history';
  static const String auditLogs = '/audit-logs';

  // ============================================================
  // RUTAS DE USUARIO
  // ============================================================
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String preferences = '/preferences';
  // BUG FIX (pedido explícito): gestión de vehículo se separó de Profile —
  // pantalla propia con "Mi Vehículo" + "Mantenimiento".
  static const String vehicle = '/vehicle';

  // ============================================================
  // RUTAS DE SOPORTE
  // ============================================================
  static const String help = '/help';
  static const String about = '/about';
  static const String support = '/support';

  // ============================================================
  // RUTAS ESPECIALES / ERROR
  // ============================================================
  static const String notFound = '/not-found';
  static const String error = '/error';

  // ============================================================
  // RUTAS CON PARÁMETROS OPCIONALES
  // ============================================================
  static const String _tripDetailsParam = 'id';
  static const String _errorParam = 'message';
  static const String _langParam = 'lang';

  // ============================================================
  // LISTA DE TODAS LAS RUTAS (para validación)
  // ============================================================
  static List<String> get _allRoutes => [
        login,
        register,
        forgotPassword,
        resetPassword,
        splash,
        welcome,
        accountType,
        createOrganization,
        fleetDashboard,
        fleetRoster,
        pendingInvite,
        home,
        dashboard,
        tracking,
        trackingActive,
        tripDetails,
        odometerCapture,
        history,
        reports,
        tripHistory,
        auditLogs,
        profile,
        settings,
        preferences,
        vehicle,
        help,
        about,
        support,
        notFound,
        error,
      ];

  // ============================================================
  // MAPEO DE RUTAS POR CATEGORÍA
  // ============================================================
  static const List<String> authRoutes = [
    login,
    register,
    forgotPassword,
    resetPassword,
    splash,
    welcome,
  ];

  static const List<String> mainRoutes = [
    home,
    dashboard,
    fleetDashboard,
  ];

  static const List<String> fleetSetupRoutes = [
    accountType,
    createOrganization,
    pendingInvite,
  ];

  static const List<String> trackingRoutes = [
    tracking,
    trackingActive,
    tripDetails,
    odometerCapture,
  ];

  static const List<String> historyRoutes = [
    history,
    reports,
    tripHistory,
    auditLogs,
  ];

  static const List<String> userRoutes = [
    profile,
    settings,
    preferences,
    vehicle,
  ];

  static const List<String> supportRoutes = [
    help,
    about,
    support,
  ];

  // ============================================================
  // MÉTODOS PARA GENERAR RUTAS CON PARÁMETROS
  // ============================================================

  /// Generar ruta a detalles de viaje con ID
  static String tripDetailsWithId(String tripId) =>
      '$tripDetails?$_tripDetailsParam=$tripId';

  /// Generar ruta a pantalla de error con mensaje
  static String errorWithMessage(String message) =>
      '$error?$_errorParam=${Uri.encodeComponent(message)}';

  /// Generar ruta a pantalla con idioma específico
  static String dashboardWithLang(String lang) =>
      '$dashboard?$_langParam=$lang';

  // ============================================================
  // VALIDACIÓN DE RUTAS
  // ============================================================

  /// Validar si una ruta existe en la aplicación
  static bool isValidRoute(String route) {
    final baseRoute = route.split('?').first;
    return _allRoutes.contains(baseRoute);
  }

  /// Extraer ruta base sin parámetros
  static String getBaseRoute(String route) {
    return route.split('?').first;
  }

  /// Extraer parámetros de una ruta
  static Map<String, String> extractParams(String route) {
    final params = <String, String>{};
    final parts = route.split('?');
    
    if (parts.length > 1) {
      final queryString = parts[1];
      final pairs = queryString.split('&');
      
      for (final pair in pairs) {
        final keyValue = pair.split('=');
        if (keyValue.length == 2) {
          params[keyValue[0]] = Uri.decodeComponent(keyValue[1]);
        }
      }
    }
    
    return params;
  }

  /// Obtener parámetro específico de una ruta
  static String? getParam(String route, String paramName) {
    return extractParams(route)[paramName];
  }

  // ============================================================
  // NOMBRES AMIGABLES DE RUTAS (para UI y debugging)
  // ============================================================

  /// Obtener nombre legible de una ruta (para debugging)
  static String getRouteName(String route) {
    final baseRoute = getBaseRoute(route);
    
    switch (baseRoute) {
      case login: return 'Login';
      case register: return 'Register';
      case forgotPassword: return 'Forgot Password';
      case resetPassword: return 'Reset Password';
      case splash: return 'Splash Screen';
      case welcome: return 'Welcome & Permissions';

      case home: return 'Home';
      case dashboard: return 'Dashboard';
      case accountType: return 'Account Type';
      case createOrganization: return 'Create Organization';
      case fleetDashboard: return 'Fleet Dashboard';
      case fleetRoster: return 'Fleet Roster';
      case pendingInvite: return 'Pending Invite';

      case tracking: return 'Tracking';
      case trackingActive: return 'Tracking Active';
      case tripDetails: return 'Trip Details';
      case odometerCapture: return 'Odometer Capture';

      case history: return 'History';
      case reports: return 'Reports';
      case tripHistory: return 'Trip History';
      case auditLogs: return 'Audit Logs';

      case profile: return 'Profile';
      case settings: return 'Settings';
      case preferences: return 'Preferences';
      case vehicle: return 'Vehicle';

      case help: return 'Help';
      case about: return 'About';
      case support: return 'Support';

      case notFound: return '404 - Not Found';
      case error: return 'Error';

      default:
        return 'Unknown Route: $baseRoute';
    }
  }

  // ============================================================
  // VERIFICACIÓN DE GRUPOS DE RUTAS
  // ============================================================

  static bool isAuthRoute(String route) {
    final baseRoute = getBaseRoute(route);
    return authRoutes.contains(baseRoute);
  }

  static bool isTrackingRoute(String route) {
    final baseRoute = getBaseRoute(route);
    return trackingRoutes.contains(baseRoute);
  }

  static bool isHistoryRoute(String route) {
    final baseRoute = getBaseRoute(route);
    return historyRoutes.contains(baseRoute);
  }

  static bool requiresAuth(String route) {
    final baseRoute = getBaseRoute(route);
    // Rutas que NO requieren autenticación
    return !authRoutes.contains(baseRoute) && baseRoute != splash;
  }

  // ============================================================
  // UTILIDADES DE NAVEGACIÓN
  // ============================================================

  /// Obtener ruta anterior lógica (para navegación atrás)
  static String? getBackRoute(String currentRoute) {
    final baseRoute = getBaseRoute(currentRoute);

    if (trackingRoutes.contains(baseRoute)) return dashboard;
    if (historyRoutes.contains(baseRoute)) return dashboard;
    if (userRoutes.contains(baseRoute)) return dashboard;
    if (supportRoutes.contains(baseRoute)) return dashboard;

    return null; 
  }

  /// Ruta correcta para un usuario ya autenticado, en un solo lugar --
  /// antes esta decisión vivía duplicada (y desincronizada) en
  /// splash_page.dart, login_screen.dart y welcome_page.dart. La
  /// desincronización fue real: splash nunca supo de cuentas Fleet, así que
  /// un fleet_admin que reabría la app (sesión ya activa, sin pasar por
  /// LoginScreen) aterrizaba en el Dashboard de Gig. Orden de prioridad:
  /// onboarding de permisos -> invitaciones pendientes (aplica aunque la
  /// cuenta sea 'gig' -- alguien puede recibir su primera invitación de
  /// flota después de meses usando el modo individual) -> elección
  /// Gig/Fleet -> destino final según el tipo de cuenta.
  static String getInitialRoute({
    required bool isAuthenticated,
    required bool onboardingCompleted,
    bool hasPendingInvites = false,
    bool accountTypeChosen = true,
    bool isFleetAdmin = false,
  }) {
    if (!isAuthenticated) return login;
    if (!onboardingCompleted) return welcome;
    if (hasPendingInvites) return pendingInvite;
    if (!accountTypeChosen) return accountType;
    if (isFleetAdmin) return fleetDashboard;
    // Fleet Phase 3: fleet_driver uses the SAME dashboard route as Gig --
    // DashboardScreen/TrackingController/VehicleService resolve the right
    // vehicle (assigned vs owned) internally instead of this routing
    // decision forking into a second, parallel screen (that screen,
    // FleetDriverHomeScreen, existed briefly in Phase 2 and was deleted
    // once this worked).
    return dashboard;
  }

  static List<String> get breadcrumbExcluded => [
        splash,
        welcome,
        login,
        register,
        notFound,
        error,
      ];

  // ============================================================
  // LOGGING Y DEBUG
  // ============================================================

  static void logNavigation(String fromRoute, String toRoute) {
    final nameFrom = getRouteName(fromRoute);
    final nameTo = getRouteName(toRoute);

    debugPrint(
      ' [Navigation] $nameFrom → $nameTo\n'
      '  From: $fromRoute\n'
      '  To: $toRoute\n'
      '  Valid: ${isValidRoute(toRoute)}',
    );
  }

  static String getRouteTree() {
    final buffer = StringBuffer();
    buffer.writeln('📍 ControlMiles Route Tree');
    _appendCategory(buffer, 'Authentication/Onboarding', authRoutes);
    _appendCategory(buffer, 'Main', mainRoutes);
    _appendCategory(buffer, 'Tracking', trackingRoutes);
    _appendCategory(buffer, 'History', historyRoutes);
    _appendCategory(buffer, 'User', userRoutes);
    _appendCategory(buffer, 'Support', supportRoutes);
    return buffer.toString();
  }

  static void _appendCategory(StringBuffer buffer, String name, List<String> routes) {
    buffer.writeln('├─ $name (${routes.length})');
    for (final route in routes) {
      buffer.writeln('│  ├─ $route');
    }
  }
}