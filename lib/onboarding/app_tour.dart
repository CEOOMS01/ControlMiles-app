// Olympus Mont Systems LLC - ControlMiles
// lib/onboarding/app_tour.dart
//
// First-run tour + "What's new" (2026-10-09, owner's request). Researched:
// Motive announces new features inside the app; the common pattern is a SHORT,
// always-skippable tour with progress ("2 of 4") the first time only, and a
// "What's new" shown once per new feature, re-openable from Settings.
//
//  * Tour: 4 cards for the user's kind of account (gig, fleet driver, fleet
//    admin, bus monitor). Only NEW accounts see it (created in the last 14
//    days), once per account on this device. Existing users skip it.
//  * What's new: every feature where the user interacts gets a
//    [FeatureNote] in [kFeatureNotes]. A note shows once, to the accounts it
//    applies to; a brand-new account marks the current notes as seen after
//    its tour (the tour already covers the basics).
//  * Settings -> "Tutorial & what's new" replays both.
//
// Adding a feature: append a FeatureNote with a NEW id (never reuse one) and
// its i18n keys in all 11 languages.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/app_state.dart';

enum TourAudience { gig, fleetDriver, fleetAdmin, monitor }

class TourPage {
  final IconData icon;
  final String titleKey;
  final String bodyKey;
  const TourPage(this.icon, this.titleKey, this.bodyKey);
}

const Map<TourAudience, List<TourPage>> kTours = {
  TourAudience.gig: [
    TourPage(Icons.route_rounded, 'tour_gig_1_title', 'tour_gig_1_body'),
    TourPage(Icons.play_circle_fill_rounded, 'tour_gig_2_title', 'tour_gig_2_body'),
    TourPage(Icons.speed_rounded, 'tour_gig_3_title', 'tour_gig_3_body'),
    TourPage(Icons.description_rounded, 'tour_gig_4_title', 'tour_gig_4_body'),
  ],
  TourAudience.fleetDriver: [
    TourPage(Icons.local_shipping_rounded, 'tour_driver_1_title', 'tour_driver_1_body'),
    TourPage(Icons.fact_check_rounded, 'tour_driver_2_title', 'tour_driver_2_body'),
    TourPage(Icons.play_circle_fill_rounded, 'tour_driver_3_title', 'tour_driver_3_body'),
    TourPage(Icons.report_rounded, 'tour_driver_4_title', 'tour_driver_4_body'),
  ],
  TourAudience.fleetAdmin: [
    TourPage(Icons.business_rounded, 'tour_admin_1_title', 'tour_admin_1_body'),
    TourPage(Icons.group_add_rounded, 'tour_admin_2_title', 'tour_admin_2_body'),
    TourPage(Icons.map_rounded, 'tour_admin_3_title', 'tour_admin_3_body'),
    TourPage(Icons.dashboard_rounded, 'tour_admin_4_title', 'tour_admin_4_body'),
  ],
  TourAudience.monitor: [
    TourPage(Icons.directions_bus_rounded, 'tour_monitor_1_title', 'tour_monitor_1_body'),
    TourPage(Icons.list_alt_rounded, 'tour_monitor_2_title', 'tour_monitor_2_body'),
    TourPage(Icons.palette_rounded, 'tour_monitor_3_title', 'tour_monitor_3_body'),
    TourPage(Icons.timer_rounded, 'tour_monitor_4_title', 'tour_monitor_4_body'),
  ],
};

/// A user-facing feature, announced once in "What's new".
class FeatureNote {
  final String id;
  final Set<TourAudience> audiences;
  final bool schoolOnly;
  final IconData icon;
  final String titleKey;
  final String bodyKey;
  const FeatureNote({
    required this.id,
    required this.audiences,
    this.schoolOnly = false,
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
  });
}

/// Newest last. Never reuse an id.
const List<FeatureNote> kFeatureNotes = [
  FeatureNote(
    id: 'school_day_colors_2026_10',
    audiences: {TourAudience.fleetDriver, TourAudience.monitor},
    schoolOnly: true,
    icon: Icons.palette_rounded,
    titleKey: 'new_school_colors_title',
    bodyKey: 'new_school_colors_body',
  ),
  FeatureNote(
    id: 'school_countdown_2026_10',
    audiences: {TourAudience.fleetDriver, TourAudience.monitor},
    schoolOnly: true,
    icon: Icons.timer_rounded,
    titleKey: 'new_school_countdown_title',
    bodyKey: 'new_school_countdown_body',
  ),
  FeatureNote(
    id: 'school_driving_lock_2026_10',
    audiences: {TourAudience.fleetDriver},
    schoolOnly: true,
    icon: Icons.do_not_touch_rounded,
    titleKey: 'new_school_driving_lock_title',
    bodyKey: 'new_school_driving_lock_body',
  ),
  FeatureNote(
    id: 'tutorial_replay_2026_10',
    audiences: {TourAudience.gig, TourAudience.fleetDriver, TourAudience.fleetAdmin, TourAudience.monitor},
    icon: Icons.school_rounded,
    titleKey: 'new_tutorial_title',
    bodyKey: 'new_tutorial_body',
  ),
];

