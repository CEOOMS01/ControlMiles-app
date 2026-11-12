// Olympus Mont Systems LLC - ControlMiles
// lib/screens/app_menu_screen.dart
//
// The app's menu (2026-11-09): opened from the bottom left button of the dashboard,
// a full page with what used to be the side menu.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/app_texts.dart';
import '../logic/app_state.dart';
import '../routes/app_routes.dart';
import '../widgets/app_version_text.dart';
import '../onboarding/product_tour.dart';

class AppMenuScreen extends StatefulWidget {
  const AppMenuScreen({super.key});

  @override
  State<AppMenuScreen> createState() => _AppMenuScreenState();
}

class _AppMenuScreenState extends State<AppMenuScreen> {
  // First time here: one tip per category, so people know where things are.
  final _scope = TourScope('menu');
  final _tourKeys = <String, GlobalKey>{};
  List<String> _tourOrder = const [];
  bool _tourChecked = false;

  static const _tourBodies = {
    'account_title': 'ptour_menu_account_body',
    'my_work_title': 'ptour_menu_work_body',
    'account_tracking': 'ptour_menu_tracking_body',
    'account_vehicles_reports': 'ptour_menu_vehicles_body',
    'preferences': 'ptour_menu_prefs_body',
    'account_help': 'ptour_menu_help_body',
  };

  @override
  void initState() {
    super.initState();
    _scope.register();
  }

  @override
  void dispose() {
    _scope.unregister();
    super.dispose();
  }

