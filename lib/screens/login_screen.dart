// Olympus Mont Systems LLC - ControlMiles
// lib/screens/login_screen.dart - PRODUCTION READY + DARK MODE READY

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../logic/app_state.dart';
import '../routes/app_routes.dart';
import '../i18n/app_texts.dart';   // ← Importante: Necesario para AppLanguage

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // BUG FIX (pedido explícito): el signup no pedía nombre real -- signUp()
  // fabricaba uno con el prefijo del email, y ese valor basura terminaba
  // en public.profiles.first_name (fuente del saludo del Dashboard).
  final _firstNameController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isLoginMode = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    super.dispose();
  }

  // ============================================================
  // AUTH LOGIC - ACTUALIZADA PARA TU BASE DE DATOS
  // ============================================================
  Future<void> _handleAuth(AppState appState) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError(appState.tr('field_required'));
      return;
    }

    // BUG FIX (pedido explícito): antes no se validaba nombre porque no
    // existía el campo -- ahora el signup lo requiere, mismo mensaje de
    // validación que ya usa el resto del formulario.
    if (!_isLoginMode && _firstNameController.text.trim().isEmpty) {
      _showError(appState.tr('field_required'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        await _authService.signIn(email, password);
      } else {
        await _authService.signUp(
          email,
          password,
          firstName: _firstNameController.text.trim(),
        );
      }

      if (!mounted) return;

      await appState.loadFromPrefs();
      // BUG FIX (pedido explícito, user ID cruzado entre cuentas): sin
      // esto, un login dentro del mismo proceso de la app (sin reiniciar)
      // seguía mostrando el display_id cacheado de la sesión anterior --
      // fetchUserProfile() solo se llamaba una vez en AppState._init().
      // Acá se refresca contra la DB para la cuenta que acaba de
      // autenticarse, así se pise cualquier valor viejo cacheado.
      await appState.fetchUserProfile();
      await appState.fetchAccountTypeChosen();
      await appState.fetchPendingInvites();

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _showError(appState.tr('auth_error'));
        return;
      }

      // BUG FIX (verificado en DB, 2026-08-24): welcome_seen vive en
      // user_onboarding, NUNCA existió en profiles. Esta consulta apuntaba
      // a la tabla equivocada -- PostgREST rechaza una columna que no
      // existe, el .catchError((_) => null) lo silenciaba, y
      // welcomeResponse siempre terminaba null. Resultado: hasSeenWelcome
      // era SIEMPRE false, así que todo login (no solo el primero)
      // redirigía a /welcome en vez de pasar directo al dashboard real.
      final onboardingResponse = await Supabase.instance.client
          .from('user_onboarding')
          .select('welcome_seen')
          .eq('user_id', user.id)
          .maybeSingle()
          .catchError((_) => null);

      final hasSeenWelcome = onboardingResponse?['welcome_seen'] == true;

      if (!mounted) return;

      // Fleet Phase 2: la decisión de a dónde ir ahora vive en un solo
      // lugar (AppRoutes.getInitialRoute) -- splash_page.dart y
      // welcome_page.dart usan la misma llamada, en vez de cada uno
      // mantener su propia copia del if/else (que fue exactamente lo que
      // dejó a splash_page.dart sin enterarse de cuentas Fleet).
      final targetRoute = AppRoutes.getInitialRoute(
        isAuthenticated: true,
        onboardingCompleted: hasSeenWelcome,
        hasPendingInvites: appState.hasPendingInvites,
        accountTypeChosen: appState.accountTypeChosen,
        isFleetAdmin: appState.isFleetAdmin,
      );
      Navigator.pushReplacementNamed(context, targetRoute);
    } catch (e) {
      if (mounted) {
        _showError(_getErrorMessage(e.toString(), appState));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getErrorMessage(String error, AppState appState) {
    if (error.contains('Invalid login credentials') || error.contains('Invalid credentials')) {
      return appState.tr('invalid_credentials');
    }
    if (error.contains('Email already registered') || error.contains('already exists')) {
      return appState.tr('email_already_exists');
    }
    return '${appState.tr('error')}: ${error.split(' ').take(6).join(' ')}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildHeader(appState, isDark),
                    const SizedBox(height: 40),
                    _buildForm(appState, isDark),
                    if (_isLoginMode) _buildForgotPasswordLink(appState),
                    const SizedBox(height: 24),
                    _buildLoginButton(appState),
                    _buildToggleMode(appState),
                    const SizedBox(height: 60),
                    _buildFooter(appState),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: _buildLanguagePicker(appState),
          ),
        ],
      ),
    );
  }

  // ====================== LANGUAGE PICKER ======================
  Widget _buildLanguagePicker(AppState appState) {
    return PopupMenuButton<AppLanguage>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          appState.currentLanguage.flag,
          style: const TextStyle(fontSize: 20),
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (lang) => appState.setLanguage(lang),
      itemBuilder: (context) => AppLanguage.values.map((lang) {
        return PopupMenuItem<AppLanguage>(
          value: lang,
          child: Row(
            children: [
              Text(lang.flag),
              const SizedBox(width: 10),
              Text(lang.label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ====================== HEADER ======================
  Widget _buildHeader(AppState appState, bool isDark) {
    return Column(
      children: [
        Hero(
          tag: 'logo',
          child: Image.asset(
            'assets/images/logo_controlmiles.png',
            height: 140,
            errorBuilder: (_, _, _) => Icon(
              Icons.shield_rounded,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          appState.tr('app_name'),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            letterSpacing: -1,
          ),
        ),
        Text(
          _isLoginMode
              ? (appState.tr('sign_in')).toUpperCase()
              : (appState.tr('sign_up')).toUpperCase(),
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  // ====================== FORM ======================
  Widget _buildForm(AppState appState, bool isDark) {
    return Column(
      children: [
        // BUG FIX (pedido explícito): campo de nombre real, solo visible
        // en modo registro -- reemplaza el fallback de email.split('@')[0]
        // que se mandaba antes sin que el usuario lo viera ni lo eligiera.
        if (!_isLoginMode) ...[
          TextField(
            controller: _firstNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: appState.tr('name'),
              prefixIcon: const Icon(Icons.person_outline_rounded),
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
        ],
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: appState.tr('email'),
            prefixIcon: const Icon(Icons.alternate_email_rounded),
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
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: appState.tr('password'),
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
      ],
    );
  }

  // ====================== LOGIN BUTTON ======================
  Widget _buildLoginButton(AppState appState) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _handleAuth(appState),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
            : Text(
                _isLoginMode
                    ? (appState.tr('sign_in')).toUpperCase()
                    : (appState.tr('sign_up')).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  // ====================== FORGOT PASSWORD ======================
  // BUG FIX (pedido explícito): la ruta forgotPassword existía en
  // AppRoutes y el string i18n también, pero no había ningún botón que la
  // disparara -- código muerto. Ahora sí navega a ForgotPasswordScreen.
  Widget _buildForgotPasswordLink(AppState appState) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
        child: Text(
          appState.tr('forgot_password'),
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ====================== TOGGLE MODE ======================
  Widget _buildToggleMode(AppState appState) {
    return TextButton(
      onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          _isLoginMode
              ? (appState.tr('signup'))
              : (appState.tr('sign_in')),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ====================== FOOTER ======================
  Widget _buildFooter(AppState appState) {
    return Column(
      children: [
        Text(
          appState.tr('Olympus Mont Systems LLC'),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        Text(
          appState.tr('data_protected_footer'),
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}