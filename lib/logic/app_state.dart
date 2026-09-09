// Olympus Mont Systems LLC - ControlMiles
// lib/logic/app_state.dart - PRODUCTION READY (LANGUAGE + DARK MODE + USER ID)

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../i18n/app_texts.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../models/organization.dart';
import '../tracking/auto_trip_detection_service.dart';

class AppState extends ChangeNotifier {

  // ============================================================
  // ESTADO PRINCIPAL
  // ============================================================
  AppLanguage _currentLanguage = AppLanguage.en;
  bool _useMetricSystem = false;
  bool _isDarkMode = true;           // ← Nuevo: Dark Mode por defecto
  // BUG FIX (toggle de notificaciones inerte): antes esto solo vivía como
  // estado local de SettingsScreen — nada fuera de esa pantalla podía
  // leerlo, incluyendo el propio NotificationService. Ahora sigue el mismo
  // patrón que isDarkMode/useMetricSystem: única fuente de verdad acá,
  // persistida bajo la misma clave que ya usaba SettingsScreen (sin
  // migración necesaria).
  bool _notificationsEnabled = true;
  // Premium Gig feature (explicit user requirement): automatic trip
  // detection. Device-level like notificationsEnabled/darkMode -- the
  // background listening service either runs on THIS device or doesn't,
  // it's not account state. Actually gating whether it can be turned on
  // at all is premiumEntitled (server-verified, see profiles.premium_entitled)
  // -- this flag only tracks whether the user has chosen to turn it on.
  bool _autoDetectEnabled = false;
  bool _isInitialized = false;
  String? _currentSessionId;

  // ============================================================
  // IDENTIDAD DEL USUARIO
  // ============================================================
  String? _userDisplayId;
  // BUG FIX (pedido explícito, saludo en Dashboard): mismo patrón que
  // _userDisplayId -- se trae en el mismo query de fetchUserProfile() y se
  // limpia en los mismos puntos (clearAll/signOutAndClear) para no
  // reabrir el bug de caché cruzado entre cuentas que ya se arregló acá.
  String? _firstName;

  // ============================================================
  // FLEET MODULE -- Gig / Fleet account type
  // ============================================================
  // profiles.account_type ya existe en DB (default 'gig', trigger
  // tr_enforce_fleet_org exige organization_members activo para
  // fleet_admin/fleet_driver) desde antes de que ningún código Dart lo
  // leyera. Mismo patrón de caché que userDisplayId/firstName arriba.
  String _accountType = 'gig';
  String? _defaultOrgId;
  // Gates paid Gig features (starting with automatic trip detection).
  // Real Stripe subscriptions now exist (see [[project_controlmiles]],
  // stripe-webhook) -- this flag is kept in sync by that webhook, not
  // manually toggled anymore.
  bool _premiumEntitled = false;
  // Base tier ($5.99) -- prep only, per explicit user request
  // (2026-08-28): the schema/webhook track this now so it's ready, but
  // nothing in the app actually gates on it yet -- that's deliberately
  // separate future work (a real trial-expiry paywall), not assumed here.
  bool _baseEntitled = false;
  // Real subscription-tier enforcement (explicit user requirement,
  // 2026-09-04): the 30-day free-trial clock starts here. Same column the
  // server-side trigger (fn_enforce_trial_or_subscription) reads --
  // single source of truth, no duplicated "trial start" concept.
  DateTime? _accountCreatedAt;
  // Owner/QA accounts exempted from all tier enforcement (trial expiry,
  // vehicle count, PDF export limit) -- profiles.tier_enforcement_exempt,
  // same flag the 3 server-side enforcement points check first.
  bool _tierEnforcementExempt = false;
  // IRS Fase 3 (2026-08-28): which deduction method the driver states
  // they're using -- 'standard' or 'actual'. ControlMiles only ever
  // computes standard-mileage-rate figures; this exists so the report's
  // disclaimer can honestly say which method the numbers reflect,
  // not so the app itself changes any calculation based on it.
  String _mileageMethod = 'standard';
  // Deliberately NOT cached to SharedPreferences like accountType/etc --
  // invites can arrive or get withdrawn at any time, so a stale disk copy
  // risks showing an already-handled invite (or hiding a brand new one).
  // Always fetched fresh in _init() and after any accept/decline.
  List<PendingInvite> _pendingInvites = [];

