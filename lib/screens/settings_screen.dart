// Olympus Mont Systems LLC - ControlMiles
// lib/screens/settings_screen.dart - FULL I18N PRODUCTION READY

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';
import '../i18n/app_texts.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../services/organization_service.dart';

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
class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final OrganizationService _organizationService = OrganizationService();
  bool _isDeletingAccount = false;
  bool _isSwitchingMode = false;

  // Explicit user requirement: switch between Gig/Fleet Admin/Fleet
  // Driver on the same account, persisting -- for testing, and for a
  // real hybrid user (owns a fleet, also drives personally). The RPC
  // validates real membership; a mode this account doesn't qualify for
  // (e.g. Fleet Admin with no organization owned) surfaces its own
  // clear error instead of silently doing nothing.
  Future<void> _switchMode(AppState appState, String mode) async {
    if (_isSwitchingMode || appState.accountType == mode) return;
    setState(() => _isSwitchingMode = true);
    try {
      await _organizationService.switchAccountMode(mode);
      await appState.refreshAccountType();
      if (!mounted) return;

      final target = switch (mode) {
        'fleet_admin' => AppRoutes.fleetDashboard,
        'fleet_driver' => AppRoutes.driverOperations,
        _ => AppRoutes.dashboard,
      };
      Navigator.pushNamedAndRemoveUntil(context, target, (route) => false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSwitchingMode = false);
    }
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          appState.tr('settings').toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _buildSectionHeader(appState, 'language', isDark),
          _buildLanguageSection(appState, isDark),

          _buildSectionHeader(appState, 'account_mode_title', isDark),
          _buildAccountModeSection(appState, isDark),

          _buildSectionHeader(appState, 'preferences', isDark),
          _buildPreferencesSection(appState, isDark),

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
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.red.shade900 : Colors.red.shade100),
        ),
        child: ListTile(
          leading: _isDeletingAccount
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
              : const Icon(Icons.delete_forever_rounded, color: Colors.red),
          title: Text(
            appState.tr('delete_account'),
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          onTap: _isDeletingAccount ? null : () => _showDeleteAccountDialog(appState),
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
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(appState.tr('cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.tr('delete_account_success'))),
      );
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
    } catch (e) {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${appState.tr('error')}: $e'),
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
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 2, width: 40, color: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }

  Widget _buildLanguageSection(AppState appState, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: AppLanguage.values.map((lang) {
          final isSelected = appState.currentLanguage == lang;
          return _buildLanguageOption(
            language: lang,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () {
              appState.setLanguage(lang);
              _showChangeConfirmation(context, appState, lang);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLanguageOption({
    required AppLanguage language,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? primary : borderColor,
          width: 2,
        ),
        boxShadow: isSelected
            ? [BoxShadow(color: primary.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))]
            : [],
      ),
      child: ListTile(
        leading: Text(language.flag, style: const TextStyle(fontSize: 22)),
        title: Text(language.label, style: TextStyle(
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
          color: isSelected ? primary : textColor,
        )),
        trailing: isSelected ? Icon(Icons.check_circle, color: primary) : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildAccountModeSection(AppState appState, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildModeOption(
            appState: appState,
            isDark: isDark,
            icon: Icons.person_rounded,
            label: appState.tr('account_mode_gig'),
            mode: 'gig',
          ),
          const SizedBox(height: 10),
          _buildModeOption(
            appState: appState,
            isDark: isDark,
            icon: Icons.local_shipping_rounded,
            label: appState.tr('account_mode_fleet_admin'),
            mode: 'fleet_admin',
          ),
          const SizedBox(height: 10),
          _buildModeOption(
            appState: appState,
            isDark: isDark,
            icon: Icons.badge_rounded,
            label: appState.tr('account_mode_fleet_driver'),
            mode: 'fleet_driver',
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required AppState appState,
    required bool isDark,
    required IconData icon,
    required String label,
    required String mode,
  }) {
    final isSelected = appState.accountType == mode;
    final primary = Theme.of(context).colorScheme.primary;
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _isSwitchingMode ? null : () => _switchMode(appState, mode),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? primary : borderColor, width: isSelected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? primary : textColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                    color: isSelected ? primary : textColor,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: primary)
              else if (_isSwitchingMode)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesSection(AppState appState, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildToggleSetting(
            icon: Icons.notifications_active_outlined,
            title: appState.tr('notifications'),
            value: appState.notificationsEnabled,
            isDark: isDark,
            onChanged: (v) => appState.setNotificationsEnabled(v),
          ),
          const SizedBox(height: 10),
          _buildToggleSetting(
            icon: Icons.straighten_rounded,
            title: appState.tr('metric_system'), // Llave validada
            value: appState.useMetricSystem,
            isDark: isDark,
            onChanged: (v) => appState.setUseMetricSystem(v),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSetting({
    required IconData icon,
    required String title,
    required bool value,
    required bool isDark,
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildAboutSection(AppState appState, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _buildAboutRow(appState.tr('app_version'), 'v1.0.0 Stable', isDark),
            Divider(height: 32, color: isDark ? const Color(0xFF1E293B) : null),
            _buildAboutRow(appState.tr('company'), 'Olympus Mont Systems LLC', isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
        Text(value, style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B), fontSize: 13)),
      ],
    );
  }

  void _showChangeConfirmation(BuildContext context, AppState appState, AppLanguage language) {
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