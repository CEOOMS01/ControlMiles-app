// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/work_mode_bar.dart
//
// General / Gig apps switch on the Dashboard (2026-11-05), in place of the old
// automatic-detection slider. The driver changes how they work without going to
// Settings, and edits which apps count. Premium accounts get automatic
// detection to follow the choice (see AutoTripDetectionService.ensureArmed).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../tracking/auto_trip_detection_service.dart';
import 'gig_app_shift_selector_sheet.dart';

class WorkModeBar extends StatelessWidget {
  const WorkModeBar({super.key});

  bool _hasApps(AppState s) => s.selectedGigAppIds.any((id) => id != 'custom');

  Future<void> _choose(BuildContext context, AppState s, String mode) async {
    if (s.workMode == mode) return;
    if (mode == 'gig' && !_hasApps(s)) {
      await showGigAppShiftSelectorSheet(context);
      if (!_hasApps(s)) return;
    }
    await s.setWorkMode(mode);
    if (context.mounted) {
      await AutoTripDetectionService.ensureArmed(context, s, force: true);
    }
  }

  Future<void> _editApps(BuildContext context, AppState s) async {
    await showGigAppShiftSelectorSheet(context);
    if (!_hasApps(s) && context.mounted) await _choose(context, s, 'general');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final mode = s.workMode;
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'general', label: Text(s.tr('work_mode_general'))),
              ButtonSegment(value: 'gig', label: Text(s.tr('work_mode_apps'))),
            ],
            selected: {if (mode == 'general' || mode == 'gig') mode!},
            onSelectionChanged: (v) {
              if (v.isNotEmpty) _choose(context, s, v.first);
            },
          ),
        ),
        if (mode == 'gig')
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _editApps(context, s),
              icon: Icon(Icons.edit_outlined, size: 16, color: primary),
              label: Text(s.tr('work_mode_edit_apps')),
            ),
          ),
      ],
    );
  }
}
