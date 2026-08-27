// Olympus Mont Systems LLC - ControlMiles
// lib/services/cgc_monitor_service.dart
//
// Forwards uncaught Flutter errors to CGC Core's crash-monitoring
// pipeline via supabase/functions/report-error -- same pattern LedgiProof
// and LedgiProof Tax Pro already use (see [[project_cgc_core]]). Wired
// into main.dart's FlutterError.onError / PlatformDispatcher.onError.
//
// Deliberately requires no signed-in user (report-error's own edge
// function has verify_jwt: false) -- a crash before login is exactly the
// kind worth catching. Never throws: a broken monitoring pipe must never
// itself become a source of errors in the app it's monitoring.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CgcMonitorService {
  static Future<void> reportError({
    required String message,
    String? stack,
    String severity = 'error',
    Map<String, dynamic>? context,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'report-error',
        body: {
          'app_source': 'controlmiles',
          'environment': kReleaseMode ? 'production' : 'development',
          'severity': severity,
          'message': message,
          'stack': stack ?? '',
          'context': context ?? {},
        },
      );
    } catch (e) {
      debugPrint('[CgcMonitorService] reportError failed: $e');
    }
  }
}