  // ============================================================
  // ONBOARDING
  // ============================================================
  bool _permissionsCompleted = false;
  // user_onboarding.account_type_chosen -- separado de _accountType porque
  // 'gig' es tanto el default real como "todavía no eligió", así que
  // account_type solo no alcanza para distinguir ambos casos.
  bool _accountTypeChosen = false;

  // ============================================================
  // FIRST-LAUNCH ROLE CHOOSER (Gig App Driver / Fleet Driver / Fleet
  // Admin) -- shown once per DEVICE, before any account exists, so this
  // can only live in SharedPreferences, never user_onboarding. Deliberately
  // NOT removed in clearAll() (device-level, survives logout -- same
  // category as dark_mode/lang/unit_system). pendingIntendedRole IS a
  // per-signup-session value though: cleared once welcome_page.dart
  // consumes it, and on sign-out.
  // ============================================================
  bool _hasSeenRoleChooser = false;
  String? _pendingIntendedRole; // 'gig' | 'fleet_driver' | 'fleet_admin'

  bool get hasSeenRoleChooser => _hasSeenRoleChooser;
  String? get pendingIntendedRole => _pendingIntendedRole;

  // ============================================================
  // GETTERS
  // ============================================================
  AppLanguage get currentLanguage => _currentLanguage;
  bool get useMetricSystem => _useMetricSystem;
  bool get isDarkMode => _isDarkMode;                    // ← Nuevo
  bool get notificationsEnabled => _notificationsEnabled;
  bool get autoDetectEnabled => _autoDetectEnabled;
  bool get isInitialized => _isInitialized;
  String? get currentSessionId => _currentSessionId;
  String? get userDisplayId => _userDisplayId;
  String? get firstName => _firstName;
  bool get permissionsCompleted => _permissionsCompleted;
  String get accountType => _accountType;
  String? get defaultOrgId => _defaultOrgId;
  bool get premiumEntitled => _premiumEntitled;
  bool get baseEntitled => _baseEntitled;
  String get mileageMethod => _mileageMethod;
  bool get accountTypeChosen => _accountTypeChosen;
  bool get isGig => _accountType == 'gig';
  bool get isFleetAdmin => _accountType == 'fleet_admin';
  bool get isFleetDriver => _accountType == 'fleet_driver';
  bool get isFleetAccount => isFleetAdmin || isFleetDriver;

  // ============================================================
  // SUBSCRIPTION-TIER ENFORCEMENT (explicit user requirement, 2026-09-04)
  // Fleet is entirely out of scope (isFleetAccount check on every getter
  // below) -- that's a separate pricing model, not built yet. Mirrors the
  // server-side triggers/RPC exactly (fn_enforce_trial_or_subscription,
  // fn_enforce_vehicle_count_limit, check_and_log_pdf_export) -- these
  // getters are for instant client-side UX only, never the real floor.
  // ============================================================
  static const int _freeTrialDays = 30;

  /// True once a Gig, non-exempt, non-subscribed account's 30-day trial
  /// has run out -- the ONLY thing this blocks is starting a NEW trip
  /// (see TrackingActionButton's canStart), never viewing existing data.
  bool get isFreeTrialExpired {
    if (isFleetAccount || _tierEnforcementExempt) return false;
    if (_premiumEntitled || _baseEntitled) return false;
    if (_accountCreatedAt == null) return false;
    return DateTime.now().difference(_accountCreatedAt!).inDays > _freeTrialDays;
  }

