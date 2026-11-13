// Olympus Mont Systems LLC - ControlMiles
// lib/services/diag_log.dart
//
// Diagnostic log (2026-11-06). Trips run in the background, which cannot be
// watched from outside in a store build. The app appends
// short lines to the same file; Settings can send it to the server so a trip can be
// reconstructed afterwards. It holds no personal text: times, coordinates rounded to
// ~100 m, counts and reasons.

import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DiagLog {
  DiagLog._();

  /// Which engine writes: the app's own ('ui'); the name stays for older logs.
  static String tag = 'ui';

  static const _maxBytes = 400 * 1024;
  static File? _file;

  /// Four hex digits, new for every Dart engine that starts (the app and the one Android
  /// wakes in the background each get their own): a line shows which one wrote it, so a
  /// log read afterwards can tell two engines apart.
  static final String _engineId = Random().nextInt(0x10000).toRadixString(16).padLeft(4, '0');

  static Future<File> _open() async {
    final cached = _file;
    if (cached != null) return cached;
    final dir = await getApplicationSupportDirectory();
    final f = File('${dir.path}/cm_diag.log');
    _file = f;
    return f;
  }

  /// Appends one line. Never throws and never waits for the caller's flow.
  ///
  /// The app, the background GPS engine and the wake-up engine are separate Dart
  /// isolates writing this one file. The old async write could be split in two by
  /// another engine's line (2026-11-12: 153 cut lines in 19 h, 2309 in the whole
  /// file). Now the whole line goes out in ONE synchronous write on an append-mode
  /// handle: nothing else in this isolate can run in between, and a single append
  /// write is not split by another process.
  static Future<void> add(String event, [Map<String, Object?> data = const {}]) async {
    try {
      final f = await _open();
      final extra = data.isEmpty ? '' : ' ${data.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
      final line = '${DateTime.now().toIso8601String()} [$tag:$_engineId] $event$extra\n';
      final raf = f.openSync(mode: FileMode.append);
      try {
        raf.writeFromSync(utf8.encode(line));
        raf.flushSync();
      } finally {
        raf.closeSync();
      }
      if (f.lengthSync() > _maxBytes) _trim(f);
    } catch (e) {
      debugPrint('[DiagLog] $e');
    }
  }

  /// Keeps the newer half, starting at a whole line. Written to a side file and renamed
  /// over the log, so a reader (the upload) or another engine never sees a half-written
  /// file; a line another engine appends during the swap can be lost, which is the
  /// price of not locking.
  static void _trim(File f) {
    final text = f.readAsStringSync();
    final cut = text.indexOf('\n', text.length ~/ 2);
    final tmp = File('${f.path}.tmp');
    tmp.writeAsStringSync(cut < 0 ? '' : text.substring(cut + 1), flush: true);
    tmp.renameSync(f.path);
  }

  static final Map<String, DateTime> _lastSampled = {};

  /// Like [add], but at most once per [every] for the same [key] (default: the
  /// event name). For lines that arrive every second while driving -- one per GPS
  /// fix, one per mile step -- which filled the 400 KB file in ~5 hours
  /// (2026-11-11: 1979 'miles' + 524 'fix' lines in one day's log). The values
  /// that matter stay: 'miles' carries the running section total, so a sample
  /// still shows where the count stood.
  static Future<void> addSampled(
    String event,
    Duration every, [
    Map<String, Object?> data = const {},
    String? key,
  ]) {
    final k = key ?? event;
    final now = DateTime.now();
    final last = _lastSampled[k];
    if (last != null && now.difference(last) < every) return Future.value();
    _lastSampled[k] = now;
    return add(event, data);
  }

  /// Coordinates to ~100 m (3 decimals) so the log never shows an exact address.
  static String coarse(double v) => v.toStringAsFixed(3);

  static const _kLastUploadHash = 'diag_last_upload_hash';

  /// Sends the file to the server; true when it was saved there.
  static bool _uploading = false;

  static Future<bool> upload() async {
    // Repeated taps sent the same file several times (2026-11-07: 10 rows, 2 distinct).
    if (_uploading) return false;
    _uploading = true;
    try {
      final f = await _open();
      if (!await f.exists()) return false;
      final content = await f.readAsString();
      if (content.trim().isEmpty) return false;
      final body = content.length > 590000 ? content.substring(content.length - 590000) : content;

      // The in-flight guard above does not cover a second tap a second or two
      // after the first one finished (2026-11-08..10: pairs of identical rows
      // 1-2 s apart). The server already has exactly this text: say so instead of
      // inserting it again.
      final hash = sha256.convert(utf8.encode(body)).toString();
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_kLastUploadHash) == hash) return true;

      final info = await PackageInfo.fromPlatform();
      await Supabase.instance.client.from('diagnostic_logs').insert({
        'app_version': '${info.version}+${info.buildNumber}',
        'device': Platform.operatingSystemVersion,
        'content': body,
      });
      await prefs.setString(_kLastUploadHash, hash);
      return true;
    } catch (e) {
      debugPrint('[DiagLog] upload failed: $e');
      return false;
    } finally {
      _uploading = false;
    }
  }
}