TourAudience audienceOf(AppState appState) {
  if (appState.isMonitor) return TourAudience.monitor;
  if (appState.isFleetDriver) return TourAudience.fleetDriver;
  if (appState.isFleetAdmin) return TourAudience.fleetAdmin;
  return TourAudience.gig;
}

List<FeatureNote> notesFor(AppState appState) {
  final audience = audienceOf(appState);
  return kFeatureNotes
      .where((n) => n.audiences.contains(audience) && (!n.schoolOnly || appState.isSchoolFleet))
      .toList();
}

class AppTourService {
  static const _newAccountDays = 14;

  static String _uid() => Supabase.instance.client.auth.currentUser?.id ?? 'anon';
  static String _tourKey(TourAudience a) => 'cm_tour_seen_${_uid()}_${a.name}';
  static String _notesKey() => 'cm_features_seen_${_uid()}';

  /// Called once per home screen open: the tour for a new account, else the
  /// notes it hasn't seen.
  static Future<void> maybeShow(BuildContext context) async {
    final appState = context.read<AppState>();
    if (Supabase.instance.client.auth.currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    final audience = audienceOf(appState);
    final notes = notesFor(appState);
    final seen = (prefs.getStringList(_notesKey()) ?? const <String>[]).toSet();

    if (!(prefs.getBool(_tourKey(audience)) ?? false)) {
      await prefs.setBool(_tourKey(audience), true);
      final created = appState.accountCreatedAt;
      final isNew = created != null && DateTime.now().difference(created).inDays <= _newAccountDays;
      if (isNew) {
        // The tour covers today's basics: today's notes count as seen.
        await prefs.setStringList(_notesKey(), {...seen, ...notes.map((n) => n.id)}.toList());
        if (!context.mounted) return;
        await showTour(context, audience);
        return;
      }
    }

    final unseen = notes.where((n) => !seen.contains(n.id)).toList();
    if (unseen.isEmpty) return;
    await prefs.setStringList(_notesKey(), {...seen, ...unseen.map((n) => n.id)}.toList());
    if (!context.mounted) return;
    await showWhatsNew(context, unseen);
  }

  /// Settings -> "Tutorial & what's new".
  static Future<void> replay(BuildContext context) async {
    final appState = context.read<AppState>();
    await showTour(context, audienceOf(appState));
    if (!context.mounted) return;
    final notes = notesFor(appState);
    if (notes.isNotEmpty) await showWhatsNew(context, notes);
  }

  static Future<void> showTour(BuildContext context, TourAudience audience) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'tour',
      pageBuilder: (_, _, _) => _TourDialog(pages: kTours[audience]!),
    );
  }

  static Future<void> showWhatsNew(BuildContext context, List<FeatureNote> notes) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _WhatsNewSheet(notes: notes),
    );
  }
}

/// Wrap a home screen: shows the tour / what's new after its first frame.
class AppTourGate extends StatefulWidget {
  final Widget child;
  const AppTourGate({super.key, required this.child});

  @override
  State<AppTourGate> createState() => _AppTourGateState();
}

class _AppTourGateState extends State<AppTourGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Let the profile (role, fleet type, account age) settle first.
      await context.read<AppState>().fetchUserProfile();
      if (mounted) await AppTourService.maybeShow(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _TourDialog extends StatefulWidget {
  final List<TourPage> pages;
  const _TourDialog({required this.pages});

  @override
  State<_TourDialog> createState() => _TourDialogState();
}

class _TourDialogState extends State<_TourDialog> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final last = _index == widget.pages.length - 1;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(
                    appState.tr('tour_step').replaceFirst('{n}', '${_index + 1}').replaceFirst('{total}', '${widget.pages.length}'),
                    style: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF6B6250), fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(context), child: Text(appState.tr('tour_skip'))),
              ],
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  for (final p in widget.pages)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(color: primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                            child: Icon(p.icon, size: 64, color: primary),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            appState.tr(p.titleKey),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF2E281F),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            appState.tr(p.bodyKey),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, height: 1.45, color: isDark ? Colors.white70 : const Color(0xFF574F40)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? primary : primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => last
                      ? Navigator.pop(context)
                      : _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text(appState.tr(last ? 'tour_done' : 'tour_next')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhatsNewSheet extends StatelessWidget {
  final List<FeatureNote> notes;
  const _WhatsNewSheet({required this.notes});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF574F40);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(appState.tr('whats_new_title'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor)),
            const SizedBox(height: 14),
            for (final n in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                      child: Icon(n.icon, color: primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(appState.tr(n.titleKey),
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: textColor)),
                          const SizedBox(height: 4),
                          Text(appState.tr(n.bodyKey), style: TextStyle(height: 1.4, color: subTextColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            FilledButton(onPressed: () => Navigator.pop(context), child: Text(appState.tr('whats_new_got_it'))),
          ],
        ),
      ),
    );
  }
}