  /// True while on the "Started" (free trial) tier -- never subscribed,
  /// trial not yet expired. Explicit user requirement (2026-09-09): show
  /// this state as its own named tier in the Subscription screen instead
  /// of leaving it implicit.
  bool get isOnFreeTrial {
    if (isFleetAccount || _tierEnforcementExempt) return false;
    if (_premiumEntitled || _baseEntitled) return false;
    return !isFreeTrialExpired;
  }

  /// Days left in the Started trial, floored at 0. Null when not
  /// applicable (subscribed, exempt, Fleet, or unknown account age).
  int? get freeTrialDaysLeft {
    if (!isOnFreeTrial || _accountCreatedAt == null) return null;
    final elapsed = DateTime.now().difference(_accountCreatedAt!).inDays;
    final remaining = _freeTrialDays - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  /// null = unlimited (exempt or Fleet). 5 for Premium, 1 for Started
  /// (trial) or Basic -- mirrors fn_enforce_vehicle_count_limit exactly
  /// (explicit user requirement, 2026-09-09: Started/Basic both cap at 1,
  /// Premium caps at 5 -- Premium used to be unlimited here, a real gap
  /// since the server-side trigger enforced no cap for it either).
  int? get maxVehicles {
    if (isFleetAccount || _tierEnforcementExempt) return null;
    return _premiumEntitled ? 5 : 1;
  }
  List<PendingInvite> get pendingInvites => _pendingInvites;
  bool get hasPendingInvites => _pendingInvites.isNotEmpty;

  bool get isAuthenticated => Supabase.instance.client.auth.currentUser != null;
  String? get currentUserId => Supabase.instance.client.auth.currentUser?.id;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================
  AppState() {
    _init();
  }

  Future<void> _init() async {
    await loadFromPrefs();

    if (isAuthenticated) {
      await fetchUserProfile();
      await fetchAccountTypeChosen();
      await fetchPendingInvites();
    }

    _isInitialized = true;
    notifyListeners();
  }

  // ============================================================
  // USER PROFILE
  // ============================================================
  Future<void> fetchUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('display_id, first_name, account_type, default_org_id, premium_entitled, base_entitled, mileage_method, created_at, tier_enforcement_exempt')
          .eq('id', user.id)
          .maybeSingle();

      final String? newDisplayId = data?['display_id'] as String?;
      final String? newFirstName = data?['first_name'] as String?;
      final String newAccountType = data?['account_type'] as String? ?? 'gig';
      final String? newDefaultOrgId = data?['default_org_id'] as String?;
      final bool newPremiumEntitled = data?['premium_entitled'] as bool? ?? false;
      final bool newBaseEntitled = data?['base_entitled'] as bool? ?? false;
      // IRS Fase 3 (2026-08-28): which deduction method the driver is
      // actually using -- 'standard' is the only one ControlMiles
      // computes figures for today, and the only one the report's
      // disclaimer text can honestly claim.
      final String newMileageMethod = data?['mileage_method'] as String? ?? 'standard';
      // Subscription-tier enforcement (2026-09-04) -- see isFreeTrialExpired.
      final DateTime? newAccountCreatedAt = data?['created_at'] != null
          ? DateTime.tryParse(data!['created_at'] as String)
          : null;
      final bool newTierEnforcementExempt = data?['tier_enforcement_exempt'] as bool? ?? false;
      final bool changed = _userDisplayId != newDisplayId ||
          _firstName != newFirstName ||
          _accountType != newAccountType ||
          _defaultOrgId != newDefaultOrgId ||
          _premiumEntitled != newPremiumEntitled ||
          _baseEntitled != newBaseEntitled ||
          _mileageMethod != newMileageMethod ||
          _accountCreatedAt != newAccountCreatedAt ||
          _tierEnforcementExempt != newTierEnforcementExempt;

      // BUG FIX (explicit user requirement, 2026-09-04, "Basic solo debe
      // ver el carrusel"): if Premium lapses (subscription cancelled,
      // downgraded) while auto-detect was left on from before, nothing
      // used to turn it back off -- the dashboard would keep showing the
      // auto-detect status card instead of the plain carousel, and the
      // background detection service would keep running silently for a
      // tier that no longer has access to the feature at all. Checked
      // BEFORE the `changed` block below updates _premiumEntitled, so this
      // only fires on a genuine true -> false transition, not on every
      // profile fetch.
      if (_premiumEntitled && !newPremiumEntitled && _autoDetectEnabled) {
        _autoDetectEnabled = false;
        await AutoTripDetectionService.instance.setEnabled(false);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('controlmiles_auto_detect_enabled', false);
      }

      // Fleet Sprint 3 (shift-scoped privacy, explicit user request,
      // 2026-09-09): a hybrid account switching from gig into fleet_admin/
      // fleet_driver mode (OrgModeSwitcher, Sprint 2) could otherwise carry
      // an auto-detect flag left on from their Gig usage straight into
      // Fleet mode -- the background location/gig-app-detection service
      // has no business running at all for a fleet_driver outside an
      // active tracked session. Same "check BEFORE _accountType updates
      // below" ordering as the premium-lapse fix above, so this only fires
      // on a genuine gig -> fleet transition, not on every profile fetch
      // while already in fleet mode.
      final becameFleetAccount = _accountType == 'gig' &&
          (newAccountType == 'fleet_admin' || newAccountType == 'fleet_driver');
      if (becameFleetAccount && _autoDetectEnabled) {
        _autoDetectEnabled = false;
        await AutoTripDetectionService.instance.setEnabled(false);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('controlmiles_auto_detect_enabled', false);
      }

      if (changed) {
        _userDisplayId = newDisplayId;
        _firstName = newFirstName;
        _accountType = newAccountType;
        _defaultOrgId = newDefaultOrgId;
        _premiumEntitled = newPremiumEntitled;
        _baseEntitled = newBaseEntitled;
        _mileageMethod = newMileageMethod;
        _accountCreatedAt = newAccountCreatedAt;
        _tierEnforcementExempt = newTierEnforcementExempt;

        final prefs = await SharedPreferences.getInstance();
        if (_userDisplayId != null) {
          await prefs.setString('controlmiles_user_display_id', _userDisplayId!);
        } else {
          await prefs.remove('controlmiles_user_display_id');
        }
        if (_firstName != null) {
          await prefs.setString('controlmiles_first_name', _firstName!);
        } else {
          await prefs.remove('controlmiles_first_name');
        }
        await prefs.setString('controlmiles_account_type', _accountType);
        await prefs.setBool('controlmiles_premium_entitled', _premiumEntitled);
        await prefs.setBool('controlmiles_base_entitled', _baseEntitled);
        await prefs.setBool('controlmiles_tier_enforcement_exempt', _tierEnforcementExempt);
        if (_accountCreatedAt != null) {
          await prefs.setString('controlmiles_account_created_at', _accountCreatedAt!.toIso8601String());
        } else {
          await prefs.remove('controlmiles_account_created_at');
        }
        if (_defaultOrgId != null) {
          await prefs.setString('controlmiles_default_org_id', _defaultOrgId!);
        } else {
          await prefs.remove('controlmiles_default_org_id');
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AppState] Error fetching profile: $e');
    }
  }

