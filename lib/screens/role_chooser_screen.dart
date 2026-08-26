// Olympus Mont Systems LLC - ControlMiles
// lib/screens/role_chooser_screen.dart
//
// First screen a brand-new device ever sees, before login/signup --
// Gig App Driver / Fleet Driver / Fleet Admin. Shown exactly once per
// device (AppState.hasSeenRoleChooser, SharedPreferences -- see
// AppRoutes.getInitialRoute, the only place this decision is made).
// Picking a role stores it as pendingIntendedRole so signup goes
// straight to the right destination afterward (skipping the redundant
// post-signup AccountTypeScreen), instead of asking the same question
// twice -- see WelcomePage._completeOnboarding.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../routes/app_routes.dart';

class RoleChooserScreen extends StatefulWidget {
  const RoleChooserScreen({super.key});

  @override
  State<RoleChooserScreen> createState() => _RoleChooserScreenState();
}

class _RoleChooserScreenState extends State<RoleChooserScreen> {
  bool _isProcessing = false;

  Future<void> _chooseRole(AppState appState, String role) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await appState.chooseIntendedRole(role);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login, arguments: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _alreadyHaveAccount(AppState appState) async {
    if (_isProcessing) return;
    await appState.skipRoleChooser();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appState.tr('role_chooser_title'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(height: 6),
              Text(
                appState.tr('role_chooser_subtitle'),
                style: TextStyle(fontSize: 13, color: subTextColor),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView(
                  children: [
                    _RoleCard(
                      icon: Icons.person_rounded,
                      title: appState.tr('role_gig_title'),
                      description: appState.tr('role_gig_desc'),
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      accent: primary,
                      isLoading: _isProcessing,
                      onTap: () => _chooseRole(appState, 'gig'),
                    ),
                    const SizedBox(height: 16),
                    _RoleCard(
                      icon: Icons.badge_rounded,
                      title: appState.tr('role_fleet_driver_title'),
                      description: appState.tr('role_fleet_driver_desc'),
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      accent: primary,
                      isLoading: _isProcessing,
                      onTap: () => _chooseRole(appState, 'fleet_driver'),
                    ),
                    const SizedBox(height: 16),
                    _RoleCard(
                      icon: Icons.local_shipping_rounded,
                      title: appState.tr('role_fleet_admin_title'),
                      description: appState.tr('role_fleet_admin_desc'),
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      accent: primary,
                      isLoading: _isProcessing,
                      onTap: () => _chooseRole(appState, 'fleet_admin'),
                    ),
                  ],
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: _isProcessing ? null : () => _alreadyHaveAccount(appState),
                  child: Text(
                    appState.tr('role_chooser_have_account'),
                    style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color subTextColor;
  final Color accent;
  final bool isLoading;
  final VoidCallback? onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.subTextColor,
    required this.accent,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isLoading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 3),
                    Text(description, style: TextStyle(fontSize: 12.5, color: subTextColor)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: subTextColor),
            ],
          ),
        ),
      ),
    );
  }
}
