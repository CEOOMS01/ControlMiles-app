// Olympus Mont Systems LLC - ControlMiles
// lib/screens/reset_password_screen.dart
//
// Paso 2 y 3 del reset de contraseña (pedido explícito): verifica el
// código de 6 dígitos (paso 2, abre sesión de recuperación) y luego fija
// la nueva contraseña (paso 3). El email llega como argumento de la ruta
// (ver AppRoutes.resetPassword en main.dart, mismo patrón que ya usa
// odometerCapture para pasar argumentos sin onGenerateRoute).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();

  bool _codeVerified = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode(AppState appState) async {
    final code = _codeController.text.trim();
    // BUG FIX (pedido explícito): antes exigía exactamente 6 dígitos
    // (maxLength: 6 en el TextField + este check) asumiendo el default
    // documentado de Supabase. El proyecto real manda códigos de 8
    // dígitos -- el TextField los truncaba a 6 y verifyOTP fallaba
    // siempre. No hardcodeamos ningún largo fijo: dejamos que Supabase
    // valide el código tal cual llegó, el cliente solo evita mandar un
    // campo vacío.
    if (code.isEmpty) {
      _showSnack(appState.tr('enter_reset_code'), error: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.verifyPasswordResetCode(widget.email, code);
      if (!mounted) return;
      setState(() => _codeVerified = true);
    } catch (e) {
      if (mounted) _showSnack('${appState.tr('error')}: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode(AppState appState) async {
    setState(() => _isLoading = true);
    try {
      await _authService.requestPasswordReset(widget.email);
      if (mounted) _showSnack(appState.tr('reset_code_sent'));
    } catch (e) {
      if (mounted) _showSnack('${appState.tr('error')}: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitNewPassword(AppState appState) async {
    final pass = _passwordController.text;
    final confirm = _confirmController.text;

    if (pass.isEmpty || pass.length < 6) {
      _showSnack(appState.tr('field_required'), error: true);
      return;
    }
    if (pass != confirm) {
      _showSnack(appState.tr('password_mismatch'), error: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.updatePassword(pass);
      if (!mounted) return;
      _showSnack(appState.tr('reset_password_success'));
      // BUG FIX (implícito): verifyPasswordResetCode dejó una sesión de
      // recuperación activa. Si no la cerramos, el usuario "ya está
      // logueado" con esa sesión de recovery en vez de pasar por
      // LoginScreen normal -- cerramos sesión explícitamente para que el
      // flujo termine siempre en Login, sin importar cómo haya llegado acá.
      await _authService.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.login, (route) => false);
    } catch (e) {
      if (mounted) _showSnack('${appState.tr('error')}: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? Colors.red.shade700 : const Color(0xFF22C55E),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Icon(
                _codeVerified ? Icons.lock_open_rounded : Icons.pin_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                appState.tr('reset_password_title'),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.email,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 30),
              if (!_codeVerified) ..._buildCodeStep(appState, isDark)
              else ..._buildPasswordStep(appState, isDark),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCodeStep(AppState appState, bool isDark) {
    return [
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        // BUG FIX (pedido explícito): sin límite fijo -- ver comentario en
        // _verifyCode(). Distintos proyectos de Supabase pueden mandar
        // códigos de distinto largo (6-10 según su config de OTP), y este
        // truncaba a 6 aunque el email mandara más dígitos.
        maxLength: 12,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 6),
        decoration: InputDecoration(
          counterText: '',
          hintText: appState.tr('reset_code_hint'),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
          ),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : () => _verifyCode(appState),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
              : Text(
                  appState.tr('verify_code').toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: _isLoading ? null : () => _resendCode(appState),
          child: Text(appState.tr('resend_code')),
        ),
      ),
    ];
  }

  List<Widget> _buildPasswordStep(AppState appState, bool isDark) {
    return [
      TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: appState.tr('new_password'),
          prefixIcon: const Icon(Icons.lock_person_rounded),
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
          ),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _confirmController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: appState.tr('confirm_new_password'),
          prefixIcon: const Icon(Icons.lock_person_rounded),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
          ),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : () => _submitNewPassword(appState),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
              : Text(
                  appState.tr('save').toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
        ),
      ),
    ];
  }
}
