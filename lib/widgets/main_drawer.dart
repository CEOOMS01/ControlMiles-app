// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/main_drawer.dart - FULL I18N PRODUCTION READY

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';
import '../routes/app_routes.dart';
import '../i18n/app_texts.dart';
import 'org_mode_switcher.dart';
import 'app_version_text.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

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

    return Drawer(
      backgroundColor: bgColor,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildHeader(context, appState),
                const SizedBox(height: 8),

                // Explicit user request (moved from the dashboard body,
                // 2026-09-09): the Personal/Company switcher lives here now
                // instead of taking up space in the dashboard's scrollable
                // content -- same widget, same self-gating (renders nothing
                // for a non-hybrid account), just relocated.
                const OrgModeSwitcher(),

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
                // BUG FIX (pedido explícito): gestión de vehículo se separó
                // de Settings — pantalla propia debajo de Reports.
                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.directions_car_rounded,
                  labelKey: 'vehicle',
                  route: AppRoutes.vehicle,
                  textColor: textColor,
                  chevronColor: chevronColor,
                ),

                Divider(indent: 20, endIndent: 20, height: 20, color: dividerColor),

                // --- Sección: Preferencias ---
                _buildSectionHeader(appState, 'settings', labelColor),

                // BUG FIX (pedido explícito): botón dedicado para alternar
                // modo oscuro directo desde el sidebar, sin tener que entrar
                // a Settings.
                _buildDarkModeToggle(context, appState, textColor),

                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.person_rounded,
                  labelKey: 'profile',
                  route: AppRoutes.profile,
                  textColor: textColor,
                  chevronColor: chevronColor,
                ),
                // Settings last, under Profile (owner's request, 2026-10-09).
                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.settings_rounded,
                  labelKey: 'settings',
                  route: AppRoutes.settings,
                  textColor: textColor,
                  chevronColor: chevronColor,
                ),

                Divider(indent: 20, endIndent: 20, height: 20, color: dividerColor),
                _buildLogoutButton(context, appState),
              ],
            ),
          ),

          _buildFooter(appState, isDark, dividerColor),
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

  Widget _buildSectionHeader(AppState appState, String labelKey, Color labelColor) {
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

  Widget _buildMenuItem({
    required BuildContext context,
    required AppState appState,
    required IconData icon,
    required String labelKey,
    required String route,
    required Color textColor,
    required Color chevronColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
      title: Text(
        appState.tr(labelKey),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
      trailing: Icon(Icons.chevron_right, size: 18, color: chevronColor),
    );
  }

  Widget _buildDarkModeToggle(BuildContext context, AppState appState, Color textColor) {
    return ListTile(
      leading: Icon(
        appState.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: 22,
      ),
      title: Text(
        appState.tr('dark_mode'),
        style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
      ),
      trailing: Switch.adaptive(
        value: appState.isDarkMode,
        onChanged: (_) => appState.toggleDarkMode(),
        activeThumbColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AppState appState) {
    return ListTile(
      leading: const Icon(Icons.logout_rounded, color: Colors.red),
      title: Text(
        appState.tr('logout'),
        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      ),
      onTap: () => _showLogoutConfirmation(context, appState),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCFC3A8)),
    );
  }

  void _showLogoutConfirmation(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appState.tr('logout')),
        content: Text(appState.tr('logout_confirmation')), 
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(appState.tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              // BUG FIX (pedido explícito, "logout se queda en modo
              // invernación, solo lleva a Login si se cierra la app por
              // completo"): el `context` de este botón vive DENTRO del
              // Drawer. `Navigator.pop(context)` dos líneas abajo cierra
              // ese Drawer -- y con él, Flutter puede desmontar el
              // subárbol del Drawer en cualquier momento del frame
              // siguiente. Cuando eso pasaba ANTES de que el `await`
              // terminara, `context.mounted` daba false y el
              // `pushNamedAndRemoveUntil` de abajo se saltaba en
              // silencio: la sesión SÍ se cerraba (signOutAndClear ya
              // corrió), pero nadie navegaba a Login -- exactamente el
              // síntoma reportado. Capturar el NavigatorState del
              // navigator RAÍZ ANTES de cualquier pop/await lo hace
              // inmune a que este context puntual se desmonte después;
              // el Navigator raíz de la app vive mientras la app viva.
              final rootNavigator = Navigator.of(context, rootNavigator: true);

              Navigator.pop(ctx);
              Navigator.pop(context);

              // BUG FIX (pedido explícito): AuthService().signOut() directo
              // sin try/catch dejaba la app "colgada" si esa llamada de red
              // fallaba (la navegación de abajo nunca se ejecutaba), y
              // nunca limpiaba AppState.userDisplayId -- el próximo login
              // con otra cuenta mostraba el ID de esta. signOutAndClear()
              // nunca lanza y siempre limpia el estado cacheado.
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