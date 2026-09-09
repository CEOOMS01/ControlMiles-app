// Olympus Mont Systems LLC - ControlMiles
// lib/screens/invite_landing_screen.dart
//
// Fleet Sprint 1 close (2026-09-09): reached when the app opens via the
// https://controlmiles.com/invite/<token> deep link (see AndroidManifest.xml's
// App Links intent-filter + main.dart's AppLinks listener), or via
// Navigator.pushNamed(AppRoutes.inviteLanding, arguments: token) directly.
// Calls resolve_driver_invite (public RPC, no auth needed) and branches
// exactly per the approved spec:
//   Case A -- account_exists=false: minimal signup (name + password), then
//     accept_driver_invite(token) in the same flow.
//   Case B -- account_exists=true: if the current session already matches
//     the invited email, a one-tap confirm; otherwise a login form (email
//     locked to the invited address) before the same accept call.
// accept_driver_invite is the single atomic RPC for both cases (see
// migration 20260904060000_driver_invites.sql) -- by the time it's called
// the caller is authenticated either way, so there's nothing left to
// branch on beyond "do we already have a session for this email".

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/app_state.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';

class InviteLandingScreen extends StatefulWidget {
  final String token;

  const InviteLandingScreen({super.key, required this.token});

  @override
  State<InviteLandingScreen> createState() => _InviteLandingScreenState();
}

enum _InviteLoadState { loading, invalid, ready }

class _InviteLandingScreenState extends State<InviteLandingScreen> {
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  _InviteLoadState _loadState = _InviteLoadState.loading;
  String? _orgName;
  String? _invitedEmail;
  bool _accountExists = false;
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    try {
      final result = await Supabase.instance.client
          .rpc('resolve_driver_invite', params: {'p_token': widget.token})
          .single();

      if (result['valid'] != true) {
        setState(() => _loadState = _InviteLoadState.invalid);
        return;
      }

      setState(() {
        _orgName = result['organization_name'] as String?;
        _invitedEmail = result['email'] as String?;
        _accountExists = result['account_exists'] == true;
        _loadState = _InviteLoadState.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _loadState = _InviteLoadState.invalid);
    }
  }

  bool get _sessionMatchesInvite {
    final currentEmail = Supabase.instance.client.auth.currentUser?.email;
    return currentEmail != null &&
        _invitedEmail != null &&
        currentEmail.toLowerCase() == _invitedEmail!.toLowerCase();
  }

  Future<void> _accept(AppState appState) async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      await Supabase.instance.client
          .rpc('accept_driver_invite', params: {'p_token': widget.token});

      // Server-side already promoted account_type/default_org_id/
      // organization_members atomically -- same refresh pattern
      // ClaimDriverSlotScreen/CreateOrganizationScreen already use.
      await appState.refreshAccountType();
      await appState.completeAccountTypeChoice();
      await appState.clearPendingIntendedRole();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.driverOperations,
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _signupThenAccept(AppState appState) async {
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    if (name.isEmpty || password.isEmpty) {
      setState(() => _error = appState.tr('field_required'));
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final parts = name.split(RegExp(r'\s+'));
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      await _authService.signUp(
        _invitedEmail!,
        password,
        firstName: firstName,
        lastName: lastName,
      );

      // A project with "Confirm email" on returns no active session from
      // signUp() until the link is clicked -- accept_driver_invite needs
      // auth.uid(), so there's genuinely nothing more to do here yet in
      // that case. Detected rather than assumed either way.
      if (Supabase.instance.client.auth.currentSession == null) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _error = appState.tr('invite_confirm_email_first');
          });
        }
        return;
      }

      await _accept(appState);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loginThenAccept(AppState appState) async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = appState.tr('field_required'));
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      await _authService.signIn(_invitedEmail!, password);
      await _accept(appState);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = e.toString().replaceFirst('Exception: ', '');
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

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Image.asset(
                  'assets/images/logo_controlmiles.png',
                  height: 64,
                  errorBuilder: (_, _, _) =>
                      Icon(Icons.local_shipping_rounded, size: 56, color: primary),
                ),
              ),
              const SizedBox(height: 24),
              if (_loadState == _InviteLoadState.loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_loadState == _InviteLoadState.invalid)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link_off_rounded, size: 40, color: subTextColor),
                        const SizedBox(height: 16),
                        Text(
                          appState.tr('invite_invalid_title'),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          appState.tr('invite_invalid_body'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: subTextColor),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Icon(Icons.badge_rounded, size: 40, color: primary),
                const SizedBox(height: 16),
                Text(
                  appState.tr('invite_landing_title').replaceFirst('{org}', _orgName ?? ''),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
                ),
                const SizedBox(height: 6),
                Text(
                  _invitedEmail ?? '',
                  style: TextStyle(fontSize: 13, color: subTextColor),
                ),
                const SizedBox(height: 28),

                if (_accountExists && _sessionMatchesInvite) ...[
                  // Case B, matching session: one-tap confirm.
                  Text(
                    appState.tr('invite_confirm_body').replaceFirst('{org}', _orgName ?? ''),
                    style: TextStyle(fontSize: 14, color: textColor),
                  ),
                ] else if (_accountExists) ...[
                  // Case B, no session or a different one: log in as the
                  // invited email first.
                  Text(
                    appState.tr('invite_login_prompt'),
                    style: TextStyle(fontSize: 13, color: subTextColor),
                  ),
                  const SizedBox(height: 16),
                  _passwordField(appState, cardColor, borderColor, primary),
                ] else ...[
                  // Case A: no account yet -- minimal signup.
                  Text(
                    appState.tr('invite_signup_prompt'),
                    style: TextStyle(fontSize: 13, color: subTextColor),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    enabled: !_isProcessing,
                    decoration: InputDecoration(
                      labelText: appState.tr('name'),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _passwordField(appState, cardColor, borderColor, primary),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () {
                            if (_accountExists && _sessionMatchesInvite) {
                              _accept(appState);
                            } else if (_accountExists) {
                              _loginThenAccept(appState);
                            } else {
                              _signupThenAccept(appState);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            appState.tr('invite_accept_button').toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _passwordField(AppState appState, Color cardColor, Color borderColor, Color primary) {
    return TextField(
      controller: _passwordController,
      enabled: !_isProcessing,
      obscureText: true,
      decoration: InputDecoration(
        labelText: appState.tr('password'),
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
    );
  }
}
