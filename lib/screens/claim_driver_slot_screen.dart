// Olympus Mont Systems LLC - ControlMiles
// lib/screens/claim_driver_slot_screen.dart
//
// ControlMiles Fleet home for an account that belongs to no fleet yet
// (AppRoutes.getInitialRoute): links it to a fleet_driver_slots row an
// admin already created (name + CM-D#### on the web dashboard) using the
// one-time code the admin shared. Owners and admins are pointed to
// controlmiles.com, where fleets are created and managed (Gig / Fleet
// split, 2026-10-11 -- there is no "continue as an individual" here any
// more: personal miles live in the ControlMiles app).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/app_state.dart';
import '../routes/app_routes.dart';
import '../services/organization_service.dart';
import '../errors/app_error.dart';

class ClaimDriverSlotScreen extends StatefulWidget {
  const ClaimDriverSlotScreen({super.key});

  @override
  State<ClaimDriverSlotScreen> createState() => _ClaimDriverSlotScreenState();
}

class _ClaimDriverSlotScreenState extends State<ClaimDriverSlotScreen> {
  final _codeController = TextEditingController();
  final _organizationService = OrganizationService();
  bool _isProcessing = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _claim(AppState appState) async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = appState.tr('field_required'));
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      await _organizationService.claimDriverSlot(code);

      // Picks up the new membership (role 'driver') for this app.
      await appState.refreshAccountType();
      await appState.completeAccountTypeChoice();
      await appState.clearPendingIntendedRole();

      if (!mounted) return;
      // Fleet_driver now lands on its own dedicated operations screen,
      // not the shared `dashboard` -- see DriverOperationsScreen's header
      // comment for why (this reverses the earlier Phase 3 decision).
      Navigator.pushReplacementNamed(context, AppRoutes.driverOperations);
    } catch (e) {
      if (mounted) {
        final appError = AppError.from(e);
        setState(() => _error = appError.display(appState.tr(appError.messageKey)));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _signOut(AppState appState) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await appState.signOutAndClear();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF12100C) : const Color(0xFFFAF6EE);
    final cardColor = isDark ? const Color(0xFF1C1812) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF6B6250);
    final borderColor = isDark ? const Color(0xFF2E281F) : const Color(0xFFE3D9C4);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Icon(Icons.badge_rounded, size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                appState.tr('claim_driver_slot_title'),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(height: 6),
              Text(
                appState.tr('claim_driver_slot_subtitle'),
                style: TextStyle(fontSize: 13, color: subTextColor),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                enabled: !_isProcessing,
                style: const TextStyle(letterSpacing: 3, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: appState.tr('claim_driver_slot_code_label'),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () => _claim(appState),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          appState.tr('claim_driver_slot_button').toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appState.tr('fleet_join_owner_hint'),
                      style: TextStyle(color: textColor, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse('https://controlmiles.com/login'),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(appState.tr('fleet_join_open_web')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _isProcessing ? null : () => _signOut(appState),
                  child: Text(
                    appState.tr('sign_out'),
                    style: TextStyle(color: subTextColor, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
