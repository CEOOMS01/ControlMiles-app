// Olympus Mont Systems LLC - ControlMiles
// lib/views/auto_schedule_screen.dart
//
// "When can the app track by itself?" (General mode, 1.3.18). Off by default:
// the phone starts a trip whenever it moves. If the driver turns it on, trips
// only start on the chosen days between the chosen hours. A trip already in
// progress is never cut off by the schedule, and gig-app mode ignores it.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';

const _dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

/// "Mon, Tue · 8:00 AM - 6:00 PM", or the "always" text when nothing is set.
String autoScheduleSummary(AppState s, BuildContext context) {
  if (!s.hasAutoSchedule) return s.tr('auto_schedule_value_always');
  final days = (s.autoScheduleDays.toList()..sort())
      .map((d) => s.tr(_dayKeys[d - 1]).substring(0, 3))
      .join(', ');
  String t(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60).format(context);
  return '$days · ${t(s.autoScheduleStartMinute)} - ${t(s.autoScheduleEndMinute)}';
}

class AutoScheduleScreen extends StatefulWidget {
  const AutoScheduleScreen({super.key});

  @override
  State<AutoScheduleScreen> createState() => _AutoScheduleScreenState();
}

class _AutoScheduleScreenState extends State<AutoScheduleScreen> {
  late bool _enabled;
  late Set<int> _days;
  late int _start;
  late int _end;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _enabled = s.hasAutoSchedule;
    _days = s.hasAutoSchedule ? {...s.autoScheduleDays} : {1, 2, 3, 4, 5};
    _start = s.autoScheduleStartMinute;
    _end = s.autoScheduleEndMinute;
  }

  Future<void> _save() async {
    final s = context.read<AppState>();
    await s.setAutoSchedule(days: _enabled ? _days : null, startMinute: _start, endMinute: _end);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickTime(bool start) async {
    final cur = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
    );
    if (picked == null) return;
    setState(() {
      final m = picked.hour * 60 + picked.minute;
      if (start) {
        _start = m;
      } else {
        _end = m;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final theme = Theme.of(context);
    String t(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60).format(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.tr('auto_schedule_title'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(s.tr('auto_schedule_hint'), style: TextStyle(fontSize: 14, height: 1.4, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7))),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.tr('auto_schedule_only_selected'), style: const TextStyle(fontWeight: FontWeight.w700)),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          if (_enabled) ...[
            const SizedBox(height: 8),
            Text(s.tr('auto_schedule_days'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(s.tr(_dayKeys[d - 1]).substring(0, 3)),
                    selected: _days.contains(d),
                    onSelected: (v) => setState(() => v ? _days.add(d) : _days.remove(d)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.tr('auto_schedule_from')),
              trailing: Text(t(_start), style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => _pickTime(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.tr('auto_schedule_to')),
              trailing: Text(t(_end), style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => _pickTime(false),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: (_enabled && _days.isEmpty) ? null : _save,
              child: Text(s.tr('address_save')),
            ),
          ),
        ],
      ),
    );
  }
}
