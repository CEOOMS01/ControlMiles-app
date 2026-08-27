// Olympus Mont Systems LLC - ControlMiles
// lib/screens/settings_screen.dart - FULL I18N PRODUCTION READY

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';
import '../i18n/app_texts.dart';
import '../models/organization.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../services/organization_service.dart';
import '../services/gig_app_detection_service.dart';
import '../tracking/auto_trip_detection_service.dart';
import '../legal/legal_documents.dart';
import 'legal_document_screen.dart';

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
class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final OrganizationService _organizationService = OrganizationService();
  bool _isDeletingAccount = false;
  bool _isSwitchingMode = false;
  bool _isTogglingAutoDetect = false;
  // Usage Access is a "special access" permission granted from system
  // Settings, not a runtime dialog -- WidgetsBindingObserver re-checks
  // it on resume, since that's the only reliable moment to notice the
  // user just came back from granting it there.
  bool _hasUsageAccess = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        GigAppDetectionService.instance.isSupported) {
      _refreshUsageAccessStatus();
    }
  }

  Future<void> _refreshUsageAccessStatus() async {
    final granted = await GigAppDetectionService.instance.hasUsageAccess();
    if (mounted) setState(() => _hasUsageAccess = granted);
  }

  // Explicit user requirement (mobile Settings, fleet_admin only): show
  // the org's name and let its owner/admin rename or delete it. Rename
  // ports the same web capability (organizations_update_admin RLS);
  // delete is new -- routes through delete_organization (SECURITY
  // DEFINER RPC), never a raw client DELETE, since 6 child tables have
  // NO ACTION on organization_id and a raw DELETE would either fail
  // outright or, for an org without those rows, silently cascade through
  // vehicles/members/routes while leaving every member's account_type
  // desynced. See organization_service.dart's own comment.
  Organization? _organization;
  bool _isLoadingOrg = false;
  bool _isRenamingOrg = false;
  bool _isDeletingOrg = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (GigAppDetectionService.instance.isSupported) {
      _refreshUsageAccessStatus();
    }

    final appState = context.read<AppState>();
    if (appState.isFleetAdmin) {
      _loadOrganization(appState);
    }
  }

  Future<void> _loadOrganization(AppState appState) async {
    final orgId = appState.defaultOrgId;
    if (orgId == null) return;
    setState(() => _isLoadingOrg = true);
    try {
      final org = await _organizationService.getOrganization(orgId);
      if (mounted) setState(() => _organization = org);
    } finally {
      if (mounted) setState(() => _isLoadingOrg = false);
    }
  }

  Future<void> _showRenameOrgDialog(AppState appState) async {
    final controller = TextEditingController(text: _organization?.name ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appState.tr('org_rename_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: appState.tr('org_name_label'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(appState.tr('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(appState.tr('save')),
          ),
        ],
      ),
    );

    if (!mounted || newName == null || newName.isEmpty || newName == _organization?.name) return;
    final orgId = appState.defaultOrgId;
    if (orgId == null) return;

    setState(() => _isRenamingOrg = true);
    try {
      await _organizationService.renameOrganization(orgId, newName);
      await _loadOrganization(appState);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appState.tr('org_renamed_success'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${appState.tr('error')}: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRenamingOrg = false);
    }
  }

  void _showDeleteOrgDialog(AppState appState) {
    final controller = TextEditingController();
    final orgName = _organization?.name ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final canConfirm = orgName.isNotEmpty && controller.text.trim() == orgName;
          return AlertDialog(
            title: Text(appState.tr('org_delete_confirm_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appState.tr('org_delete_confirm_body')),
                const SizedBox(height: 16),
                Text(
                  '${appState.tr('org_delete_type_to_confirm')} ($orgName)',
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
                        _deleteOrganization(appState);
                      }
                    : null,
                child: Text(appState.tr('org_delete_button')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteOrganization(AppState appState) async {
    final orgId = appState.defaultOrgId;
    if (orgId == null) return;

    setState(() => _isDeletingOrg = true);
    try {
      await _organizationService.deleteOrganization(orgId);
      await appState.refreshAccountType();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.tr('org_deleted_success'))),
      );
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboard, (route) => false);
    } catch (e) {
      if (mounted) {
        setState(() => _isDeletingOrg = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${appState.tr('error')}: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

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

  // Premium Gig feature: automatic trip detection. onboarding
  // (welcome_page.dart) already requests locationAlways +
  // activityRecognition for every user -- the plugin's own motion
  // detection needs both -- but a user can still revoke either later
  // from system settings, so this re-checks before actually arming.
  Future<void> _handleAutoDetectToggle(AppState appState, bool value) async {
    if (_isTogglingAutoDetect) return;
    setState(() => _isTogglingAutoDetect = true);

    try {
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

          if (appState.isFleetAdmin && (_isLoadingOrg || _organization != null)) ...[
            _buildSectionHeader(appState, 'organization_section_title', isDark),
            _buildOrganizationSection(appState, isDark),
          ],

          if (appState.isGig) ...[
            _buildSectionHeader(appState, 'automatic_tracking_section', isDark),
            _buildAutoDetectSection(appState, isDark),
          ],

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

  Widget _buildOrganizationSection(AppState appState, bool isDark) {
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white54 : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    if (_isLoadingOrg) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_organization == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: ListTile(
              leading: Icon(Icons.local_shipping_rounded, color: Theme.of(context).colorScheme.primary),
              title: Text(
                _organization!.name,
                style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
              ),
              subtitle: Text(appState.tr('org_rename_hint'), style: TextStyle(fontSize: 12, color: subTextColor)),
              trailing: _isRenamingOrg
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.edit_rounded, color: subTextColor),
              onTap: _isRenamingOrg ? null : () => _showRenameOrgDialog(appState),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.red.shade900 : Colors.red.shade100),
            ),
            child: ListTile(
              leading: _isDeletingOrg
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                  : const Icon(Icons.delete_forever_rounded, color: Colors.red),
              title: Text(
                appState.tr('org_delete_button'),
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              onTap: _isDeletingOrg ? null : () => _showDeleteOrgDialog(appState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoDetectSection(AppState appState, bool isDark) {
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white54 : const Color(0xFF64748B);
    final locked = !appState.premiumEntitled;
    final primary = Theme.of(context).colorScheme.primary;

    final showUsageAccessRow = !locked &&
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
              leading: Icon(Icons.auto_awesome_rounded, color: locked ? subTextColor : primary),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      appState.tr('auto_detect_toggle_title'),
                      style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                    ),
                  ),
                  if (locked) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        appState.tr('premium_badge'),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: primary, letterSpacing: 0.5),
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
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Switch.adaptive(
                          value: appState.autoDetectEnabled,
                          onChanged: (v) => _handleAutoDetectToggle(appState, v),
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
                leading: Icon(
                  _hasUsageAccess ? Icons.check_circle_rounded : Icons.apps_rounded,
                  color: _hasUsageAccess ? Colors.green.shade600 : subTextColor,
                ),
                title: Text(
                  appState.tr('gig_app_detection_title'),
                  style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                ),
                subtitle: Text(
                  appState.tr(_hasUsageAccess
                      ? 'gig_app_detection_subtitle_granted'
                      : 'gig_app_detection_subtitle_not_granted'),
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
                trailing: _hasUsageAccess ? null : Icon(Icons.chevron_right_rounded, color: subTextColor),
                onTap: _hasUsageAccess
                    ? null
                    : () => GigAppDetectionService.instance.openUsageAccessSettings(),
              ),
            ),
          ],
          // Explicit user follow-up request: mid-trip gig-app-switch
          // behavior is its own savable/revertible choice, separate from
          // auto-detect itself -- default OFF (ask first via a
          // notification + the Dashboard status card's tap-to-switch),
          // ON switches silently and just confirms afterward.
          if (!locked && appState.autoDetectEnabled) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: Icon(Icons.swap_horiz_rounded, color: primary),
                title: Text(
                  appState.tr('auto_switch_toggle_title'),
                  style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                ),
                subtitle: Text(
                  appState.tr('auto_switch_toggle_subtitle'),
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
                trailing: Switch.adaptive(
                  value: appState.autoSwitchGigApp,
                  onChanged: (v) => appState.setAutoSwitchGigApp(v),
                  activeThumbColor: primary,
                ),
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
    final subTextColor = isDark ? Colors.white54 : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildAboutRow(appState.tr('app_version'), 'v2.0.1', isDark),
                Divider(height: 32, color: isDark ? const Color(0xFF1E293B) : null),
                _buildAboutRow(appState.tr('company'), 'Olympus Mont Systems LLC', isDark),
                Divider(height: 32, color: isDark ? const Color(0xFF1E293B) : null),
                // Explicit user request (legal risk mitigation, 2026-08-27):
                // a short, always-visible non-affiliation disclaimer -- the
                // full legal text lives in Privacy Policy/Terms below, but
                // this is the one line that has to be visible WITHOUT a
                // tap, since it's what separates "referring to a trademark"
                // from "implying a partnership" under nominative fair use.
                Text(
                  appState.tr('trademark_disclaimer_short'),
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: subTextColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildLegalLinkRow(
            icon: Icons.privacy_tip_outlined,
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
                  // relationship that's actually live once isFleetAccount
                  // is true.
                  body: appState.isFleetAccount ? privacyPolicyFleetEn : privacyPolicyEn,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildLegalLinkRow(
            icon: Icons.description_outlined,
            label: appState.tr('terms_conditions'),
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LegalDocumentScreen(
                  titleKey: 'terms_conditions',
                  body: appState.isFleetAccount ? termsOfServiceFleetEn : termsOfServiceEn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // BUG FIX (pedido explícito, riesgo legal): privacy_policy/terms_conditions
  // ya existían como claves i18n traducidas en los 11 idiomas -- pero
  // ninguna pantalla las usaba nunca (grep confirmó cero call sites fuera
  // de los archivos de i18n). No había Privacy Policy ni Terms of Service
  // accesibles desde la app, pese a que ControlMiles pide permisos
  // sensibles (ubicación en segundo plano, cámara, Usage Access). Estas
  // dos filas cierran ese hueco.
  Widget _buildLegalLinkRow({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white54 : const Color(0xFF64748B);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
        trailing: Icon(Icons.chevron_right_rounded, color: subTextColor),
        onTap: onTap,
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