// Olympus Mont Systems LLC - ControlMiles
// lib/screens/login_screen.dart - PRODUCTION READY + DARK MODE READY

import 'package:flutter/gestures.dart';
import '../services/login_prefs.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_flavor.dart';

import '../services/auth_service.dart';
import '../logic/app_state.dart';
import '../routes/app_routes.dart';
import '../errors/app_error.dart';
import '../i18n/app_texts.dart';   // ← Importante: Necesario para AppLanguage
import '../legal/legal_documents.dart';
import 'legal_document_screen.dart';

class LoginScreen extends StatefulWidget {
  // Set by RoleChooserScreen so a brand-new user lands directly on the
  // signup form instead of needing an extra tap on "Sign up" -- the
  // chooser already told us their intent.
  final bool startInSignupMode;

  // Set by RoleChooserScreen's "Fleet Driver" card (explicit user
  // request, 2026-09-17): a driver never self-signs-up anymore -- their
  // admin already created their invite, so this card's job now is
  // getting them straight to the driver-ID login tab, not a signup form.
  final bool startInDriverIdMode;

  const LoginScreen({super.key, this.startInSignupMode = false, this.startInDriverIdMode = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // Fleet driver ID login (explicit user request, 2026-09-17): a
  // fleet_driver account no longer logs in with email/password at all --
  // only this ID + the password THEY chose when confirming their invite
  // (never set/known by their admin, see resolve-driver-login's own
  // header comment). Everyone else (gig drivers, fleet admins) keeps the
  // existing email login untouched -- this is a second, driver-only input
  // mode on the SAME shared screen, not a separate screen, so it stays
  // reachable from every existing entry point (splash, "forgot password"
  // back-link, role chooser) without duplicating this whole form.
  final _driverIdController = TextEditingController();
  bool _isDriverIdMode = false;
  // BUG FIX (pedido explícito): el signup no pedía nombre real -- signUp()
  // fabricaba uno con el prefijo del email, y ese valor basura terminaba
  // en public.profiles.first_name (fuente del saludo del Dashboard).
  final _firstNameController = TextEditingController();
  // BUG FIX (pedido explícito): last_name/full_name existen en
  // public.profiles desde antes -- profile_screen.dart ya los edita y
  // reports_screen.dart ya los lee para el nombre legal del PDF -- pero el
  // registro nunca los pedía, así que se quedaban vacíos hasta que el
  // usuario visitara Profile a mano. Se piden los dos ahora, mismo
  // patrón/labels que profile_screen.dart (tr('name') + tr('last_name')).
  final _lastNameController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  late bool _isLoginMode;
  bool _obscurePassword = true;
  // Explicit user requirement (legal risk mitigation, 2026-08-27): the
  // Terms of Service already state a minimum age of 18, but nothing
  // enforced it -- researched how real competitor mileage apps (MileIQ,
  // TripLog, Everlance) handle this before building: none of them
  // collect an actual date of birth, all use a self-attestation checkbox
  // instead. Same pattern here, combined with explicit ToS/Privacy
  // agreement in one checkbox rather than two separate ones.
  bool _agreedToTerms = false;

  // "Remember my email" / "Stay signed in" (2026-09-29) -- see
  // LoginPrefs' header for the researched rules (identifier only, never
  // the password; staying signed in is on by default on the phone because
  // background tracking and auto-detect need a live session).
  bool _rememberId = false;
  // Header wording: "Welcome back" only for a returning user; "Check your
  // email" right after a sign-up; "Sign in" otherwise.
  bool _hasSignedInBefore = false;
  bool _justSignedUp = false;
  bool _staySignedIn = true;

  @override
  void initState() {
    super.initState();
    // Gig / Fleet split (2026-10-11): the Fleet app has no self sign-up
    // (owners sign up on controlmiles.com, drivers get a code) and opens
    // on the driver-ID tab; the gig app is email / Google only.
    _isLoginMode = AppFlavor.isFleet || !widget.startInSignupMode;
    _isDriverIdMode = AppFlavor.isFleet || widget.startInDriverIdMode;
    _loadLoginPrefs();
  }

  Future<void> _loadLoginPrefs() async {
    final prefs = await LoginPrefs.load();
    final hasSignedInBefore = await LoginPrefs.hasSignedInBefore();
    if (!mounted) return;
    setState(() {
      _hasSignedInBefore = hasSignedInBefore;
      _rememberId = prefs.remember;
      _staySignedIn = prefs.staySignedIn;
      if (prefs.remember) {
        if (prefs.email != null && _emailController.text.isEmpty) {
          _emailController.text = prefs.email!;
        }
        final id = prefs.driverId;
        if (id != null && _driverIdController.text.isEmpty) {
          _driverIdController.text = id.replaceFirst(RegExp('^CM-', caseSensitive: false), '');
        }
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _driverIdController.dispose();
    super.dispose();
  }

  static final RegExp _emailFormat = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool _isValidEmailFormat(String email) => _emailFormat.hasMatch(email);

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

    // BUG FIX (pre-launch security audit): there was no email format
    // validation at all on either login or signup -- 'invalid_email' was
    // already translated in every i18n file but never actually wired to
    // any check. Same regex used server-side in create_driver_invite, for
    // consistency across the project.
    if (!_isValidEmailFormat(email)) {
      _showError(appState.tr('invalid_email'));
      return;
    }

    // BUG FIX (pedido explícito): antes no se validaba nombre porque no
    // existía el campo -- ahora el signup lo requiere, mismo mensaje de
    // validación que ya usa el resto del formulario. Apellido ahora exigido
    // igual que el nombre -- mismo motivo (full_name para reportes/PDF).
    if (!_isLoginMode &&
        (_firstNameController.text.trim().isEmpty ||
            _lastNameController.text.trim().isEmpty)) {
      _showError(appState.tr('field_required'));
      return;
    }

    // Security hardening (explicit user request, 2026-09-08): signup only
    // -- login must keep accepting whatever password an existing account
    // already has, even one shorter than this floor. UX-layer only; the
    // real floor is Supabase Auth's own server-side minimum, which this
    // client-side check can't see or enforce (verify/raise it in the
    // Supabase Dashboard to match, under Authentication -> Policies).
    if (!_isLoginMode && password.length < 8) {
      _showError(appState.tr('password_too_short'));
      return;
    }

    // BUG FIX (pre-launch security audit): length was the only rule --
    // "password"/"12345678" both passed. Light complexity floor (needs at
    // least one letter AND one digit), still UX-layer only same as the
    // length check above.
    if (!_isLoginMode &&
        !(RegExp(r'[A-Za-z]').hasMatch(password) && RegExp(r'[0-9]').hasMatch(password))) {
      _showError(appState.tr('password_too_weak'));
      return;
    }

    if (!_isLoginMode && !_agreedToTerms) {
      _showError(appState.tr('age_terms_required_error'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        await _authService.signIn(email, password);

        // BUG FIX (found live, 2026-09-18): the driver/email mode toggle
        // above was only ever a UI default -- nothing stopped a plain
        // 'driver' from just picking the Email tab and signing in with
        // their real email/password anyway, which is exactly what the
        // explicit user request ("eliminamos el login por correo para
        // los driver fleet only") was supposed to prevent. Checked here,
        // not server-side: this is a UX/process guardrail, not a
        // security boundary -- a driver who got in this way ends up with
        // the exact same RLS-scoped session (same auth.uid(), same
        // organization_members.member_role) as if they'd used the
        // correct Driver ID tab, so there's no extra access to gate at
        // the RLS layer, only the login PATH to correct. Scoped to
        // member_role == 'driver' specifically -- operator/admin/owner
        // still need email (they use the web dashboard too), only the
        // base driver tier is ID-only.
        // Gig / Fleet split: only the Fleet app enforces this -- in the gig
        // app the same person signs in with email for their personal miles.
        final justSignedIn = Supabase.instance.client.auth.currentUser;
        if (justSignedIn != null && AppFlavor.isFleet) {
          final memberRows = await Supabase.instance.client
              .from('organization_members')
              .select('member_role')
              .eq('user_id', justSignedIn.id)
              .eq('is_active', true);
          final roles = {
            for (final r in memberRows as List) r['member_role'] as String?,
          };
          if (roles.contains('driver') &&
              !roles.any((r) => r == 'owner' || r == 'admin' || r == 'operator')) {
            await Supabase.instance.client.auth.signOut();
            if (!mounted) return;
            setState(() => _isLoading = false);
            _showError(appState.tr('fleet_driver_must_use_id_login'));
            return;
          }
        }
      } else {
        await _authService.signUp(
          email,
          password,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
        );
        // Found live (2026-10-08): with email confirmation on, signUp
        // returns no session, and _afterSuccessfulAuth then showed
        // "Authentication error" although the account was created and the
        // confirmation email sent. Go to the sign-in form instead (user
        // request), email kept, with a "check your email" message.
        if (Supabase.instance.client.auth.currentSession == null) {
          if (!mounted) return;
          setState(() {
            _isLoginMode = true;
            _isDriverIdMode = false;
            _justSignedUp = true;
            _passwordController.clear();
          });
          _showInfo(appState.tr('signup_check_email'));
          return;
        }
      }

      if (!mounted) return;
      await _afterSuccessfulAuth(appState);
    } catch (e) {
      // BUG FIX (pedido explícito, 2026-09-09): esta rama antes mostraba
      // texto crudo de la excepción/base de datos al usuario (primeras 6
      // palabras del error real) cuando no coincidía con los dos casos
      // conocidos. Ahora usa el registro central de errores -- nunca
      // texto crudo, siempre un mensaje traducido + código estable
      // (AppError.from ya reconoce credenciales inválidas/email
      // duplicado; cualquier otra cosa cae en el código 701 genérico).
      if (mounted) {
        final appError = AppError.from(e);
        _showError(appError.display(appState.tr(appError.messageKey)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fleet driver ID login (explicit user request, 2026-09-17): same
  // post-auth routing as _handleAuth (loadFromPrefs/fetchUserProfile/
  // welcome-seen check/AppRoutes.getInitialRoute) once a real session
  // exists -- factored out here so both entry points share it instead of
  // duplicating it, since the sign-in call itself is the only thing that
  // actually differs between the two modes.
  Future<void> _handleDriverIdAuth(AppState appState) async {
    final digits = _driverIdController.text.trim();
    final password = _passwordController.text.trim();

    if (digits.isEmpty || password.isEmpty) {
      _showError(appState.tr('field_required'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signInWithDriverId('CM-$digits'.toUpperCase(), password);
      if (!mounted) return;
      await _afterSuccessfulAuth(appState);
    } catch (e) {
      if (mounted) {
        final appError = AppError.from(e);
        _showError(appError.display(appState.tr(appError.messageKey)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _afterSuccessfulAuth(AppState appState) async {
    if (Supabase.instance.client.auth.currentSession != null) {
      await LoginPrefs.markSignedIn();
    }
    if (!_isLoginMode && Supabase.instance.client.auth.currentSession != null) {
      try {
        await Supabase.instance.client
            .rpc('accept_legal_terms', params: {'p_version': legalTermsVersion});
      } catch (e) {
        debugPrint('[Login] recording legal acceptance failed: $e');
      }
    }
    if (_isLoginMode) {
      await LoginPrefs.saveAfterSignIn(
        remember: _rememberId,
        email: _isDriverIdMode ? null : _emailController.text.trim(),
        driverId: _isDriverIdMode ? _driverIdController.text.trim() : null,
        staySignedIn: _staySignedIn,
      );
    }
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
      // BUG FIX (missing key, hardcoded-string audit): 'auth_error' was
      // referenced here but never added to any i18n dictionary -- tr()
      // silently rendered the raw key string. Now added to all 11.
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
      isFleetDriver: appState.isFleetDriver,
    );
    Navigator.pushReplacementNamed(context, targetRoute);
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 8),
      ),
    );
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

  // ====================== GOOGLE ======================
  Future<void> _handleGoogle(AppState appState) async {
    setState(() => _isLoading = true);
    try {
      final signedIn = await _authService.signInWithGoogle();
      if (!signedIn || !mounted) return;
      await _afterSuccessfulAuth(appState);
    } catch (e) {
      debugPrint('[Login] Google sign-in failed: $e');
      if (mounted) _showError(appState.tr('google_sign_in_failed'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _submit(AppState appState) {
    if (_isLoading) return;
    if (_isLoginMode && _isDriverIdMode) {
      _handleDriverIdAuth(appState);
    } else {
      _handleAuth(appState);
    }
  }

  // ====================== LAYOUT ======================
  // Redesign (2026-09-29, explicit user request "más fluido, menos soso"),
  // after researching login/sign-up best practices (Authgear 2025 guide,
  // Eleken, Cieden): social sign-in first, as few fields as possible,
  // show-password toggle, autofill hints for password managers, errors that
  // keep what was typed and offer a way out, sentence-case actions, a clear
  // switch between sign-in and sign-up, and a busy state on the button.
  // All auth logic above is unchanged.
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1C1812) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12100C) : const Color(0xFF0F2A44),
      body: Stack(
        children: [
          // Brand backdrop: navy gradient + the same soft route curve the
          // website's hero uses, so the app and controlmiles.com feel like
          // one product.
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F2A44), Color(0xFF1F5F8B)],
                ),
              ),
              child: CustomPaint(painter: _RouteCurvePainter()),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        _buildHero(appState),
                        const SizedBox(height: 20),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                              boxShadow: const [
                                BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, -4)),
                              ],
                            ),
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                transitionBuilder: (child, anim) => FadeTransition(
                                  opacity: anim,
                                  child: SlideTransition(
                                    position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
                                        .animate(anim),
                                    child: child,
                                  ),
                                ),
                                child: KeyedSubtree(
                                  key: ValueKey('$_isLoginMode-$_isDriverIdMode'),
                                  child: _buildCardContent(appState, isDark),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(top: 40, right: 16, child: _buildLanguagePicker(appState)),
        ],
      ),
    );
  }

  Widget _buildHero(AppState appState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      child: Column(
        children: [
          Hero(
            tag: 'logo',
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Image.asset(
                AppFlavor.isFleet
                    ? 'assets/images/logo_controlmiles_fleet.png'
                    : 'assets/images/logo_controlmiles.png',
                height: 56,
                errorBuilder: (_, _, _) => const Icon(Icons.route_rounded, size: 56, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Fleet app: "ControlMiles" + a black "Fleet" on a cream tag, on one
          // line (owner's request, 2026-10-11); the tag keeps it readable on
          // the dark header.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  appState.tr('app_name'),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.8),
                ),
                if (AppFlavor.isFleet) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF6EE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Fleet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            appState.tr(AppFlavor.isFleet ? 'login_tagline_fleet' : 'login_tagline'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent(AppState appState, bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1812);
    final subColor = isDark ? Colors.white60 : const Color(0xFF6B6250);
    final showGoogle = !(_isLoginMode && _isDriverIdMode);

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            appState.tr(!_isLoginMode
                ? 'login_create_account_title'
                : _justSignedUp
                    ? 'signup_confirm_title'
                    : _hasSignedInBefore
                        ? 'login_welcome_back'
                        : 'login_sign_in_title'),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: titleColor),
          ),
          const SizedBox(height: 4),
          Text(
            appState.tr(!_isLoginMode
                ? 'login_create_account_sub'
                : _justSignedUp
                    ? 'signup_check_email'
                    : AppFlavor.isFleet
                        ? (_isDriverIdMode ? 'fleet_sign_in_sub_driver' : 'fleet_sign_in_sub_admin')
                        : _hasSignedInBefore
                            ? 'login_welcome_back_sub'
                            : 'login_sign_in_sub'),
            style: TextStyle(fontSize: 13.5, color: subColor),
          ),
          const SizedBox(height: 20),
          if (showGoogle) ...[
            _buildGoogleButton(appState, isDark),
            const SizedBox(height: 16),
            _buildOrDivider(appState, isDark),
            const SizedBox(height: 16),
          ],
          _buildForm(appState, isDark),
          const SizedBox(height: 8),
          if (_isLoginMode) _buildLoginOptions(appState, isDark) else _buildAgeTermsCheckbox(appState, isDark),
          const SizedBox(height: 16),
          _buildLoginButton(appState),
          const SizedBox(height: 8),
          if (AppFlavor.isGig) _buildToggleMode(appState, isDark),
          const SizedBox(height: 8),
          _buildOtherAppHint(appState, isDark),
          const SizedBox(height: 8),
          _buildFooter(appState),
        ],
      ),
    );
  }

  // ====================== LANGUAGE PICKER ======================
  Widget _buildLanguagePicker(AppState appState) {
    return PopupMenuButton<AppLanguage>(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(appState.currentLanguage.flag, style: const TextStyle(fontSize: 18)),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (lang) => appState.setLanguage(lang),
      itemBuilder: (context) => AppLanguage.values
          .map((lang) => PopupMenuItem<AppLanguage>(
                value: lang,
                child: Row(
                  children: [
                    Text(lang.flag),
                    const SizedBox(width: 10),
                    Text(lang.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  // ====================== GOOGLE BUTTON ======================
  Widget _buildGoogleButton(AppState appState, bool isDark) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: _isLoading ? null : () => _handleGoogle(appState),
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF2E281F) : Colors.white,
          side: BorderSide(color: isDark ? const Color(0xFF3D352A) : const Color(0xFFDADCE0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GoogleGPainter())),
            const SizedBox(width: 12),
            Text(
              appState.tr('continue_with_google'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1F1F1F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrDivider(AppState appState, bool isDark) {
    final lineColor = isDark ? const Color(0xFF3D352A) : const Color(0xFFE3D9C4);
    return Row(
      children: [
        Expanded(child: Divider(color: lineColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            appState.tr('or_divider'),
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFFA39A86)),
          ),
        ),
        Expanded(child: Divider(color: lineColor)),
      ],
    );
  }

  // ====================== FORM ======================
  InputDecoration _decoration(bool isDark, String label, IconData icon, {Widget? suffix, String? prefixText, String? hint}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: isDark ? const Color(0xFF3D352A) : const Color(0xFFE3D9C4)),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: isDark ? const Color(0xFF2E281F) : const Color(0xFFFAF6EE),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
    );
  }

  Widget _buildForm(AppState appState, bool isDark) {
    return Column(
      children: [
        // Real name, sign-up only (replaces the old email.split('@') guess).
        if (!_isLoginMode) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.givenName],
                  decoration: _decoration(isDark, appState.tr('name'), Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.familyName],
                  decoration: _decoration(isDark, appState.tr('last_name'), Icons.person_outline_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (_isLoginMode && _isDriverIdMode)
          TextField(
            controller: _driverIdController,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            // "CM-" is fixed: drivers only type the part their admin gave them.
            decoration: _decoration(isDark, appState.tr('driver_id_label'), Icons.badge_outlined,
                prefixText: 'CM-', hint: 'D1234'),
          )
        else
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            decoration: _decoration(isDark, appState.tr('email'), Icons.alternate_email_rounded),
          ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          autofillHints: [_isLoginMode ? AutofillHints.password : AutofillHints.newPassword],
          onSubmitted: (_) => _submit(appState),
          decoration: _decoration(
            isDark,
            appState.tr('password'),
            Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
      ],
    );
  }

  // ====================== LOGIN OPTIONS ======================
  // "Remember my email" + "Forgot password?" share one row; "Stay signed in"
  // gets its own row with the reason (see LoginPrefs).
  Widget _buildLoginOptions(AppState appState, bool isDark) {
    final textColor = isDark ? Colors.white70 : const Color(0xFF574F40);
    final hintColor = isDark ? Colors.white54 : const Color(0xFF6B6250);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _rememberId = !_rememberId),
                child: Row(
                  children: [
                    Checkbox(
                      value: _rememberId,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => setState(() => _rememberId = v ?? false),
                    ),
                    Flexible(
                      child: Text(
                        appState.tr(_isDriverIdMode ? 'remember_my_driver_id' : 'remember_my_email'),
                        style: TextStyle(fontSize: 13, color: textColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Drivers too: their account has the email they registered with,
            // and the reset goes there.
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
              child: Text(appState.tr('forgot_password'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _staySignedIn = !_staySignedIn),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _staySignedIn,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => setState(() => _staySignedIn = v ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(appState.tr('stay_signed_in'), style: TextStyle(fontSize: 13, color: textColor)),
                      const SizedBox(height: 2),
                      Text(appState.tr(AppFlavor.isFleet ? 'stay_signed_in_hint_fleet' : 'stay_signed_in_hint'),
                          style: TextStyle(fontSize: 11.5, height: 1.35, color: hintColor)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ====================== AGE + TERMS CHECKBOX ======================
  // Explicit user requirement (legal risk mitigation, 2026-08-27):
  // required before signup -- 18+ self-attestation + Terms/Privacy.
  Widget _buildAgeTermsCheckbox(AppState appState, bool isDark) {
    final textColor = isDark ? Colors.white70 : const Color(0xFF574F40);
    final linkColor = Theme.of(context).colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _agreedToTerms,
          visualDensity: VisualDensity.compact,
          onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12.5, height: 1.4, color: textColor),
                children: [
                  TextSpan(text: '${appState.tr('age_terms_checkbox_prefix')} '),
                  TextSpan(
                    text: appState.tr('terms_conditions'),
                    style: TextStyle(color: linkColor, fontWeight: FontWeight.w700),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalDocumentScreen(
                                titleKey: 'terms_conditions',
                                body: termsOfServiceEn,
                              ),
                            ),
                          ),
                  ),
                  TextSpan(text: ' ${appState.tr('age_terms_checkbox_and')} '),
                  TextSpan(
                    text: appState.tr('privacy_policy'),
                    style: TextStyle(color: linkColor, fontWeight: FontWeight.w700),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalDocumentScreen(
                                titleKey: 'privacy_policy',
                                body: privacyPolicyEn,
                              ),
                            ),
                          ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ====================== PRIMARY BUTTON ======================
  Widget _buildLoginButton(AppState appState) {
    final label = appState.tr(_isLoginMode ? 'sign_in' : 'create_account');
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: _isLoading ? null : () => _submit(appState),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: _isLoading
              ? const SizedBox(
                  key: ValueKey('busy'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Text(label, key: ValueKey(label)),
        ),
      ),
    );
  }

  // ====================== OTHER APP HINT ======================
  // Gig: "drive for a fleet? get ControlMiles Fleet". Fleet: every driver
  // and bus monitor signs in with their CM-D ID (the email is only used to
  // register, user rule 2026-10-11); owners and admins get a small "sign in
  // with email" link, and create / manage their fleet on controlmiles.com.
  Widget _buildOtherAppHint(AppState appState, bool isDark) {
    final muted = isDark ? Colors.white60 : const Color(0xFF6B6250);
    final isFleet = AppFlavor.isFleet;
    if (!isFleet && !AppFlavor.fleetAppOnPlay) return const SizedBox.shrink();
    return Column(
      children: [
        if (isFleet)
          TextButton(
            onPressed: _isLoading
                ? null
                : () => setState(() => _isDriverIdMode = !_isDriverIdMode),
            child: Text(appState.tr(
                _isDriverIdMode ? 'fleet_admin_email_login' : 'fleet_driver_id_login')),
          ),
        Text(
          appState.tr(isFleet ? 'fleet_join_owner_hint' : 'gig_fleet_app_hint'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: muted),
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse(isFleet ? 'https://controlmiles.com/signup' : AppFlavor.fleetStoreUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: Text(appState.tr(isFleet ? 'fleet_join_open_web' : 'get_fleet_app')),
        ),
      ],
    );
  }

  // ====================== SIGN-IN / SIGN-UP SWITCH ======================
  Widget _buildToggleMode(AppState appState, bool isDark) {
    final muted = isDark ? Colors.white60 : const Color(0xFF6B6250);
    return Center(
      child: TextButton(
        onPressed: _isLoading
            ? null
            : () => setState(() {
                  _isLoginMode = !_isLoginMode;
                  _justSignedUp = false;
                  if (!_isLoginMode) _isDriverIdMode = false;
                }),
        child: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 13.5, color: muted),
            children: [
              TextSpan(text: '${appState.tr(_isLoginMode ? 'no_account_prompt' : 'have_account_prompt')} '),
              TextSpan(
                text: appState.tr(_isLoginMode ? 'create_account' : 'sign_in'),
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================== FOOTER ======================
  Widget _buildFooter(AppState appState) {
    // One line, trade name (owner's request, 2026-10-11): Olimsys
    // Development is Olympus Mont Systems LLC's brand; the legal name stays
    // in Settings > About and the legal documents.
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 11, color: Colors.grey),
        children: [
          TextSpan(text: '${appState.tr('powered_by_footer')} '),
          const TextSpan(
            text: 'Olimsys Development',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.3),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _RouteCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final h = size.height * 0.28;
    final path = Path()
      ..moveTo(-20, h * 0.95)
      ..cubicTo(size.width * 0.25, h * 0.35, size.width * 0.45, h * 1.15, size.width * 0.65, h * 0.6)
      ..cubicTo(size.width * 0.8, h * 0.2, size.width * 0.95, h * 0.55, size.width + 20, h * 0.4);
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(size.width * 0.65, h * 0.6), 5, Paint()..color = Colors.white.withValues(alpha: 0.18));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Google "G" mark drawn in its four brand colors (no image asset needed).
class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.2;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, s - stroke, s - stroke);
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const deg = 3.14159265 / 180;
    canvas.drawArc(rect, -40 * deg, -100 * deg, false, arc(const Color(0xFFEA4335))); // red, top
    canvas.drawArc(rect, -140 * deg, -90 * deg, false, arc(const Color(0xFFFBBC05))); // yellow, left
    canvas.drawArc(rect, 130 * deg, -90 * deg, false, arc(const Color(0xFF34A853))); // green, bottom
    canvas.drawArc(rect, 40 * deg, -80 * deg, false, arc(const Color(0xFF4285F4))); // blue, right
    canvas.drawRect(
      Rect.fromLTWH(s * 0.5, s * 0.5 - stroke / 2, s * 0.5 - stroke / 2 + stroke / 2, stroke),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