  /// Refresca account_type/default_org_id contra la DB sin esperar al
  /// próximo fetchUserProfile() -- se llama justo después de
  /// createOrganization() para que isFleetAdmin ya sea true en la misma
  /// sesión, sin pedirle al usuario que reinicie la app.
  Future<void> refreshAccountType() => fetchUserProfile();

  /// user_onboarding.account_type_chosen -- si ya se marcó, la app nunca
  /// vuelve a mostrar la pantalla de elección Gig/Fleet para esta cuenta.
  Future<void> fetchAccountTypeChosen() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('user_onboarding')
          .select('account_type_chosen')
          .eq('user_id', user.id)
          .maybeSingle();

      final bool chosen = data?['account_type_chosen'] as bool? ?? false;
      if (_accountTypeChosen != chosen) {
        _accountTypeChosen = chosen;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('controlmiles_account_type_chosen', chosen);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AppState] Error fetching account_type_chosen: $e');
    }
  }

  /// Fleet Phase 2: pending organization_members rows (is_active = false)
  /// for the current user. org_members_select_own (RLS) already lets a
  /// member see their own row regardless of is_active -- no policy change
  /// was needed for this to work.
  Future<void> fetchPendingInvites() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('organization_members')
          .select('id, organization_id, invited_at, organizations(name)')
          .eq('user_id', user.id)
          .eq('is_active', false)
          .order('invited_at', ascending: false);

      _pendingInvites = List<Map<String, dynamic>>.from(data)
          .map(PendingInvite.fromMap)
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('[AppState] Error fetching pending invites: $e');
    }
  }

  Future<void> completeAccountTypeChoice() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _accountTypeChosen = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('controlmiles_account_type_chosen', true);

    try {
      await Supabase.instance.client.from('user_onboarding').upsert({
        'user_id': user.id,
        'account_type_chosen': true,
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('[AppState] Warning: could not persist account_type_chosen: $e');
    }
  }

  // ============================================================
  // DARK MODE
  // ============================================================
  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;

    _isDarkMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('controlmiles_dark_mode', value);
  }

  // Toggle rápido
  Future<void> toggleDarkMode() async {
    await setDarkMode(!_isDarkMode);
  }

  // ============================================================
  // NOTIFICACIONES
  // ============================================================
  Future<void> setNotificationsEnabled(bool value) async {
    if (_notificationsEnabled == value) return;

    _notificationsEnabled = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);

    await NotificationService.instance.setEnabled(value);
  }

  // ============================================================
  // DETECCIÓN AUTOMÁTICA DE VIAJES (premium, Gig-only)
  // ============================================================
  /// Caller is responsible for checking premiumEntitled/isGig before ever
  /// calling this with value=true -- this setter itself doesn't re-check
  /// entitlement, same division of responsibility as the rest of this
  /// class (UI reads the flags, this just persists a choice).
  ///
  /// Returns whether the underlying GPS engine is actually running after
  /// this call (only meaningful when value=true) -- part of the
  /// 2026-08-28 silent-auto-detect-failure fix, see
  /// AutoTripDetectionService.setEnabled's own comment. Turning it off
  /// always reports true (there's nothing to fail).
  Future<bool> setAutoDetectEnabled(bool value) async {
    if (_autoDetectEnabled == value) return true;

    _autoDetectEnabled = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('controlmiles_auto_detect_enabled', value);

    return await AutoTripDetectionService.instance.setEnabled(value);
  }

  /// IRS Fase 3 (2026-08-28): writes straight to profiles.mileage_method
  /// -- no local device caching needed (unlike autoDetectEnabled/etc,
  /// this has no offline-critical read path, it's just report metadata).
  Future<void> setMileageMethod(String value) async {
    if (_mileageMethod == value) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final previous = _mileageMethod;
    _mileageMethod = value;
    notifyListeners();

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'mileage_method': value})
          .eq('id', user.id);
    } catch (e) {
      debugPrint('[AppState] Error saving mileage_method: $e');
      _mileageMethod = previous;
      notifyListeners();
    }
  }

  // ============================================================
  // IDIOMA
  // ============================================================
  Future<void> setLanguage(AppLanguage language) async {
    if (_currentLanguage == language) return;

    _currentLanguage = language;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('controlmiles_lang', language.code);
  }

  // ============================================================
  // UNIDADES
  // ============================================================
  Future<void> setUseMetricSystem(bool value) async {
    if (_useMetricSystem == value) return;

    _useMetricSystem = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('controlmiles_unit_system', value);
  }

  // ============================================================
  // SESIÓN ACTUAL
  // ============================================================
  void setCurrentSession(String? sessionId) {
    if (_currentSessionId != sessionId) {
      _currentSessionId = sessionId;
      notifyListeners();
    }
  }

  // ============================================================
  // ONBOARDING
  // ============================================================
  Future<void> completePermissionsSetup() async {
    _permissionsCompleted = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('controlmiles_permissions_completed', true);
  }

  // ============================================================
  // FIRST-LAUNCH ROLE CHOOSER
  // ============================================================

  /// Called when a new user picks a card on RoleChooserScreen. Marks the
  /// chooser seen (never shown again on this device) and remembers which
  /// destination signup should skip ahead to once welcome/permissions is
  /// done -- see WelcomePage._completeOnboarding.
  Future<void> chooseIntendedRole(String role) async {
    _hasSeenRoleChooser = true;
    _pendingIntendedRole = role;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('controlmiles_has_seen_role_chooser', true);
    await prefs.setString('controlmiles_pending_intended_role', role);
  }

  /// "Already have an account? Sign in" on RoleChooserScreen -- marks the
  /// chooser seen without setting an intended role, so a returning user
  /// reinstalling on a new device just goes to normal LoginScreen from
  /// here on, never a role picker.
  Future<void> skipRoleChooser() async {
    _hasSeenRoleChooser = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('controlmiles_has_seen_role_chooser', true);
  }

  Future<void> clearPendingIntendedRole() async {
    if (_pendingIntendedRole == null) return;
    _pendingIntendedRole = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('controlmiles_pending_intended_role');
  }

  // ============================================================
  // TRADUCCIÓN
  // ============================================================
  String tr(String key) {
    return AppTexts.getText(key, _currentLanguage);
  }

  // ============================================================
  // PERSISTENCIA
  // ============================================================
  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Idioma
      final langCode = prefs.getString('controlmiles_lang');
      if (langCode != null) {
        _currentLanguage = AppLanguageExtension.fromCode(langCode);
      }

      // Unidades
      _useMetricSystem = prefs.getBool('controlmiles_unit_system') ?? false;

      // Dark Mode (nuevo)
      _isDarkMode = prefs.getBool('controlmiles_dark_mode') ?? true;

      // Notificaciones (misma clave que ya usaba SettingsScreen)
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

      // Detección automática de viajes (premium, Gig-only)
      _autoDetectEnabled = prefs.getBool('controlmiles_auto_detect_enabled') ?? false;

      // Onboarding
      _permissionsCompleted = prefs.getBool('controlmiles_permissions_completed') ?? false;

      // User Display ID
      _userDisplayId = prefs.getString('controlmiles_user_display_id');

      // Nombre (saludo del Dashboard)
      _firstName = prefs.getString('controlmiles_first_name');

      // Fleet module
      _accountType = prefs.getString('controlmiles_account_type') ?? 'gig';
      _defaultOrgId = prefs.getString('controlmiles_default_org_id');
      _premiumEntitled = prefs.getBool('controlmiles_premium_entitled') ?? false;
      _baseEntitled = prefs.getBool('controlmiles_base_entitled') ?? false;
      _tierEnforcementExempt = prefs.getBool('controlmiles_tier_enforcement_exempt') ?? false;
      final cachedCreatedAt = prefs.getString('controlmiles_account_created_at');
      _accountCreatedAt = cachedCreatedAt != null ? DateTime.tryParse(cachedCreatedAt) : null;
      _accountTypeChosen = prefs.getBool('controlmiles_account_type_chosen') ?? false;

      // First-launch role chooser (device-level, see clearAll())
      _hasSeenRoleChooser = prefs.getBool('controlmiles_has_seen_role_chooser') ?? false;
      _pendingIntendedRole = prefs.getString('controlmiles_pending_intended_role');

    } catch (e) {
      debugPrint('[AppState] Error loading preferences: $e');
    }
  }

  // ============================================================
  // LIMPIAR ESTADO (Logout)
  // ============================================================
  Future<void> clearAll() async {
    _userDisplayId = null;
    _firstName = null;
    _currentSessionId = null;
    _permissionsCompleted = false;
    _accountType = 'gig';
    _defaultOrgId = null;
    _premiumEntitled = false;
    _baseEntitled = false;
    _tierEnforcementExempt = false;
    _accountCreatedAt = null;
    _accountTypeChosen = false;
    // A different account on this same device shouldn't inherit the
    // previous account's premium auto-detect choice, and the listening
    // service must stop -- it has no idle account to attribute a
    // detected trip to once signed out.
    _autoDetectEnabled = false;
    await AutoTripDetectionService.instance.setEnabled(false);
    _pendingInvites = [];
    // NOT cleared: _hasSeenRoleChooser -- device-level, must survive
    // logout (see the field's own doc comment above).
    _pendingIntendedRole = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('controlmiles_user_display_id');
    await prefs.remove('controlmiles_first_name');
    await prefs.remove('controlmiles_permissions_completed');
    await prefs.remove('controlmiles_account_type');
    await prefs.remove('controlmiles_premium_entitled');
    await prefs.remove('controlmiles_base_entitled');
    await prefs.remove('controlmiles_tier_enforcement_exempt');
    await prefs.remove('controlmiles_account_created_at');
    await prefs.remove('controlmiles_auto_detect_enabled');
    await prefs.remove('controlmiles_default_org_id');
    await prefs.remove('controlmiles_account_type_chosen');
    await prefs.remove('controlmiles_pending_intended_role');

    notifyListeners();
  }

  // ============================================================
  // SIGN OUT (pedido explícito) — dos bugs reales encontrados acá:
  //
  // Bug #1 (user ID cruzado entre cuentas): clearAll() ya existía pero
  // NINGÚN botón de logout lo llamaba -- grep confirmó cero call sites.
  // Cada pantalla de logout (drawer, profile, delete-account) solo
  // llamaba AuthService().signOut(), que cierra la sesión en Supabase
  // pero nunca toca _userDisplayId ni el SharedPreferences que lo
  // persiste. AppState es una sola instancia para toda la vida del
  // proceso (ChangeNotifierProvider en main.dart) y fetchUserProfile()
  // solo se llamaba una vez, dentro de _init() al arrancar la app. Si el
  // usuario cerraba sesión y entraba con OTRA cuenta sin reiniciar la
  // app, nada volvía a pedirle el display_id real a la DB -- seguía
  // mostrando el de la cuenta anterior, cacheado en memoria y en disco.
  // La DB en sí está bien (display_id tiene UNIQUE constraint, cada
  // usuario tiene el suyo, verificado directo en Supabase) -- el bug es
  // 100% de caché client-side.
  //
  // Bug #2 (la app queda "colgada" al cerrar sesión): AuthService.
  // signOut() relanza cualquier error como Exception genérica, y los
  // botones de logout llamaban `await authService.signOut()` SIN
  // try/catch antes de navegar -- si esa llamada de red fallaba (lo cual
  // pasó bastante en esta sesión de pruebas con reset de contraseña /
  // borrado de cuenta encima), la excepción quedaba sin manejar dentro
  // del callback async y la navegación a Login nunca se ejecutaba. La
  // UI quedaba "viva" pero sin reaccionar, indistinguible de un cuelgue
  // real para el usuario.
  //
  // Fix único para ambos: este método nunca lanza (el fallo de red en
  // signOut() se loguea y se ignora -- la intención del usuario de
  // salir se respeta igual, localmente) y siempre limpia el estado
  // cacheado. Los tres call sites (drawer, profile, delete-account) se
  // reescriben para usar esto en vez de llamar AuthService directo.
  // ============================================================
  Future<void> signOutAndClear() async {
    try {
      await AuthService().signOut();
    } catch (e) {
      debugPrint('[AppState] signOut remoto falló (se limpia igual localmente): $e');
    }
    await clearAll();
  }
}