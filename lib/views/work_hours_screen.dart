// Olympus Mont Systems LLC - ControlMiles
// lib/views/work_hours_screen.dart
//
// Work Hours (2026-11-09): classifies General trips by the time they started. This
// is not "Automatic tracking hours": that one decides whether the app records at
// all, this one only names the trip. A regular trip wins over it.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../services/trip_rules_service.dart';
import '../widgets/brand_loader.dart';
import '../widgets/trip_edits.dart';
import '../widgets/cm_dark_app_bar.dart';

const _dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

class WorkHoursScreen extends StatefulWidget {
  const WorkHoursScreen({super.key});

  @override
  State<WorkHoursScreen> createState() => _WorkHoursScreenState();
}

class _WorkHoursScreenState extends State<WorkHoursScreen> {
  TripClassificationSettings? _settings;
  bool _failed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await TripRulesService.loadSettings();
      if (mounted) setState(() => _settings = settings);
    } catch (e) {
      debugPrint('[WorkHours] load failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _pickTime(bool start) async {
    final settings = _settings!;
    final cur = start ? settings.workStartMinute : settings.workEndMinute;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
    );
    if (picked == null) return;
    setState(() {
      final m = picked.hour * 60 + picked.minute;
      if (start) {
        settings.workStartMinute = m;
      } else {
        settings.workEndMinute = m;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await TripRulesService.saveSettings(_settings!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        TripEdits.showError(context, e);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final theme = Theme.of(context);
    final muted = TextStyle(fontSize: 14, height: 1.4, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7));
    final settings = _settings;
    String t(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60).format(context);

    return Scaffold(
      appBar: cmDarkAppBar(context, s.tr('work_hours_title')),
      body: settings == null
          ? Center(child: _failed ? Text(s.tr('error')) : const BrandLoader(size: 36))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(s.tr('work_hours_hint'), style: muted),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.tr('work_hours_inside'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(s.tr('work_hours_inside_hint')),
                  value: settings.workHoursInside,
                  onChanged: (v) => setState(() => settings.workHoursInside = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.tr('work_hours_outside'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(s.tr('work_hours_outside_hint')),
                  value: settings.workHoursOutside,
                  onChanged: (v) => setState(() => settings.workHoursOutside = v),
                ),
                if (settings.workHoursInside || settings.workHoursOutside) ...[
                  const SizedBox(height: 8),
                  Text(s.tr('auto_schedule_days'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        FilterChip(
                          label: Text(s.tr(_dayKeys[d - 1]).substring(0, 3)),
                          selected: settings.workDays.contains(d),
                          onSelected: (v) => setState(() => v ? settings.workDays.add(d) : settings.workDays.remove(d)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.tr('auto_schedule_from')),
                    trailing: Text(t(settings.workStartMinute), style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () => _pickTime(true),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.tr('auto_schedule_to')),
                    trailing: Text(t(settings.workEndMinute), style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () => _pickTime(false),
                  ),
                ],
                const SizedBox(height: 12),
                Text(s.tr('trip_rules_general_only'), style: muted),
                const SizedBox(height: 8),
                Text(s.tr('work_hours_priority_note'), style: muted),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ||
                            ((settings.workHoursInside || settings.workHoursOutside) && settings.workDays.isEmpty)
                        ? null
                        : _save,
                    child: Text(s.tr('address_save')),
                  ),
                ),
              ],
            ),
    );
  }
}
