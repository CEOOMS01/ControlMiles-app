// Olympus Mont Systems LLC - ControlMiles
// lib/services/work_schedule.dart
//
// Work-hours reminder (2026-11-01, Gig app only): on the days and hours the
// driver picks, the phone shows "Time to start tracking?" at the start time
// and "Done for the day?" at the end time. Local notifications only -- no
// location, no server. Stored on the phone (SharedPreferences), like the
// other notification settings.

import 'package:shared_preferences/shared_preferences.dart';

class WorkSchedule {
  final bool enabled;
  // DateTime.monday (1) .. DateTime.sunday (7).
  final Set<int> days;
  final int startMinutes; // minutes after midnight
  final int endMinutes;

  const WorkSchedule({
    required this.enabled,
    required this.days,
    required this.startMinutes,
    required this.endMinutes,
  });

  static const WorkSchedule defaults = WorkSchedule(
    enabled: false,
    days: {1, 2, 3, 4, 5},
    startMinutes: 9 * 60,
    endMinutes: 17 * 60,
  );

  WorkSchedule copyWith({
    bool? enabled,
    Set<int>? days,
    int? startMinutes,
    int? endMinutes,
  }) =>
      WorkSchedule(
        enabled: enabled ?? this.enabled,
        days: days ?? this.days,
        startMinutes: startMinutes ?? this.startMinutes,
        endMinutes: endMinutes ?? this.endMinutes,
      );

  static const _kEnabled = 'work_schedule_enabled';
  static const _kDays = 'work_schedule_days';
  static const _kStart = 'work_schedule_start_min';
  static const _kEnd = 'work_schedule_end_min';

  static Future<WorkSchedule> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDays = prefs.getStringList(_kDays);
    final days = storedDays == null
        ? defaults.days
        : storedDays.map(int.tryParse).whereType<int>().where((d) => d >= 1 && d <= 7).toSet();
    return WorkSchedule(
      enabled: prefs.getBool(_kEnabled) ?? defaults.enabled,
      days: days,
      startMinutes: prefs.getInt(_kStart) ?? defaults.startMinutes,
      endMinutes: prefs.getInt(_kEnd) ?? defaults.endMinutes,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
    await prefs.setStringList(_kDays, (days.toList()..sort()).map((d) => '$d').toList());
    await prefs.setInt(_kStart, startMinutes);
    await prefs.setInt(_kEnd, endMinutes);
  }
}
