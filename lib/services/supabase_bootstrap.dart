// Olympus Mont Systems LLC - ControlMiles
// lib/services/supabase_bootstrap.dart
//
// Supabase set-up shared by main() and the headless isolate. Android runs the
// GPS callback in a headless isolate while the app is closed; that isolate never
// runs main(), so anything there that talks to Supabase (finding the open trip,
// starting a trip by itself) must make sure the client exists first.
// Supabase.initialize skips itself when it already ran.

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'secure_supabase_storage.dart';

class SupabaseBootstrap {
  SupabaseBootstrap._();

  static const url = 'https://zuujwmcftycmdaxesdya.supabase.co';
  static const _publishableKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp1dWp3bWNmdHljbWRheGVzZHlhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2MTA1MjUsImV4cCI6MjA5MTE4NjUyNX0.hdkU3aFdjJzoKPFjLoBSlSA0aq2zrpF2O6wwmz1dfVA';

  static Future<void>? _run;
  static bool _ready = false;

  /// True once the client exists (Supabase.instance is safe to touch).
  static bool get isReady => _ready;

  /// Safe to call many times and from several places at once: every caller gets
  /// the same run. main() starts it without waiting (2026-11-05, cold-start
  /// speed) so the Android Keystore opens while the first frame is drawn;
  /// anything that needs the client awaits this first.
  static Future<void> ensure() {
    return _run ??= _initialize().then((_) => _ready = true).catchError((Object e) {
      _run = null; // let the next caller try again
      throw e;
    });
  }

  static Future<void> _initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    final persistSessionKey = 'sb-${Uri.parse(url).host.split(".").first}-auth-token';
    await Supabase.initialize(
      url: url,
      publishableKey: _publishableKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSupabaseLocalStorage(persistSessionKey: persistSessionKey),
        pkceAsyncStorage: SecureGotrueAsyncStorage(),
      ),
    );
  }
}
