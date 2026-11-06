// Olympus Mont Systems LLC - ControlMiles
// lib/services/diag_log.dart
//
// Diagnostic log (2026-11-06). Background tracking runs in several Dart isolates
// (the open app, the short-lived wake engine, Tracelet's headless engine), none of
// which can be watched from outside in a store build. Every one of them appends
// short lines to the same file; Settings can send it to the server so a trip can be
// reconstructed afterwards. It holds no personal text: times, coordinates rounded to
// ~100 m, counts and reasons.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DiagLog {
  DiagLog._();

  /// Which isolate writes: 'ui', 'wake' or 'headless'. Each entry point sets it.
  static String tag = 'ui';

  static const _maxBytes = 400 * 1024;
  static File? _file;

  static Future<File> _open() async {
    final cached = _file;
    if (cached != null) return cached;
    final dir = await getApplicationSupportDirectory();
    final f = File('${dir.path}/cm_diag.log');
    _file = f;
    return f;
  }

  /// Appends one line. Never throws and never waits for the caller's flow.
  static Future<void> add(String event, [Map<String, Object?> data = const {}]) async {
    try {
      final f = await _open();
      final extra = data.isEmpty ? '' : ' ${data.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
      final line = '${DateTime.now().toIso8601String()} [$tag] $event$extra\n';
      await f.writeAsString(line, mode: FileMode.append, flush: true);
      if (await f.length() > _maxBytes) {
        final text = await f.readAsString();
        await f.writeAsString(text.substring(text.length ~/ 2));
      }
    } catch (e) {
      debugPrint('[DiagLog] $e');
    }
  }

  /// Coordinates to ~100 m (3 decimals) so the log never shows an exact address.
  static String coarse(double v) => v.toStringAsFixed(3);

  /// Sends the file to the server; true when it was saved there.
  static Future<bool> upload() async {
    try {
      final f = await _open();
      if (!await f.exists()) return false;
      final content = await f.readAsString();
      if (content.trim().isEmpty) return false;
      final info = await PackageInfo.fromPlatform();
      await Supabase.instance.client.from('diagnostic_logs').insert({
        'app_version': '${info.version}+${info.buildNumber}',
        'device': Platform.operatingSystemVersion,
        'content': content.length > 590000 ? content.substring(content.length - 590000) : content,
      });
      return true;
    } catch (e) {
      debugPrint('[DiagLog] upload failed: $e');
      return false;
    }
  }
}
