// Olympus Mont Systems LLC - ControlMiles
// lib/screens/pending_invite_screen.dart
//
// Fleet Phase 2: shown whenever AppState.hasPendingInvites is true, ahead
// of the normal account-type/dashboard routing (see
// AppRoutes.getInitialRoute) -- a gig user can receive their first fleet
// invite months after signing up, so this isn't only a first-login screen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../models/organization.dart';
import '../routes/app_routes.dart';
import '../services/organization_service.dart';

class PendingInviteScreen extends StatefulWidget {
  const PendingInviteScreen({super.key});

  @override
  State<PendingInviteScreen> createState() => _PendingInviteScreenState();
}

class _PendingInviteScreenState extends State<PendingInviteScreen> {
  final _organizationService = OrganizationService();
  bool _isProcessing = false;
  String? _error;

  Future<void> _respond(AppState appState, PendingInvite invite, bool accept) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      await _organizationService.respondToInvite(invite.membershipId, accept);
      await appState.refreshAccountType();
      await appState.fetchPendingInvites();

      if (!mounted) return;

      if (appState.hasPendingInvites) {
        // Otra invitación pendiente -- se queda en esta pantalla.
        setState(() => _isProcessing = false);
        return;
      }

      await appState.completeAccountTypeChoice();

      if (!mounted) return;
      final targetRoute = AppRoutes.getInitialRoute(
        isAuthenticated: true,
        onboardingCompleted: true,
        hasPendingInvites: false,
        accountTypeChosen: true,
        isFleetAdmin: appState.isFleetAdmin,
        isFleetDriver: appState.isFleetDriver,
      );
      Navigator.pushReplacementNamed(context, targetRoute);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = '${appState.tr('error')}: ${e.toString()}';
        });
      }
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
    final primary = Theme.of(context).colorScheme.primary;

    final invite = appState.pendingInvites.isNotEmpty ? appState.pendingInvites.first : null;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_shipping_rounded, size: 48, color: primary),
              const SizedBox(height: 20),
              Text(
                appState.tr('fleet_invite_title'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(height: 24),
              if (invite != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Text(
                        invite.organizationName,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appState.tr('fleet_invite_role_driver'),
                        style: TextStyle(fontSize: 12.5, color: subTextColor),
                      ),
                    ],
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
              ],
              const SizedBox(height: 24),
              if (invite != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : () => _respond(appState, invite, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            appState.tr('fleet_invite_accept').toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : () => _respond(appState, invite, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      appState.tr('fleet_invite_decline'),
                      style: TextStyle(fontWeight: FontWeight.bold, color: subTextColor),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
