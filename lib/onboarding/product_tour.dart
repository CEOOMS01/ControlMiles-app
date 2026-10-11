// Olympus Mont Systems LLC - ControlMiles
// lib/onboarding/product_tour.dart
//
// Gig app product tour (2026-10-11, owner's request: "como las empresas #1
// del mercado"). Replaces the gig app's old 4-card carousel + "What's new".
// Researched 2026 guidance (Usertour, Appcues-style coach marks, MileIQ's
// first-drive flow): highlight the REAL control, one short sentence per
// step, "2 of 5" + an always-visible Skip; teach in context (each screen's
// tips the first time it's opened), never all upfront; show each tip once,
// re-playable on demand.
//
//  * Welcome sheet once per account: "Show me around" / "Not now".
//  * Dashboard: 6 spotlights over the real controls.
//  * Contextual: Reports, History and Settings show their own tips the
//    first time they're opened; a "?" in their app bar replays them.
//  * Milestone: after the first finished trip, History is highlighted.
//  * Settings -> "App tour" replays everything.
//
// Seen tours are kept per account on the device and in
// user_onboarding.tour_seen (server), so a reinstall doesn't repeat them.
// Texts: English + Spanish (what the category does -- MileIQ is English
// only, Gridwise EN/ES, Everlance EN/ES/FR); other languages fall back to
// English.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/app_state.dart';

/// Tour ids. Bump the suffix to show a tour again after a big redesign.
class TourIds {
  static const welcome = 'gig_welcome_v1';
  static const dashboard = 'gig_dashboard_v1';
  static const reports = 'gig_reports_v1';
  static const history = 'gig_history_v1';
  static const settings = 'gig_settings_v1';
  static const firstTrip = 'gig_first_trip_v1';
  static const all = [welcome, dashboard, reports, history, settings, firstTrip];
}

class ProductTour {
  ProductTour._();

  static String _uid() => Supabase.instance.client.auth.currentUser?.id ?? 'anon';
  static String _key() => 'cm_product_tour_seen_${_uid()}';

  static Set<String>? _cache;
  static String? _cacheUid;

  /// Seen tour ids: the device's list merged with the server's.
  static Future<Set<String>> _seen() async {
    if (_cache != null && _cacheUid == _uid()) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final local = (prefs.getStringList(_key()) ?? const <String>[]).toSet();
    var remote = <String>{};
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final row = await Supabase.instance.client
            .from('user_onboarding')
            .select('tour_seen')
            .eq('user_id', user.id)
            .maybeSingle();
        remote = {for (final v in (row?['tour_seen'] as List? ?? const [])) v as String};
      } catch (e) {
        // Column not there yet / offline: the device's list is enough.
        debugPrint('[ProductTour] server read skipped: $e');
      }
    }
    _cache = {...local, ...remote};
    _cacheUid = _uid();
    return _cache!;
  }

  static Future<bool> isSeen(String id) async => (await _seen()).contains(id);

  static Future<void> markSeen(String id) async {
    final seen = {...await _seen(), id};
    _cache = seen;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(), seen.toList());
    await _push(seen);
  }

  /// Settings -> "App tour": everything shows again.
  static Future<void> resetAll() async {
    _cache = <String>{};
    _cacheUid = _uid();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key());
    await _push(<String>{});
  }

  static Future<void> _push(Set<String> seen) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('user_onboarding').upsert(
        {'user_id': user.id, 'tour_seen': seen.toList()},
        onConflict: 'user_id',
      );
    } catch (e) {
      debugPrint('[ProductTour] server write skipped: $e');
    }
  }

  /// Starts [keys] in [scope] once (marks [id] seen), or always when
  /// [force] (the "?" replay). Targets not on screen are skipped.
  static Future<void> run(
    BuildContext context, {
    required String id,
    required String scope,
    required List<GlobalKey> keys,
    bool force = false,
  }) async {
    if (!force && await isSeen(id)) return;
    if (!context.mounted) return;
    final present = keys.where((k) => k.currentContext != null).toList();
    if (present.isEmpty) return;
    await markSeen(id);
    ShowcaseView.getNamed(scope).startShowCase(present);
  }

  /// Welcome sheet; true = "Show me around".
  static Future<bool> showWelcome(BuildContext context) async {
    await markSeen(TourIds.welcome);
    if (!context.mounted) return false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _WelcomeSheet(),
    );
    return result ?? false;
  }
}