  void _maybeStartTour(AppState appState) {
    if (_tourChecked) return;
    _tourChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ProductTour.run(
        context,
        id: appState.premiumEntitled ? TourIds.menu : TourIds.menuBasic,
        scope: _scope.name,
        keys: [for (final k in _tourOrder) _tourKeys[k]!],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
   final appState = context.watch<AppState>();
   // BUG FIX (pedido explícito): este drawer nunca leyó Theme.of(context)
   // en ningún lado -- fondo/texto quedaban fijos en colores de modo claro
   // sin importar appState.isDarkMode. Mismo patrón isDark ya usado en
   // dashboard_screen.dart/history_screen.dart/etc.
   final isDark = Theme.of(context).brightness == Brightness.dark;
   final bgColor = isDark ? const Color(0xFF1C1812) : const Color(0xFFFAF6EE); // cream (2026-10-09)
   final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
   final labelColor = isDark ? Colors.white38 : const Color(0xFFA39A86);
   final dividerColor = isDark ? const Color(0xFF2E281F) : const Color(0xFFE3D9C4);
   final chevronColor = isDark ? Colors.white24 : const Color(0xFFCFC3A8);
   _tourOrder = [
     'account_title',
     if (appState.accountType == 'gig') 'my_work_title',
     'account_tracking',
     'account_vehicles_reports',
     'preferences',
     'account_help',
   ];
   for (final k in _tourOrder) {
     _tourKeys.putIfAbsent(k, () => GlobalKey());
   }
   _maybeStartTour(appState);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildHeader(context, appState),
                const SizedBox(height: 8),

                // --- Sección: Navegación Principal ---
                _buildSectionLabel(appState, 'navigation', labelColor),
                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.dashboard_rounded,
                  labelKey: 'dashboard',
                  route: AppRoutes.dashboard,
                  textColor: textColor,
                  chevronColor: chevronColor,
                ),
                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.history_rounded,
                  labelKey: 'history',
                  route: AppRoutes.history,
                  textColor: textColor,
                  chevronColor: chevronColor,
                ),
                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.assessment_rounded,
                  labelKey: 'reports',
                  route: AppRoutes.reports,
                  textColor: textColor,
                  chevronColor: chevronColor,
                ),
                Divider(indent: 20, endIndent: 20, height: 20, color: dividerColor),

                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.person_rounded,
                  labelKey: 'account_title',
                  route: AppRoutes.profile,
                  textColor: textColor,
                  chevronColor: chevronColor,
                ),
                if (appState.accountType == 'gig')
                  _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.work_rounded,
                  labelKey: 'my_work_title',
                  route: AppRoutes.myWork,
                  textColor: textColor,
                  chevronColor: chevronColor,
                ),
                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.location_on_rounded,
                  labelKey: 'account_tracking',
                  route: AppRoutes.accountTracking,
                  textColor: textColor,
                  chevronColor: chevronColor,
                ),
                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.directions_car_rounded,
                  labelKey: 'account_vehicles_reports',
                  route: AppRoutes.vehiclesReports,
                  textColor: textColor,
                  chevronColor: chevronColor,
                ),
                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.tune_rounded,
                  labelKey: 'preferences',
                  route: AppRoutes.accountPreferences,
                  textColor: textColor,
                  chevronColor: chevronColor,
                ),
                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.help_rounded,
                  labelKey: 'account_help',
                  route: AppRoutes.helpLegal,
                  textColor: textColor,
                  chevronColor: chevronColor,
                ),

                Divider(indent: 20, endIndent: 20, height: 20, color: dividerColor),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: Text(
                    appState.tr('logout'),
                    style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  onTap: () => _confirmLogout(context, appState),
                  trailing: Icon(Icons.chevron_right, size: 18, color: chevronColor),
                ),
              ],
            ),
          ),

          // Edge to edge on recent Android: the phone's own buttons covered this.
          SafeArea(top: false, child: _buildFooter(appState, isDark, dividerColor)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppState appState) {
    // FIX 1: userEmail eliminado — ya no se declara ni se usa

    return Container(
      width: double.infinity,
      // The ID tab sits flush on the header's bottom edge and left side
      // (owner's request, 2026-10-09); the logo row keeps its own 24 px sides.
      padding: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E281F),
            Color(0xFF1C1812),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Explicit user request: wordmark moved next to the logo
          // (was stacked below it) -- a single horizontal lockup instead
          // of two separate lines.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
            children: [
              Image.asset(
                'assets/images/logo_controlmiles.png',
                height: 40,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  appState.tr('app_name'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          ),
          // FIX 2: Text(userEmail) eliminado — línea de email removida
          const SizedBox(height: 26),
          // BUG FIX (pedido explícito): el quick-toggle de auto-detect que
          // vivía acá se movió al Dashboard, junto al botón Start -- tener
          // los dos a la vez era un control duplicado para la misma
          // función. Fila ahora solo con el badge de ID.
          Row(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 7, 14, 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(10)),
                ),
                child: Text(
                  "ID: ${appState.userDisplayId ?? '---'}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              // Language (2026-10-09, owner's request): moved from the menu
              // list to this header's right corner, mirroring the ID tab; it
              // only opens the list of languages.
              PopupMenuButton<AppLanguage>(
                tooltip: appState.tr('language'),
                position: PopupMenuPosition.under,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                constraints: const BoxConstraints(minWidth: 200, maxHeight: 420),
                onSelected: (lang) {
                  if (lang != appState.currentLanguage) appState.setLanguage(lang);
                },
                itemBuilder: (context) => AppLanguage.values
                    .map((lang) => PopupMenuItem<AppLanguage>(
                          value: lang,
                          child: Row(
                            children: [
                              Text(lang.flag, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  lang.label,
                                  style: TextStyle(
                                      fontWeight:
                                          lang == appState.currentLanguage ? FontWeight.w800 : FontWeight.w500),
                                ),
                              ),
                              if (lang == appState.currentLanguage)
                                Icon(Icons.check_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                            ],
                          ),
                        ))
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 5, 20, 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(10)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(appState.currentLanguage.flag, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(
                        appState.currentLanguage.code.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildSectionLabel(AppState appState, String labelKey, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        appState.tr(labelKey).toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: labelColor,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appState.tr('logout')),
        content: Text(appState.tr('logout_confirmation')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(appState.tr('cancel'))),
          TextButton(
            onPressed: () async {
              // Taken before anything closes: this context lives inside the Drawer,
              // and without the root navigator sign-out never reached Login.
              final rootNavigator = Navigator.of(context, rootNavigator: true);
              Navigator.pop(ctx);
              Navigator.pop(context);
              // Never throws and always clears the cached account.
              await appState.signOutAndClear();
              rootNavigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(appState.tr('logout'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required AppState appState,
    required IconData icon,
    required String labelKey,
    required String route,
    required Color textColor,
    required Color chevronColor,
  }) {
    final tile = ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
      title: Text(
        appState.tr(labelKey),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      onTap: () {
        if (route == AppRoutes.dashboard) {
          // The dashboard is already underneath this page.
          Navigator.pop(context);
        } else {
          // Opened on top of the menu, so going back returns to it (owner's request,
          // 2026-11-09: closing the menu first sent the driver back to the dashboard).
          Navigator.pushNamed(context, route);
        }
      },
      trailing: Icon(Icons.chevron_right, size: 18, color: chevronColor),
    );
    final step = _tourOrder.indexOf(labelKey);
    if (step < 0) return tile;
    final basic = !appState.premiumEntitled && (labelKey == 'my_work_title' || labelKey == 'account_tracking');
    return TourTarget(
      showcaseKey: _tourKeys[labelKey]!,
      scope: _scope.name,
      step: step + 1,
      total: _tourOrder.length,
      titleKey: labelKey,
      bodyKey: '${_tourBodies[labelKey]!}${basic ? '_basic' : ''}',
      radius: BorderRadius.zero,
      child: tile,
    );
  }

  Widget _buildFooter(AppState appState, bool isDark, Color dividerColor) {
    final mutedColor = isDark ? Colors.white38 : Colors.grey;
    final faintColor = isDark ? Colors.white24 : Colors.grey[400];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: dividerColor))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppVersionText(style: TextStyle(color: mutedColor, fontSize: 10)),
              Text(appState.tr('app_version').toUpperCase(),
                  style: TextStyle(color: mutedColor, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 8),
          // BUG FIX (pedido explícito, 2026-09-09): el orden estaba al
          // revés -- renderizaba "All rights reserved 2026 ControlMiles"
          // en vez de "© 2026 ControlMiles. All rights reserved.".
          Text('© 2026 ControlMiles. ${appState.tr('copyright')}.', style: TextStyle(color: faintColor, fontSize: 9)),
        ],
      ),
    );
  }
}