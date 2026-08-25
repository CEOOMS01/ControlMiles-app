// Olympus Mont Systems LLC - ControlMiles
// lib/screens/account_type_screen.dart
//
// Fleet Phase 1: shown exactly once, right after the existing
// permissions/welcome step (see WelcomePage._completeOnboarding), before
// user_onboarding.account_type_chosen is true. Picking "Gig" is a pure
// local flag flip -- profiles.account_type is already 'gig' by default
// (handle_new_user trigger), nothing to write. Picking "Fleet" leads into
// CreateOrganizationScreen.
//
// BUG FIX (pedido explícito): un tercer card deshabilitado "I have an
// invite code" vivía acá desde la Fase 1, cuando ese flujo todavía no
// existía. Desde la Fase 2, PendingInviteScreen intercepta ANTES que esta
// pantalla (ver AppRoutes.getInitialRoute: pending invites tiene
// prioridad sobre account-type-chosen) -- un usuario con invitación
// pendiente nunca llega a ver este choice screen. El card deshabilitado
// quedó como UI muerta que insinuaba "coming soon" para algo que ya
// funciona por otro camino -- se quita.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../routes/app_routes.dart';

class AccountTypeScreen extends StatefulWidget {
  const AccountTypeScreen({super.key});

  @override
  State<AccountTypeScreen> createState() => _AccountTypeScreenState();
}

class _AccountTypeScreenState extends State<AccountTypeScreen> {
  bool _isProcessing = false;

  Future<void> _chooseGig(AppState appState) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await appState.completeAccountTypeChoice();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _chooseFleet() {
    if (_isProcessing) return;
    Navigator.pushReplacementNamed(context, AppRoutes.createOrganization);
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
                appState.tr('account_type_title'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(height: 6),
              Text(
                appState.tr('account_type_subtitle'),
                style: TextStyle(fontSize: 13, color: subTextColor),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView(
                  children: [
                    _ChoiceCard(
                      icon: Icons.person_rounded,
                      title: appState.tr('account_type_gig_title'),
                      description: appState.tr('account_type_gig_desc'),
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      accent: primary,
                      isLoading: _isProcessing,
                      onTap: () => _chooseGig(appState),
                    ),
                    const SizedBox(height: 16),
                    _ChoiceCard(
                      icon: Icons.local_shipping_rounded,
                      title: appState.tr('fleet_management'),
                      description: appState.tr('account_type_fleet_desc'),
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      accent: primary,
                      isLoading: false,
                      onTap: _chooseFleet,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
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

  const _ChoiceCard({
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
        onTap: onTap,
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
              if (isLoading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(Icons.chevron_right_rounded, color: subTextColor),
            ],
          ),
        ),
      ),
    );
  }
}