/// Registers a showcase scope for a screen's lifetime. Call [register] in
/// initState and [unregister] in dispose.
class TourScope {
  final String name;
  TourScope(this.name);

  void register() => ShowcaseView.register(
        scope: name,
        enableAutoScroll: true,
        skipIfTargetNotPresent: true,
        blurValue: 0,
        overlayOpacity: 0.72,
      );

  void unregister() {
    try {
      ShowcaseView.getNamed(name).unregister();
    } catch (_) {}
  }
}

/// Wraps a real control: dims the screen around it and shows a ControlMiles
/// tooltip card (step n of total, title, one sentence, Skip / Next).
class TourTarget extends StatelessWidget {
  final GlobalKey showcaseKey;
  final String scope;
  final int step;
  final int total;
  final String titleKey;
  final String bodyKey;
  final Widget child;
  final BorderRadius radius;
  final TooltipPosition? position;

  const TourTarget({
    super.key,
    required this.showcaseKey,
    required this.scope,
    required this.step,
    required this.total,
    required this.titleKey,
    required this.bodyKey,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(16)),
    this.position,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Showcase.withWidget(
      key: showcaseKey,
      scope: scope,
      targetBorderRadius: radius,
      tooltipPosition: position,
      disableBarrierInteraction: true,
      container: SizedBox(
        width: width - 48 > 340 ? 340 : width - 48,
        child: _TourCard(
          scope: scope,
          step: step,
          total: total,
          titleKey: titleKey,
          bodyKey: bodyKey,
        ),
      ),
      child: child,
    );
  }
}

class _TourCard extends StatelessWidget {
  final String scope;
  final int step;
  final int total;
  final String titleKey;
  final String bodyKey;

  const _TourCard({
    required this.scope,
    required this.step,
    required this.total,
    required this.titleKey,
    required this.bodyKey,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final last = step >= total;
    final view = ShowcaseView.getNamed(scope);
    return Material(
      color: isDark ? const Color(0xFF1C1812) : Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (total > 1)
              Text(
                appState.tr('tour_step').replaceFirst('{n}', '$step').replaceFirst('{total}', '$total'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primary),
              ),
            const SizedBox(height: 4),
            Text(
              appState.tr(titleKey),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF2E281F),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              appState.tr(bodyKey),
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDark ? Colors.white70 : const Color(0xFF574F40),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (!last)
                  TextButton(
                    onPressed: view.dismiss,
                    child: Text(appState.tr('tour_skip')),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: last ? view.dismiss : () => view.next(),
                  child: Text(appState.tr(last ? 'tour_done' : 'tour_next')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeSheet extends StatelessWidget {
  const _WelcomeSheet();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo_controlmiles.png', height: 64),
            const SizedBox(height: 16),
            Text(
              appState.tr('ptour_welcome_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF2E281F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              appState.tr('ptour_welcome_body'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: isDark ? Colors.white70 : const Color(0xFF574F40),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(appState.tr('ptour_welcome_start')),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(appState.tr('ptour_welcome_later')),
            ),
          ],
        ),
      ),
    );
  }
}

/// "?" for an app bar: replays that screen's tips.
class TourHelpButton extends StatelessWidget {
  final VoidCallback onPressed;
  const TourHelpButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.read<AppState>().tr('ptour_help'),
      icon: const Icon(Icons.help_outline_rounded),
      onPressed: onPressed,
    );
  }
}
