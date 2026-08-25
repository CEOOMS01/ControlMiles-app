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

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildHeader(appState),
                const SizedBox(height: 8),

                // --- Sección: Navegación Principal ---
                _buildSectionLabel(appState, 'navigation'), 
                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.dashboard_rounded,
                  labelKey: 'dashboard',
                  route: AppRoutes.dashboard,
                ),
                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.history_rounded,
                  labelKey: 'history',
                  route: AppRoutes.history,
                ),
                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.assessment_rounded,
                  labelKey: 'reports',
                  route: AppRoutes.reports,
                ),
                // BUG FIX (pedido explícito): gestión de vehículo se separó
                // de Settings — pantalla propia debajo de Reports.
                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.directions_car_rounded,
                  labelKey: 'vehicle',
                  route: AppRoutes.vehicle,
                ),

                const Divider(indent: 20, endIndent: 20, height: 20),

                // --- Sección: Preferencias ---
                _buildSectionHeader(appState, 'settings'),
                _buildLanguageSelector(context, appState),
                
                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.settings_rounded,
                  labelKey: 'settings',
                  route: AppRoutes.settings,
                ),
                _buildMenuItem(
                  context: context,
                  appState: appState,
                  icon: Icons.person_rounded,
                  labelKey: 'profile',
                  route: AppRoutes.profile,
                ),

                const Divider(indent: 20, endIndent: 20, height: 20),
                _buildLogoutButton(context, appState),
              ],
            ),
          ),

          _buildFooter(appState),
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

  Widget _buildSectionLabel(AppState appState, String labelKey) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        appState.tr(labelKey).toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(AppState appState, String labelKey) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        appState.tr(labelKey).toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Color(0xFF94A3B8),
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
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
      title: Text(
        appState.tr(labelKey),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
      ),
      onTap: () {
        Navigator.pop(context); 
        Navigator.pushNamed(context, route);
      },
      trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCBD5E1)),
    );
  }

  Widget _buildLanguageSelector(BuildContext context, AppState appState) {
    return ListTile(
      leading: Icon(Icons.language, color: Theme.of(context).colorScheme.primary, size: 22),
      title: Text(
        appState.tr('language'),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
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
      trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCBD5E1)),
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

  Widget _buildFooter(AppState appState) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("v1.0.0 Stable", style: TextStyle(color: Colors.grey, fontSize: 10)),
              Text(appState.tr('company').toUpperCase(), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 8),
          Text('${appState.tr('copyright')} 2026 Olympus Mont Systems LLC', style: TextStyle(color: Colors.grey[400], fontSize: 9)),
        ],
      ),
    );
  }
}