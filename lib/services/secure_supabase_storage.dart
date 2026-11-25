// Olympus Mont Systems LLC - ControlMiles
// lib/services/secure_supabase_storage.dart
//
// 2026-08-24 security hardening (audit finding #1): supabase_flutter's
// default LocalStorage/GotrueAsyncStorage both persist to plain
// shared_preferences -- unencrypted on Android, readable by anyone with
// filesystem access to the app's private data dir. Combined with
// android:allowBackup defaulting to true (see AndroidManifest.xml), this
// meant `adb backup` on an unlocked, non-rooted phone could extract the
// refresh token directly -- full account takeover with no password, no
// root, no exploit. These two adapters route the same data through
// flutter_secure_storage instead (Android Keystore / iOS Keychain), so a
// stolen device's app-data backup no longer contains a usable session.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'diag_log.dart';

const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

/// Reads the saved session, trying again before giving up (2026-11-24). Right after an
/// update or a phone start the Android Keystore can answer with an error for a moment;
/// a single failed read looked like "no session" and sent the driver to sign in again,
/// which cleared the setup. A read that keeps failing returns [fallback]; it never
/// deletes what is saved, so the next start can still read it.
Future<T> _readWithRetry<T>(Future<T> Function() read, T fallback) async {
  for (var attempt = 1; attempt <= 3; attempt++) {
    try {
      return await read();
    } catch (e) {
      debugPrint('[SecureStorage] read failed (try $attempt of 3): $e');
      if (attempt == 3) {
        unawaited(
          DiagLog.add('session storage read failed', {
            'type': e.runtimeType.toString(),
          }),
        );
      } else {
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
  }
  return fallback;
}

/// Replaces supabase_flutter's default SharedPreferencesLocalStorage.
/// Same session-persistence contract (see LocalStorage in
/// package:supabase_flutter/src/local_storage.dart), backed by the
/// platform keystore instead of shared_preferences.
class SecureSupabaseLocalStorage extends LocalStorage {
  const SecureSupabaseLocalStorage({required this.persistSessionKey});

  final String persistSessionKey;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    return await _readWithRetry(
      () => _secureStorage.containsKey(key: persistSessionKey),
      false,
    );
  }

  @override
  Future<String?> accessToken() async {
    return _readWithRetry<String?>(
      () => _secureStorage.read(key: persistSessionKey),
      null,
    );
  }

  @override
  Future<void> removePersistedSession() async {
    await _secureStorage.delete(key: persistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _secureStorage.write(
      key: persistSessionKey,
      value: persistSessionString,
    );
  }
}

/// Replaces supabase_flutter's default SharedPreferencesGotrueAsyncStorage
/// (used for the PKCE flow's code verifier). Lower sensitivity than the
/// session token itself -- single-use, short-lived -- but there's no
/// reason to leave it on the weaker backend once the real session storage
/// is being hardened anyway.
class SecureGotrueAsyncStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) {
    return _secureStorage.read(key: key);
  }

  @override
  Future<void> setItem({required String key, required String value}) {
    return _secureStorage.write(key: key, value: value);
  }

  @override
  Future<void> removeItem({required String key}) {
    return _secureStorage.delete(key: key);
  }
}
