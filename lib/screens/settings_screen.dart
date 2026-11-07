// Olympus Mont Systems LLC - ControlMiles
// lib/screens/settings_screen.dart - FULL I18N PRODUCTION READY

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../onboarding/product_tour.dart';
import '../logic/app_state.dart';
import '../i18n/app_texts.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../services/gig_app_detection_service.dart';
import '../utils/permission_status.dart';
import '../views/permissions_flow_screen.dart';
import '../views/rates_screen.dart';
import '../views/auto_schedule_screen.dart';
import '../services/diag_log.dart';
import '../views/work_type_screen.dart';
import '../tracking/auto_trip_detection_service.dart';
import '../legal/legal_documents.dart';
import 'legal_document_screen.dart';
import 'generate_report_code_screen.dart';
import '../errors/app_error.dart';
import '../widgets/language_selector_tile.dart';
import '../widgets/app_version_text.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

// BUG FIX (toggle de notificaciones inerte): este toggle guardaba
// notifications_enabled en SharedPreferences por su cuenta y nada más en la
// app lo leía. Ahora sigue el mismo patrón que el toggle de sistema métrico
// (unas líneas abajo): lee y escribe a través de AppState, que es la única
// fuente de verdad y la que a su vez conecta con NotificationService.
class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  bool _isDeletingAccount = false;
  bool _isTogglingAutoDetect = false;
  // Usage Access is a "special access" permission granted from system
  // Settings, not a runtime dialog -- WidgetsBindingObserver re-checks
  // it on resume, since that's the only reliable moment to notice the
  // user just came back from granting it there.
  bool _hasUsageAccess = false;

  // BUG FIX (real root cause, 2026-09-19: notifications/reminders "solo
  // aparecen al abrir la app" persisted even after the exact-alarm fix --
  // most Android OEMs freeze a backgrounded app's process under their own
  // battery manager regardless of AlarmManager settings). Both of these
  // are "special access" permissions with no visible in-app confirmation
  // of their own, so this screen is the only place a user who already
  // installed the app can actually check and fix them -- same
  // WidgetsBindingObserver-on-resume pattern _hasUsageAccess already uses,
  // since returning from system Settings is the only reliable moment to
  // notice either one changed.
  bool? _ignoringBatteryOptimizations;

  Future<void> _refreshBackgroundReliabilityStatus() async {
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    final perms = <PermKind, bool>{
      for (final k in _statusKinds) k: await PermissionStatusService.isOk(k),
    };
    if (mounted) {
      setState(() {
        _ignoringBatteryOptimizations = batteryStatus.isGranted;
        _permOk = perms;
      });
    }
  }

  // Location, notifications, activity and camera: the permissions the app
  // cannot do its job without (2026-11-03). Tapping a row reopens the
  // step-by-step permissions screen, which skips what is already allowed.
  static const _statusKinds = [
    PermKind.location,
    PermKind.locationAlways,
    PermKind.notifications,
    PermKind.motion,
    PermKind.camera,
  ];
  Map<PermKind, bool> _permOk = {};

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tourScope.unregister();
    super.dispose();
  }

  // Product tour (2026-10-11, gig app): the two settings people miss -- the
  // tax-preparer code and background reliability.
  final _tourScope = TourScope('settings');
  String get _tour => _tourScope.name;
  final _tPortal = GlobalKey();
  final _tReliability = GlobalKey();
  bool _tourChecked = false;

  void _startTour({bool force = false}) {
    ProductTour.run(context,
        id: TourIds.settings, scope: _tour, keys: [_tPortal, _tReliability], force: force);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (GigAppDetectionService.instance.isSupported) {
        _refreshUsageAccessStatus();
      }
      _refreshBackgroundReliabilityStatus();
    }
  }

  Future<void> _refreshUsageAccessStatus() async {
    final granted = await GigAppDetectionService.instance.hasUsageAccess();
    if (mounted) setState(() => _hasUsageAccess = granted);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tourScope.register();
    if (GigAppDetectionService.instance.isSupported) {
      _refreshUsageAccessStatus();
    }
    _refreshBackgroundReliabilityStatus();
  }

  Future<void> _handleAutoDetectToggle(AppState appState, bool value) async {
    if (_isTogglingAutoDetect) return;
    setState(() => _isTogglingAutoDetect = true);

    try {
      // This switch is the only way to turn automatic detection off; ending a
      // trip never does. Remember the choice so the Dashboard does not turn it
      // back on by itself.
      await appState.setAutoDetectOffByUser(!value);
      if (!mounted) return;
      if (value) {
        // requestEnable owns the whole activation flow now (permission
        // check + shift-start odometer capture + actually arming) --
        // explicit user requirement, see AutoTripDetectionService's own
        // comment on why activation captures odometer instead of asking
        // again on every detected trip.
        await AutoTripDetectionService.requestEnable(context, appState);
      } else {
        await appState.setAutoDetectEnabled(false);
      }
    } finally {
      if (mounted) setState(() => _isTogglingAutoDetect = false);
    }
  }

  void _showPremiumLockedDialog(AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appState.tr('premium_feature_locked_title')),
        content: Text(appState.tr('premium_feature_locked_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(appState.tr('ok')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    // BUG FIX (pedido explícito): este screen completo estaba hardcodeado
    // en modo claro (ver el comentario que quedó documentando esto como
    // pendiente en _buildLanguageOption más abajo) -- ahora sí lee
    // Theme.of(context).brightness, mismo patrón isDark que el resto de la
    // app (dashboard_screen.dart/history_screen.dart/main_drawer.dart).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!_tourChecked) {
      _tourChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startTour();
      });
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF12100C)
          : const Color(0xFFFAF6EE),
      appBar: AppBar(
        actions: [
          TourHelpButton(onPressed: () => _startTour(force: true)),
        ],
        title: Text(
          appState.tr('settings').toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: isDark
            ? const Color(0xFF1C1812)
            : const Color(0xFF2E281F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _buildSectionHeader(appState, 'language', isDark),
          _buildLanguageSection(appState, isDark),

          ...[
            _buildSectionHeader(appState, 'automatic_tracking_section', isDark),
            _buildAutoDetectSection(appState, isDark),

            // Explicit user requirement (2026-09-09): generating a Report
            // Portal access code used to only exist on controlmiles.com --
            // but a gig driver should never need to log into the web at
            // all (web is fleet-admin only going forward). Moved here so
            // the "no login needed for your preparer" pitch is actually
            // true for the driver too, not just the preparer.
            _buildSectionHeader(appState, 'report_portal_section', isDark),
            TourTarget(
              showcaseKey: _tPortal,
              scope: _tour,
              step: 1,
              total: 2,
              titleKey: 'ptour_portal_title',
              bodyKey: 'ptour_portal_body',
              child: _buildReportPortalSection(appState, isDark),
            ),
          ],

          _buildSectionHeader(appState, 'preferences', isDark),
          _buildPreferencesSection(appState, isDark),

          _buildSectionHeader(appState, 'background_reliability_section', isDark),
          TourTarget(
            showcaseKey: _tReliability,
            scope: _tour,
            step: 2,
            total: 2,
            titleKey: 'ptour_reliability_title',
            bodyKey: 'ptour_reliability_body',
            child: _buildBackgroundReliabilitySection(appState, isDark),
          ),

          _buildSectionHeader(appState, 'about_app', isDark),
          _buildAboutSection(appState, isDark),

          _buildSectionHeader(appState, 'danger_zone', isDark),
          _buildDangerZoneSection(appState, isDark),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // DANGER ZONE (pedido explícito: account deletion). Requiere Edge
  // Function delete-account -- ver supabase/functions/delete-account/
  // index.ts y AuthService.deleteAccount(). El cliente nunca borra
  // auth.users directo (no tiene la service role key).
  // ════════════════════════════════════════════════════════════
  Widget _buildDangerZoneSection(AppState appState, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1812) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.red.shade900 : Colors.red.shade100,
          ),
        ),
        // BUG FIX (real, 183 occurrences in CGC Core monitoring): a
        // ListTile paints its background/ink splashes on the nearest
        // Material ancestor -- this Container's own BoxDecoration.color
        // sits between the ListTile and that ancestor, silently hiding
        // the tap ripple. Wrapping in a transparent Material gives the
        // ListTile its own nearer surface to paint on, with zero visual
        // change (the Container's color still shows through).
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            leading: _isDeletingAccount
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red,
                    ),
                  )
                : null,
            title: Text(
              appState.tr('delete_account'),
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: _isDeletingAccount
                ? null
                : () => _showDeleteAccountDialog(appState),
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(AppState appState) {
    final controller = TextEditingController();
    final confirmWord = appState.tr('delete_account_word');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final canConfirm = controller.text.trim() == confirmWord;
          return AlertDialog(
            title: Text(appState.tr('delete_account_confirm_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appState.tr('delete_account_confirm_body')),
                const SizedBox(height: 16),
                Text(
                  '${appState.tr('delete_account_type_to_confirm')} ($confirmWord)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B6250),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(appState.tr('cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                ),
                onPressed: canConfirm
                    ? () {
                        Navigator.pop(ctx);
                        _deleteAccount(appState);
                      }
                    : null,
                child: Text(appState.tr('delete_account')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteAccount(AppState appState) async {
    setState(() => _isDeletingAccount = true);
    // BUG FIX (pedido explícito, logout que no navega): capturado ANTES
    // de los awaits de abajo, para que la navegación a Login nunca
    // dependa de que este `context` puntual siga "mounted" -- ver
    // main_drawer.dart para el detalle completo. El SnackBar sigue
    // necesitando el context real (y su propio chequeo `mounted`), pero
    // la navegación ya no depende de él.
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    try {
      await _authService.deleteAccount();
      // BUG FIX (implícito, reforzado por el bug de ID cruzado
      // descubierto después): el borrado ya pasó en el server (edge
      // function), pero el cliente puede seguir con un JWT local
      // "válido" hasta que expire, y AppState puede seguir cacheando el
      // display_id de esta cuenta ya eliminada. signOutAndClear() limpia
      // ambas cosas y nunca lanza, así que la navegación de abajo
      // siempre se ejecuta.
      await appState.signOutAndClear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appState.tr('delete_account_success'))),
        );
      }
      rootNavigator.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
        // critical:true -- account deletion is destructive/irreversible.
        final appError = AppError.from(e, critical: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appError.display(appState.tr(appError.messageKey))),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ============================================================
  // COMPONENTES UI - SECCIONES Y CABECERAS
  // ============================================================

  Widget _buildSectionHeader(AppState appState, String labelKey, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appState.tr(labelKey).toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isDark ? const Color(0xFFF0E6D2) : const Color(0xFF2E281F),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 3,
            width: 40,
            decoration: BoxDecoration(color: const Color(0xFFBD5B26), borderRadius: BorderRadius.circular(2)),
          ),
        ],
      ),
    );
  }

  // One "Language" row that opens a dropdown (2026-09-30, user request:
  // no loose list of 11 languages on the settings screen).
  Widget _buildLanguageSection(AppState appState, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1C1812) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E281F) : const Color(0xFFE3D9C4);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: LanguageSelectorTile(
          onChanged: (lang) => _showChangeConfirmation(context, appState, lang),
        ),
      ),
    );
  }

  Widget _buildReportPortalSection(AppState appState, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1C1812) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final subTextColor = isDark ? Colors.white54 : const Color(0xFF6B6250);
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          leading: Icon(Icons.qr_code_2_rounded, color: primary),
          title: Text(
            appState.tr('generate_report_code_title'),
            style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
          ),
          subtitle: Text(
            appState.tr('report_portal_section_subtitle'),
            style: TextStyle(fontSize: 12, color: subTextColor),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: subTextColor),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GenerateReportCodeScreen()),
          ),
        ),
      ),
    );
  }

  Widget _buildAutoDetectSection(AppState appState, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1C1812) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final subTextColor = isDark ? Colors.white54 : const Color(0xFF6B6250);
    final locked = !appState.premiumEntitled;
    final primary = Theme.of(context).colorScheme.primary;

    final showUsageAccessRow =
        !locked &&
        appState.autoDetectEnabled &&
        GigAppDetectionService.instance.isSupported;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: Icon(
                Icons.auto_awesome_rounded,
                color: locked ? subTextColor : primary,
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      appState.tr('auto_detect_toggle_title'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (locked) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        appState.tr('premium_badge'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                appState.tr('auto_detect_toggle_subtitle'),
                style: TextStyle(fontSize: 12, color: subTextColor),
              ),
              trailing: locked
                  ? Icon(Icons.lock_outline_rounded, color: subTextColor)
                  : (_isTogglingAutoDetect
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Switch.adaptive(
                            value: appState.autoDetectEnabled,
                            onChanged: (v) =>
                                _handleAutoDetectToggle(appState, v),
                            activeThumbColor: primary,
                          )),
              onTap: locked ? () => _showPremiumLockedDialog(appState) : null,
            ),
          ),
          // Real primary trigger, per explicit user correction ("no por
          // movimiento"): gig-app-foreground detection needs its OWN
          // special-access permission (Settings.ACTION_USAGE_ACCESS_SETTINGS,
          // no runtime dialog exists for it) -- surfaced here, separate
          // from the toggle above, since motion-detection alone still
          // works as a fallback without it.
          if (showUsageAccessRow) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                title: Text(
                  appState.tr('gig_app_detection_title'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  appState.tr(
                    _hasUsageAccess
                        ? 'gig_app_detection_subtitle_granted'
                        : 'gig_app_detection_subtitle_not_granted',
                  ),
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
                trailing: _hasUsageAccess
                    ? null
                    : Icon(Icons.chevron_right_rounded, color: subTextColor),
                onTap: _hasUsageAccess
                    ? null
                    : () => GigAppDetectionService.instance
                          .openUsageAccessSettings(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferencesSection(AppState appState, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // BUG FIX (pedido explícito, 2026-09-18: "hay demasiados botones
          // que viven dentro del botón notificaciones y se ve la pantalla
          // de Settings demasiado cargada"). Antes los 5 toggles de tipo
          // de aviso (_buildNotificationTypeToggles) se pintaban en línea,
          // siempre visibles apenas el interruptor maestro estaba
          // encendido -- 6 filas completas solo para notificaciones. Ahora
          // esta fila es una sola: el switch maestro sigue prendiendo/
          // apagando todo desde acá mismo, y tocar el resto de la fila
          // (icono/título) abre los 5 tipos en un bottom sheet aparte, sin
          // ocupar espacio en la pantalla principal cuando no se están
          // editando.
          _buildToggleSetting(
            title: appState.tr('notifications'),
            value: appState.notificationsEnabled,
            isDark: isDark,
            onChanged: (v) => appState.setNotificationsEnabled(v),
          ),

          if (appState.accountType == 'gig') ...[
            const SizedBox(height: 10),
            _buildLegalLinkRow(
              label: appState.tr('work_type_setting'),
              subtitle: appState.tr(switch (appState.workMode) {
                'gig' => 'work_type_value_gig',
                'general' => 'work_type_value_general',
                _ => 'work_type_value_all',
              }),
              isDark: isDark,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WorkTypeScreen(dismissible: true)),
              ),
            ),
            // General mode: the days and hours the phone may start trips by itself.
            // Premium only: Basic does not track by itself.
            if (appState.premiumEntitled && appState.workMode == 'general') ...[
              const SizedBox(height: 10),
              _buildLegalLinkRow(
                label: appState.tr('auto_schedule_title'),
                subtitle: autoScheduleSummary(appState, context),
                isDark: isDark,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AutoScheduleScreen()),
                ),
              ),
            ],
          ],
          const SizedBox(height: 10),
          _buildToggleSetting(
            title: appState.tr('metric_system'), // Llave validada
            value: appState.useMetricSystem,
            isDark: isDark,
            onChanged: (v) => appState.setUseMetricSystem(v),
          ),
        ],
      ),
    );
  }

  /// BUG FIX (real root cause, 2026-09-19 -- see the field comments above):
  /// the two OS-level switches that actually decide whether reminders and
  /// the pause-status notification survive the app being backgrounded.
  /// Both are "special access" permissions with no other in-app
  /// confirmation, so this is the one place a user can check current
  /// status and fix either one without reinstalling.
  Widget _buildBackgroundReliabilitySection(AppState appState, bool isDark) {
    Future<void> openFlow() async {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const PermissionsFlowScreen(dismissible: true)),
      );
      await _refreshBackgroundReliabilityStatus();
    }

    String label(PermKind kind) => appState.tr(switch (kind) {
          PermKind.location => 'perm_flow_location_title',
          PermKind.locationAlways => 'perm_flow_always_title',
          PermKind.notifications => 'perm_flow_notifications_title',
          PermKind.motion => 'perm_flow_motion_title',
          _ => 'perm_flow_camera_title',
        });

    // Every check as (title, state text, on/off, fix action).
    final items = <(String, String, bool?, VoidCallback)>[
      for (final kind in _statusKinds)
        (
          label(kind),
          _permOk[kind] == null
              ? appState.tr('checking_status')
              : appState.tr(_permOk[kind]! ? 'perm_status_ok' : 'perm_status_missing'),
          _permOk[kind],
          openFlow,
        ),
      (
        appState.tr('battery_optimization_title'),
        _ignoringBatteryOptimizations == null
            ? appState.tr('checking_status')
            : appState.tr(_ignoringBatteryOptimizations!
                ? 'battery_optimization_granted'
                : 'battery_optimization_missing'),
        _ignoringBatteryOptimizations,
        () async {
          await Permission.ignoreBatteryOptimizations.request();
          await _refreshBackgroundReliabilityStatus();
        },
      ),
    ];

    Widget row((String, String, bool?, VoidCallback) it) => _buildPermissionStatusRow(
          appState: appState,
          title: it.$1,
          subtitle: it.$2,
          granted: it.$3,
          isDark: isDark,
          onTap: it.$4,
        );

    final off = items.where((it) => it.$3 == false).toList();
    final on = items.where((it) => it.$3 != false).toList();
    final subTextColor = isDark ? Colors.white54 : const Color(0xFF6B6250);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final it in off) ...[
            row(it),
            const SizedBox(height: 10),
          ],
          if (off.isEmpty && _permOk.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(appState.tr('perm_all_ok'), style: TextStyle(fontSize: 13, color: subTextColor)),
              ),
            ),
          if (on.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1812) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  title: Text(
                    appState.tr('perm_active_group').replaceAll('{n}', '${on.length}'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF2E281F),
                    ),
                  ),
                  children: [
                    for (final it in on) ...[
                      row(it),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionStatusRow({
    required AppState appState,
    required String title,
    required String subtitle,
    required bool? granted,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final statusColor = granted == null
        ? (isDark ? Colors.white38 : const Color(0xFFA39A86))
        : (granted ? const Color(0xFF22C55E) : const Color(0xFFF59E0B));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1812) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF2E281F),
          ),
        ),
        subtitle: Row(
          children: [
            Icon(
              granted == true ? Icons.check_circle : Icons.error_outline,
              size: 14,
              color: statusColor,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: statusColor),
              ),
            ),
          ],
        ),
        trailing: granted == true
            ? null
            : TextButton(
                onPressed: onTap,
                child: Text(appState.tr('fix_it')),
              ),
      ),
    );
  }

  Widget _buildToggleSetting({
    required String title,
    required bool value,
    required bool isDark,
    required Function(bool) onChanged,
    // Ambos opcionales (pedido explícito, 2026-09-18, consolidar el botón
    // de notificaciones): `onTap` deja que la fila entera (icono/título)
    // abra algo aparte -- el sheet de tipos de aviso, en el único call
    // site que los usa -- sin interferir con el Switch, que sigue
    // reaccionando a su propio tap independiente del ListTile.onTap.
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1812) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF2E281F),
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : const Color(0xFF6B6250),
                ),
              )
            : null,
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildAboutSection(AppState appState, bool isDark) {
    final subTextColor = isDark ? Colors.white54 : const Color(0xFF6B6250);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1812) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      appState.tr('app_version'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF2E281F),
                      ),
                    ),
                    AppVersionText(
                      style: TextStyle(
                        color: isDark ? Colors.white54 : const Color(0xFF6B6250),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Divider(
                  height: 32,
                  color: isDark ? const Color(0xFF2E281F) : null,
                ),
                _buildAboutRow(
                  appState.tr('company'),
                  'Olympus Mont Systems LLC',
                  isDark,
                ),
                Divider(
                  height: 32,
                  color: isDark ? const Color(0xFF2E281F) : null,
                ),
                // Explicit user request (legal risk mitigation, 2026-08-27):
                // a short, always-visible non-affiliation disclaimer -- the
                // full legal text lives in Privacy Policy/Terms below, but
                // this is the one line that has to be visible WITHOUT a
                // tap, since it's what separates "referring to a trademark"
                // from "implying a partnership" under nominative fair use.
                Text(
                  appState.tr('trademark_disclaimer_short'),
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // "App tour" (2026-10-11, replaces "Tutorial & what's new"): back
          // to the dashboard that's already open; the tour plays on top of it
          // (ProductTour.replayRequested). Gig app only for now.
          ...[
            _buildLegalLinkRow(
              label: appState.tr('ptour_replay'),
              isDark: isDark,
              onTap: () async {
                Navigator.popUntil(context, (r) => r.settings.name == AppRoutes.dashboard || r.isFirst);
                await ProductTour.replay();
              },
            ),
            const SizedBox(height: 10),
          ],
          // Personal plans and the IRS mileage method.
          ...[
            _buildMileageMethodRow(appState, isDark),
            const SizedBox(height: 10),
            _buildLegalLinkRow(
              label: appState.tr('rates_title'),
              isDark: isDark,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RatesScreen())),
            ),
            const SizedBox(height: 10),
            _buildLegalLinkRow(
              label: appState.tr('diag_send_title'),
              subtitle: appState.tr('diag_send_hint'),
              isDark: isDark,
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final ok = await DiagLog.upload();
                messenger.showSnackBar(SnackBar(content: Text(appState.tr(ok ? 'diag_send_ok' : 'diag_send_failed'))));
              },
            ),
            const SizedBox(height: 10),
            _buildLegalLinkRow(
              label: appState.tr('subscription'),
              isDark: isDark,
              onTap: () => Navigator.pushNamed(context, AppRoutes.subscription),
            ),
            const SizedBox(height: 10),
          ],
          _buildLegalLinkRow(
            label: appState.tr('privacy_policy'),
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LegalDocumentScreen(
                  titleKey: 'privacy_policy',
                  // Explicit user request (2026-08-28): Fleet accounts see
                  // the organization/company-framed version -- the
                  // individual version doesn't cover an admin's own
                  // obligations around driver data, which is the
                  // relationship that's actually live in the Fleet app.
                  body: privacyPolicyEn,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildLegalLinkRow(
            label: appState.tr('terms_conditions'),
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LegalDocumentScreen(
                  titleKey: 'terms_conditions',
                  body: termsOfServiceEn,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Terms of Use (2026-10-01): rules for using the app, same for
          // every account type (unlike the Terms above).
          _buildLegalLinkRow(
            label: appState.tr('terms_of_use'),
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalDocumentScreen(
                  titleKey: 'terms_of_use',
                  body: termsOfUseEn,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Explicit user request (2026-09-09): a place for user
          // suggestions/feedback that isn't the Dashboard -- Settings,
          // same row style as Subscription/Privacy/Terms above.
          // Map credits + open-source notices (2026-10-01): OpenStreetMap's
          // ODbL and the bundled packages' licenses (MapLibre etc.) --
          // Flutter's LicensePage lists every package license itself.
          _buildLegalLinkRow(
            label: appState.tr('licenses_map_data'),
            isDark: isDark,
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'ControlMiles',
              applicationLegalese:
                  '© 2026 Olympus Mont Systems LLC\n\n'
                  'Map data © OpenStreetMap contributors, available under the '
                  'Open Database License (ODbL): openstreetmap.org/copyright. '
                  'Basemap packaging by Protomaps (protomaps.com). Maps rendered '
                  'with MapLibre. Speed limits from the OpenStreetMap Overpass API.',
            ),
          ),
          const SizedBox(height: 10),
          _buildLegalLinkRow(
            label: appState.tr('send_feedback'),
            isDark: isDark,
            onTap: () => _sendFeedback(appState),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFeedback(AppState appState) async {
    // BUG FIX (pedido explícito, 2026-09-09): el asunto del correo estaba
    // hardcodeado en inglés en vez de pasar por tr() como el resto de
    // esta pantalla.
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@controlmiles.com',
      query:
          'subject=${Uri.encodeComponent(appState.tr('send_feedback_email_subject'))}',
    );
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.tr('send_feedback_no_mail_app'))),
      );
    }
  }

  // BUG FIX (pedido explícito, riesgo legal): privacy_policy/terms_conditions
  // ya existían como claves i18n traducidas en los 11 idiomas -- pero
  // ninguna pantalla las usaba nunca (grep confirmó cero call sites fuera
  // de los archivos de i18n). No había Privacy Policy ni Terms of Service
  // accesibles desde la app, pese a que ControlMiles pide permisos
  // sensibles (ubicación en segundo plano, cámara, Usage Access). Estas
  // dos filas cierran ese hueco.
  // IRS Fase 3 (2026-08-28): lets the driver state which deduction method
  // they're using -- doesn't change any calculation (ControlMiles only
  // ever computes standard-mileage figures), just what the report's
  // disclaimer honestly claims. See AppState.setMileageMethod.
  Widget _buildMileageMethodRow(AppState appState, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final subTextColor = isDark ? Colors.white54 : const Color(0xFF6B6250);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1812) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        title: Text(
          appState.tr('mileage_method_label'),
          style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
        ),
        trailing: DropdownButton<String>(
          value: appState.mileageMethod,
          underline: const SizedBox.shrink(),
          style: TextStyle(color: subTextColor, fontSize: 13),
          dropdownColor: isDark ? const Color(0xFF2E281F) : Colors.white,
          items: [
            DropdownMenuItem(
              value: 'standard',
              child: Text(appState.tr('mileage_method_standard')),
            ),
            DropdownMenuItem(
              value: 'actual',
              child: Text(appState.tr('mileage_method_actual')),
            ),
          ],
          onChanged: (v) {
            if (v != null) appState.setMileageMethod(v);
          },
        ),
      ),
    );
  }

  Widget _buildLegalLinkRow({
    required String label,
    String? subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final subTextColor = isDark ? Colors.white54 : const Color(0xFF6B6250);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1812) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        title: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
        ),
        subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(fontSize: 12, color: subTextColor)),
        trailing: Icon(Icons.chevron_right_rounded, color: subTextColor),
        onTap: onTap,
      ),
    );
  }

  Widget _buildAboutRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF2E281F),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white54 : const Color(0xFF6B6250),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  void _showChangeConfirmation(
    BuildContext context,
    AppState appState,
    AppLanguage language,
  ) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${appState.tr('language_changed')}: ${language.label}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
