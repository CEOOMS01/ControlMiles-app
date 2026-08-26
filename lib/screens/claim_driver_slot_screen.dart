// Olympus Mont Systems LLC - ControlMiles
// lib/screens/claim_driver_slot_screen.dart
//
// Reached when a new user picked "Fleet Driver" on RoleChooserScreen --
// links their brand-new account to a fleet_driver_slots row an admin
// already created (name + CM-D#### on the web dashboard) using the
// one-time code the admin shared. No back button on purpose: this
// screen is reached deterministically right after welcome/permissions
// for that intent, not from AccountTypeScreen, so there's no sensible
// "back" target. "I don't have a code" defaults to a plain individual
// driver instead, mirroring AccountTypeScreen's Gig choice.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../routes/app_routes.dart';
import '../services/organization_service.dart';

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

      // The RPC already promoted profiles.account_type to 'fleet_driver'
      // + default_org_id server-side -- same refresh pattern
      // CreateOrganizationScreen uses after create_organization.
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
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _continueAsIndividual(AppState appState) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await appState.completeAccountTypeChoice();
      await appState.clearPendingIntendedRole();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
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

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
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
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _isProcessing ? null : () => _continueAsIndividual(appState),
                  child: Text(
                    appState.tr('claim_driver_slot_skip'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subTextColor, fontSize: 12.5),
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
