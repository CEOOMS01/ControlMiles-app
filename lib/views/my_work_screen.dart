// Olympus Mont Systems LLC - ControlMiles
// lib/views/my_work_screen.dart
//
// My work (2026-11-09): what the driver does, when the app records, and how General
// trips classify themselves. Opened from the side menu.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../theme/cm_colors.dart';
import 'auto_schedule_screen.dart';
import 'regular_trips_screen.dart';
import 'work_hours_screen.dart';
import 'work_type_screen.dart';
import '../widgets/cm_dark_app_bar.dart';
import '../onboarding/product_tour.dart';

class MyWorkScreen extends StatefulWidget {
  const MyWorkScreen({super.key});

  @override
  State<MyWorkScreen> createState() => _MyWorkScreenState();
}

class _MyWorkScreenState extends State<MyWorkScreen> {
  final _scope = TourScope('my_work');
  final _tHours = GlobalKey();
  final _tRegular = GlobalKey();
  bool _tourChecked = false;

  @override
  void initState() {
    super.initState();
    _scope.register();
  }

  @override
  void dispose() {
    _scope.unregister();
    super.dispose();
  }

  // Premium only: Basic has just the work type here, nothing to explain.
  void _startTour({bool force = false}) {
    ProductTour.run(context, id: TourIds.myWork, scope: _scope.name, keys: [_tHours, _tRegular], force: force);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!_tourChecked) {
      _tourChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startTour();
      });
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : CmColors.ink;
    final dim = isDark ? Colors.white60 : CmColors.inkDim;

    Widget row(IconData icon, String title, String subtitle, Widget screen) => ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: dim)),
          trailing: Icon(Icons.chevron_right_rounded, color: dim),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
        );

    final rows = <Widget>[
      row(
        Icons.badge_outlined,
        s.tr('work_type_setting'),
        s.tr(switch (s.workMode) {
          'gig' => 'work_type_value_gig',
          'general' => 'work_type_value_general',
          _ => 'work_type_value_all',
        }),
        const WorkTypeScreen(dismissible: true),
      ),
      // The days and hours the phone may start trips by itself. Basic does not.
      if (s.premiumEntitled && s.workMode == 'general')
        row(Icons.schedule_rounded, s.tr('auto_schedule_title'), autoScheduleSummary(s, context), const AutoScheduleScreen()),
      if (s.premiumEntitled && s.workMode != 'gig') ...[
        TourTarget(
          showcaseKey: _tHours,
          scope: _scope.name,
          step: 1,
          total: 2,
          titleKey: 'work_hours_title',
          bodyKey: 'ptour_work_hours_body',
          radius: BorderRadius.zero,
          child: row(Icons.event_available_outlined, s.tr('work_hours_title'), s.tr('work_hours_row_hint'), const WorkHoursScreen()),
        ),
        TourTarget(
          showcaseKey: _tRegular,
          scope: _scope.name,
          step: 2,
          total: 2,
          titleKey: 'regular_trips_title',
          bodyKey: 'ptour_regular_body',
          radius: BorderRadius.zero,
          child: row(Icons.repeat_rounded, s.tr('regular_trips_title'), s.tr('regular_trips_row_hint'), const RegularTripsScreen()),
        ),
      ],
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12100C) : CmColors.cream,
      appBar: cmDarkAppBar(
        context,
        s.tr('my_work_title'),
        actions: [if (s.premiumEntitled && s.workMode != 'gig') TourHelpButton(onPressed: () => _startTour(force: true))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1812) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) Divider(height: 1, indent: 56, color: isDark ? const Color(0xFF2E281F) : CmColors.sand),
                    rows[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
