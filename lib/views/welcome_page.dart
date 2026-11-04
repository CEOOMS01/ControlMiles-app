// ================================================================
// Olympus Mont Systems LLC - ControlMiles
// lib/views/welcome_page.dart
//
// First-time onboarding (2026-11-04, explicit request: "like MileIQ"): there
// is no screen or checkbox of its own any more. Right after signing in, the
// driver lands on the permission steps, one at a time. The 18+ / Terms
// acceptance is the sentence under the first Allow button and is recorded
// server-side when that button is tapped. Camera is not asked here: it is asked
// when the first odometer photo is needed.
// ================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../legal/legal_documents.dart';
import '../logic/app_state.dart';
import '../routes/app_routes.dart';
import 'permissions_flow_screen.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _isProcessing = false;
  bool _termsRecorded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _completeOnboarding(context.read<AppState>());
    });
  }

  /// Records the 18+ and Terms/Privacy acceptance as server-side evidence
  /// (2026-09-29): every account passes through here -- email sign-up, Google,
  /// fleet drivers alike. Runs once.
  Future<void> _recordAcceptance() async {
    if (_termsRecorded) return;
    _termsRecorded = true;
    try {
      await Supabase.instance.client.rpc('accept_legal_terms', params: {'p_version': legalTermsVersion});
    } catch (e) {
      debugPrint('[Welcome] recording legal acceptance failed: $e');
    }
  }

  Future<void> _completeOnboarding(AppState appState) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      final done = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PermissionsFlowScreen(includeCamera: false, onAccept: _recordAcceptance),
        ),
      );
      if (!mounted) return;

      if (done != true) {
        // Not reachable by design (the screen cannot be dismissed); the retry
        // button below is the way back in if it ever happens.
        setState(() => _isProcessing = false);
        return;
      }

      // Every step was already working, so the sentence was never shown: the
      // account is still recorded as accepted.
      await _recordAcceptance();
      await _markWelcomeSeen(user.id);
      appState.completePermissionsSetup();
      await appState.fetchAccountTypeChosen();

      if (!mounted) return;

      // Fleet Phase 2: same centralized routing decision as
      // login_screen.dart/splash_page.dart -- a first-time user might
      // already have a pending fleet invite waiting (sent while they were
      // still finishing permissions setup).
      final targetRoute = AppRoutes.getInitialRoute(
        isAuthenticated: true,
        onboardingCompleted: true,
      );
      Navigator.pushReplacementNamed(context, targetRoute);
    } catch (e) {
      debugPrint('[WelcomePage Error]: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appState.tr('something_went_wrong')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markWelcomeSeen(String userId) async {
    try {
      await Supabase.instance.client.from('user_onboarding').upsert({
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
    final bgColor = isDark ? const Color(0xFF12100C) : const Color(0xFFFAF6EE);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: _isProcessing
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _completeOnboarding(appState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      appState.tr('continue').toUpperCase(),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
