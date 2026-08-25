// Olympus Mont Systems LLC - ControlMiles
// lib/screens/settings_screen.dart - FULL I18N PRODUCTION READY

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';
import '../i18n/app_texts.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';

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
  bool _isDeletingAccount = false;

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          appState.tr('settings').toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _buildSectionHeader(appState, 'language'),
          _buildLanguageSection(appState),

          _buildSectionHeader(appState, 'preferences'),
          _buildPreferencesSection(appState),

          _buildSectionHeader(appState, 'about_app'),
          _buildAboutSection(appState),

          _buildSectionHeader(appState, 'danger_zone'),
          _buildDangerZoneSection(appState),
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
  Widget _buildDangerZoneSection(AppState appState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade100),
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

  Widget _buildSectionHeader(AppState appState, String labelKey) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appState.tr(labelKey).toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF94A3B8),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 2, width: 40, color: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }

  Widget _buildLanguageSection(AppState appState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: AppLanguage.values.map((lang) {
          final isSelected = appState.currentLanguage == lang;
          return _buildLanguageOption(
            language: lang,
            isSelected: isSelected,
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
    required VoidCallback onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    // BUG FIX (pedido explícito, cuadros invisibles en modo día): el borde
    // sin seleccionar estaba en grey.shade100, casi idéntico al fondo del
    // scaffold (#F8FAFC) -- ahora usa el mismo token de borde que el resto
    // de la app (#E2E8F0). NO se toca el fondo (se queda Colors.white
    // hardcodeado, igual que el resto de este archivo) -- este screen
    // completo no tiene soporte de modo oscuro (Scaffold, AppBar y todas
    // las demás secciones usan colores fijos sin isDark en ningún otro
    // lado). Meterle dark mode a un solo widget acá crearía una tarjeta
    // oscura flotando sobre un fondo claro fijo, peor que el bug original.
    // Si quieres modo oscuro real en Settings, es un fix aparte que toca
    // todo el archivo, no solo este widget.
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? primary : const Color(0xFFE2E8F0),
          width: 2,
        ),
        boxShadow: isSelected
            ? [BoxShadow(color: primary.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))]
            : [],
      ),
      child: ListTile(
        leading: Text(language.flag, style: const TextStyle(fontSize: 22)),
        title: Text(language.label, style: TextStyle(
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
          color: isSelected ? primary : const Color(0xFF1E293B),
        )),
        trailing: isSelected ? Icon(Icons.check_circle, color: primary) : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildPreferencesSection(AppState appState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildToggleSetting(
            icon: Icons.notifications_active_outlined,
            title: appState.tr('notifications'),
            value: appState.notificationsEnabled,
            onChanged: (v) => appState.setNotificationsEnabled(v),
          ),
          const SizedBox(height: 10),
          _buildToggleSetting(
            icon: Icons.straighten_rounded,
            title: appState.tr('metric_system') ?? 'Metric System', // Llave validada
            value: appState.useMetricSystem,
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
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildAboutSection(AppState appState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _buildAboutRow(appState.tr('app_version'), 'v1.0.0 Stable'),
            const Divider(height: 32),
            _buildAboutRow(appState.tr('company'), 'Olympus Mont Systems LLC'),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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