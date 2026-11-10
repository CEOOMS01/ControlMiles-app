// Olympus Mont Systems LLC - ControlMiles
// lib/services/trip_rules_service.dart
//
// Regular Trips and Work Hours (2026-11-09): how a General trip classifies itself.
// The database applies both when a trip closes (fn_classify_section_on_close), so
// this file only reads and saves the driver's choices.

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegularTrip {
  final String id;
  final bool startAny;
  final double? startLatitude;
  final double? startLongitude;
  final String? startAddress;
  final double endLatitude;
  final double endLongitude;
  final String? endAddress;
  final String purpose;

  const RegularTrip({
    required this.id,
    required this.startAny,
    this.startLatitude,
    this.startLongitude,
    this.startAddress,
    required this.endLatitude,
    required this.endLongitude,
    this.endAddress,
    required this.purpose,
  });

  factory RegularTrip.fromMap(Map<String, dynamic> m) => RegularTrip(
        id: m['id'] as String,
        startAny: m['start_any'] == true,
        startLatitude: (m['start_latitude'] as num?)?.toDouble(),
        startLongitude: (m['start_longitude'] as num?)?.toDouble(),
        startAddress: m['start_address'] as String?,
        endLatitude: (m['end_latitude'] as num).toDouble(),
        endLongitude: (m['end_longitude'] as num).toDouble(),
        endAddress: m['end_address'] as String?,
        purpose: m['purpose'] as String,
      );
}

class TripClassificationSettings {
  bool regularEnabled;
  bool suggestionsEnabled;
  bool workHoursInside;
  bool workHoursOutside;
  Set<int> workDays;
  int workStartMinute;
  int workEndMinute;

  TripClassificationSettings({
    this.regularEnabled = true,
    this.suggestionsEnabled = true,
    this.workHoursInside = false,
    this.workHoursOutside = false,
    Set<int>? workDays,
    this.workStartMinute = 540,
    this.workEndMinute = 1080,
  }) : workDays = workDays ?? {1, 2, 3, 4, 5};

  factory TripClassificationSettings.fromMap(Map<String, dynamic> m) => TripClassificationSettings(
        regularEnabled: m['regular_enabled'] != false,
        suggestionsEnabled: m['suggestions_enabled'] != false,
        workHoursInside: m['work_hours_inside'] == true,
        workHoursOutside: m['work_hours_outside'] == true,
        workDays: ((m['work_days'] as List?) ?? const [1, 2, 3, 4, 5]).map((d) => (d as num).toInt()).toSet(),
        workStartMinute: (m['work_start_minute'] as num?)?.toInt() ?? 540,
        workEndMinute: (m['work_end_minute'] as num?)?.toInt() ?? 1080,
      );

  Map<String, dynamic> toRow(String userId, String timeZone) => {
        'user_id': userId,
        'regular_enabled': regularEnabled,
        'suggestions_enabled': suggestionsEnabled,
        'work_hours_inside': workHoursInside,
        'work_hours_outside': workHoursOutside,
        'work_days': workDays.toList()..sort(),
        'work_start_minute': workStartMinute,
        'work_end_minute': workEndMinute,
        'time_zone': timeZone,
      };
}

class TripRulesService {
  TripRulesService._();

  static SupabaseClient get _client => Supabase.instance.client;
  static String get _userId => _client.auth.currentUser!.id;

  static Future<TripClassificationSettings> loadSettings() async {
    final row = await _client.from('trip_classification_settings').select().eq('user_id', _userId).maybeSingle();
    return row == null ? TripClassificationSettings() : TripClassificationSettings.fromMap(row);
  }

  /// Work Hours are read in the phone's time zone, so it is saved with them.
  static Future<void> saveSettings(TripClassificationSettings s) async {
    final zone = (await FlutterTimezone.getLocalTimezone()).identifier;
    await _client.from('trip_classification_settings').upsert(s.toRow(_userId, zone));
  }

  static Future<List<RegularTrip>> list() async {
    final rows = await _client.from('regular_trips').select().eq('user_id', _userId).order('created_at');
    return (rows as List).map((r) => RegularTrip.fromMap(r as Map<String, dynamic>)).toList();
  }

  static Future<String> create(Map<String, dynamic> fields) async {
    final row = await _client.from('regular_trips').insert({...fields, 'user_id': _userId}).select('id').single();
    return row['id'] as String;
  }

  static Future<void> update(String id, Map<String, dynamic> fields) =>
      _client.from('regular_trips').update(fields).eq('id', id);

  static Future<void> delete(String id) => _client.from('regular_trips').delete().eq('id', id);

  /// Earlier General trips on this route that still have no category.
  static Future<int> countPast(String id) async =>
      ((await _client.rpc('apply_regular_trip_to_past', params: {'p_rule_id': id, 'p_dry_run': true})) as num).toInt();

  static Future<int> applyToPast(String id) async =>
      ((await _client.rpc('apply_regular_trip_to_past', params: {'p_rule_id': id, 'p_dry_run': false})) as num).toInt();

  /// The route to offer as a regular trip after this trip was classified, or null.
  static Future<Map<String, dynamic>?> suggestFor(String sectionId) async {
    final data = await _client.rpc('suggest_regular_trip', params: {'p_section_id': sectionId});
    return data == null ? null : Map<String, dynamic>.from(data as Map);
  }
}
