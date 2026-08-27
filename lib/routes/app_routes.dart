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
  // Primera pantalla que ve un dispositivo nuevo, antes de login/signup --
  // Gig App Driver / Fleet Driver / Fleet Admin. Se muestra una sola vez
  // por dispositivo (AppState.hasSeenRoleChooser, SharedPreferences, NO se
  // limpia en clearAll() -- sobrevive logout, mismo criterio que dark_mode/
  // lang/unit_system). Ver AppRoutes.getInitialRoute().
  static const String roleChooser = '/role-chooser';

  // ============================================================
  // FLEET MODULE -- ControlMiles Gig / ControlMiles Fleet
  // ============================================================
  static const String accountType = '/account-type';
  static const String createOrganization = '/create-organization';
  // Reached only when the caller picked "Fleet Driver" on roleChooser --
  // claims a fleet_driver_slots row (admin-created, CM-D####) via a
  // one-time code. See ClaimDriverSlotScreen / claim_driver_slot RPC.
  static const String claimDriverSlot = '/claim-driver-slot';
  static const String fleetDashboard = '/fleet-dashboard';
  static const String fleetRoster = '/fleet-roster';
  static const String fleetLiveMap = '/fleet-live-map';
  static const String fleetStateMileage = '/fleet-state-mileage';
  // REVERSES the Fleet Phase 3 decision documented right above this line
  // in git history (fleet_driver reusing `dashboard`) -- explicit user
  // requirement for a genuinely restricted driver-ops flow: pre-trip
  // checklist, tracking, mid-trip incident reports, live self-map, and
  // nothing else. See DriverOperationsScreen's own header comment for
  // the full reasoning on why this is a deliberate divergence, not an
  // accidental duplication of the earlier decision's mistake.
  static const String driverOperations = '/driver-operations';
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
  static const String subscription = '/subscription';
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
        roleChooser,
        accountType,
        createOrganization,
        claimDriverSlot,
        driverOperations,
        fleetDashboard,
        fleetRoster,
        fleetLiveMap,
        fleetStateMileage,
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
        subscription,
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
    roleChooser,
  ];

  static const List<String> mainRoutes = [
    home,
    dashboard,
    fleetDashboard,
    driverOperations,
  ];

  static const List<String> fleetSetupRoutes = [
    accountType,
    createOrganization,
    claimDriverSlot,
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
    subscription,
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
      case roleChooser: return 'Role Chooser';

      case home: return 'Home';
      case dashboard: return 'Dashboard';
      case accountType: return 'Account Type';
      case createOrganization: return 'Create Organization';
      case claimDriverSlot: return 'Claim Driver Slot';
      case fleetDashboard: return 'Fleet Dashboard';
      case fleetRoster: return 'Fleet Roster';
      case fleetLiveMap: return 'Fleet Live Map';
      case fleetStateMileage: return 'Fleet State Mileage';
      case driverOperations: return 'Driver Operations';
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
      case subscription: return 'Subscription';
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
    // Default true so the two call sites that are always already
    // authenticated (login_screen.dart, welcome_page.dart) never need to
    // pass this -- the check below only ever matters when !isAuthenticated,
    // which only happens from splash_page.dart's cold-start call.
    bool hasSeenRoleChooser = true,
    // REVERSES the Fleet Phase 3 note this replaced (fleet_driver used to
    // share `dashboard` with Gig -- see DriverOperationsScreen's own
    // header comment for why that changed). Default false, not true,
    // unlike isFleetAdmin -- a caller that forgets to pass this should
    // fail toward the existing Gig dashboard, not toward a driver-only
    // screen that assumes an assigned fleet vehicle exists.
    bool isFleetDriver = false,
  }) {
    if (!isAuthenticated && !hasSeenRoleChooser) return roleChooser;
    if (!isAuthenticated) return login;
    if (!onboardingCompleted) return welcome;
    if (hasPendingInvites) return pendingInvite;
    // BUG FIX (found live, real account): account_type/default_org_id are
    // set atomically server-side by create_organization/claim_driver_slot,
    // but accountTypeChosen used to only ever get set by a SEPARATE
    // client-side call AFTER the RPC returned -- if the app closed/lost
    // network between those two steps, an account could end up with a
    // real fleet_admin/fleet_driver status and a real org, yet
    // accountTypeChosen still false. That silently routed a fleet admin
    // with two real organizations back to the Gig/Fleet choice screen,
    // whose Fleet card has no "you already have one" check and just
    // offers to create another. The RPCs now set accountTypeChosen
    // atomically too (real root-cause fix), but this check is reordered
    // as well, on purpose: isFleetAdmin/isFleetDriver are a STRONGER
    // signal than the separate boolean (they mean account_type itself is
    // already resolved), so they win regardless of whether that flag
    // ever desyncs again for some other reason.
    if (isFleetAdmin) return fleetDashboard;
    if (isFleetDriver) return driverOperations;
    if (!accountTypeChosen) return accountType;
    return dashboard;
  }

  static List<String> get breadcrumbExcluded => [
        splash,
        welcome,
        roleChooser,
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