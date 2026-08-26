// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/main_drawer.dart - FULL I18N PRODUCTION READY

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';
import '../routes/app_routes.dart';
import '../i18n/app_texts.dart';

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
   final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
   final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
   final labelColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);
   final dividerColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
   final chevronColor = isDark ? Colors.white24 : const Color(0xFFCBD5E1);

    return Drawer(
      backgroundColor: bgColor,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildHeader(appState),
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
                _buildLanguageSelector(context, appState, textColor, chevronColor),

                // BUG FIX (pedido explícito): botón dedicado para alternar
                // modo oscuro directo desde el sidebar, sin tener que entrar
                // a Settings.
                _buildDarkModeToggle(context, appState, textColor),

                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.settings_rounded,
                  labelKey: 'settings',
                  route: AppRoutes.settings,
                  textColor: textColor,
                  chevronColor: chevronColor,
                ),
                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.person_rounded,
                  labelKey: 'profile',
                  route: AppRoutes.profile,
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

  Widget _buildHeader(AppState appState) {
    // FIX 1: userEmail eliminado — ya no se declara ni se usa

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/images/logo_controlmiles.png', 
            height: 55,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            appState.tr('app_name'), 
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          // FIX 2: Text(userEmail) eliminado — línea de email removida
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
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

  Widget _buildLanguageSelector(BuildContext context, AppState appState, Color textColor, Color chevronColor) {
    return ListTile(
      leading: Icon(Icons.language, color: Theme.of(context).colorScheme.primary, size: 22),
      title: Text(
        appState.tr('language'),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      subtitle: Text(
        '${appState.currentLanguage.flag} ${appState.currentLanguage.label}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, AppRoutes.settings);
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
      trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCBD5E1)),
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
              Navigator.pop(ctx);
              Navigator.pop(context);

              // BUG FIX (pedido explícito): AuthService().signOut() directo
              // sin try/catch dejaba la app "colgada" si esa llamada de red
              // fallaba (la navegación de abajo nunca se ejecutaba), y
              // nunca limpiaba AppState.userDisplayId -- el próximo login
              // con otra cuenta mostraba el ID de esta. signOutAndClear()
              // nunca lanza y siempre limpia el estado cacheado.
              await appState.signOutAndClear();

              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
              }
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
              Text("v1.0.0 Stable", style: TextStyle(color: mutedColor, fontSize: 10)),
              Text(appState.tr('company').toUpperCase(),
                  style: TextStyle(color: mutedColor, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 8),
          Text('${appState.tr('copyright')} 2026 Olympus Mont Systems LLC', style: TextStyle(color: faintColor, fontSize: 9)),
        ],
      ),
    );
  }
}