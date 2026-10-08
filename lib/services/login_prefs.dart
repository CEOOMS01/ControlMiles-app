// Olympus Mont Systems LLC - ControlMiles
// lib/services/login_prefs.dart
//
// "Remember my email" + "Stay signed in" (explicit user request,
// 2026-09-29). Researched before building (OWASP mobile M3/M4, Microsoft
// "Keep me signed in", banking apps):
//   * Remember = the IDENTIFIER only (email, or the fleet driver ID) --
//     never the password. Unchecking forgets it right away.
//   * Stay signed in = the session outlives closing the app. When off, the
//     next cold start of the app signs out -- except while a trip is being
//     recorded, which must never be cut off by a sign-out.
// Device-level prefs: AppState.clearAll() (sign-out) doesn't touch them, so
// a remembered email is still there on the login screen after signing out.

import 'package:shared_preferences/shared_preferences.dart';

class LoginPrefs {
  static const _kRememberId = 'controlmiles_login_remember_id';
  static const _kRememberedEmail = 'controlmiles_login_remembered_email';
  static const _kRememberedDriverId = 'controlmiles_login_remembered_driver_id';
  static const _kStaySignedIn = 'controlmiles_login_stay_signed_in';

  static Future<({bool remember, String? email, String? driverId, bool staySignedIn})> load() async {
    final p = await SharedPreferences.getInstance();
    return (
      remember: p.getBool(_kRememberId) ?? false,
      email: p.getString(_kRememberedEmail),
      driverId: p.getString(_kRememberedDriverId),
      // On by default on the phone: ControlMiles records trips in the
      // background and auto-detects them, which needs a live session.
      staySignedIn: p.getBool(_kStaySignedIn) ?? true,
    );
  }

  /// Called after a successful sign-in with whatever the driver chose.
  static Future<void> saveAfterSignIn({
    required bool remember,
    String? email,
    String? driverId,
    required bool staySignedIn,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kRememberId, remember);
    await p.setBool(_kStaySignedIn, staySignedIn);
    if (!remember) {
      await p.remove(_kRememberedEmail);
      await p.remove(_kRememberedDriverId);
      return;
    }
    if (email != null) await p.setString(_kRememberedEmail, email);
    if (driverId != null) await p.setString(_kRememberedDriverId, driverId);
  }

  static Future<bool> staySignedIn() async =>
      (await SharedPreferences.getInstance()).getBool(_kStaySignedIn) ?? true;

  // "Welcome back" only for someone who has signed in on this phone before
  // (2026-10-08: new users saw it on first open and right after sign-up).
  static const _kHasSignedIn = 'controlmiles_login_has_signed_in';

  static Future<bool> hasSignedInBefore() async =>
      (await SharedPreferences.getInstance()).getBool(_kHasSignedIn) ?? false;

  static Future<void> markSignedIn() async =>
      (await SharedPreferences.getInstance()).setBool(_kHasSignedIn, true);
}
