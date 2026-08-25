// ================================================================
// Olympus Mont Systems LLC - ControlMiles
// lib/views/welcome_page.dart - VERSIÓN FINAL OPTIMIZADA
// ================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';   // ← IMPORT OBLIGATORIO

import '../logic/app_state.dart';
import '../routes/app_routes.dart';
import '../utils/permission_recovery_service.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _isProcessing = false;
  bool _acceptedTerms = false;

  Future<bool> _requestPermissionsFlow() async {
    final hasPermissions = await PermissionRecoveryService.hasCriticalPermissions();
    if (hasPermissions) return true;

    return await _requestAllPermissions();
  }

  Future<bool> _requestAllPermissions() async {
    var status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      if (status.isPermanentlyDenied) await PermissionRecoveryService.openAppSettings();
      return false;
    }

    status = await Permission.locationAlways.request();
    if (!status.isGranted) {
      if (status.isPermanentlyDenied) await PermissionRecoveryService.openAppSettings();
      return false;
    }

    await Permission.camera.request();
    await Permission.activityRecognition.request();
    await Permission.notification.request();

    return true;
  }

  Future<void> _completeOnboarding(AppState appState) async {
    if (_isProcessing || !_acceptedTerms) return;

    setState(() => _isProcessing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      final permissionsOk = await _requestPermissionsFlow();
      if (!mounted) return;

      if (!permissionsOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appState.tr('permissions_required')),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await _markWelcomeSeen(user.id);
      appState.completePermissionsSetup();
      await appState.fetchAccountTypeChosen();

      if (!mounted) return;
      // Fleet Phase 1: after permissions, a first-time user still needs to
      // pick Gig vs Fleet before landing on either dashboard.
      Navigator.pushReplacementNamed(
        context,
        appState.accountTypeChosen ? AppRoutes.dashboard : AppRoutes.accountType,
      );
    } catch (e) {
      debugPrint('[WelcomePage Error]: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appState.tr('something_went_wrong')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _markWelcomeSeen(String userId) async {
  try {
    await Supabase.instance.client
        .from('user_onboarding')
        .upsert({
          'user_id': userId,
          'welcome_seen': true,
          'welcome_seen_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id');
  } catch (e) {
    debugPrint('[WelcomePage] Warning: Could not mark welcome as seen: $e');
    // No bloqueamos el flujo si falla, solo lo logueamos
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

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              Column(
                children: [
                  Image.asset(
                    'assets/images/logo_olympus.png',
                    height: 70,
                    errorBuilder: (_, __, ___) => Icon(Icons.shield_rounded, size: 60, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    appState.tr('olympus_mont_systems'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appState.tr('secure_audit_programs'),
                    style: TextStyle(fontSize: 12, color: subTextColor),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appState.tr('permissions_required'),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      appState.tr('permissions_description'),
                      style: TextStyle(color: subTextColor),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  children: [
                    _PermissionTile(icon: Icons.location_on, title: appState.tr('location_access'), desc: appState.tr('location_desc')),
                    _PermissionTile(icon: Icons.camera_alt, title: appState.tr('camera'), desc: appState.tr('camera_desc')),
                    _PermissionTile(icon: Icons.directions_walk, title: appState.tr('motion_detection'), desc: appState.tr('motion_desc')),
                    _PermissionTile(icon: Icons.notifications, title: appState.tr('notifications'), desc: appState.tr('notifications_desc')),
                  ],
                ),
              ),

              Row(
                children: [
                  Checkbox(
                    value: _acceptedTerms,
                    onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  Expanded(
                    child: Text(
                      appState.tr('accept_terms'),
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isProcessing || !_acceptedTerms) ? null : () => _completeOnboarding(appState),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          appState.tr('continue').toUpperCase(),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _PermissionTile({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}