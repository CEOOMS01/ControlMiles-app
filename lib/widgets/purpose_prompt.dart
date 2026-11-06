// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/purpose_prompt.dart
//
// "What was this trip for?" (2026-11-05). General trips are started by the phone
// itself, so the purpose is asked once the trip is over: the dashboard shows
// this sheet for the most recent closed General trip that still has none.
// Gig-app trips never ask (they are saved as Business). The End trip button asks
// at once (askNow); trips answered "later" are finished from History
// (categorizeAll). A closed trip's purpose can always be changed.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/app_state.dart';
import '../models/gig_app.dart';
import '../tracking/tracking_controller.dart';
import 'trip_review_sheet.dart';

class PurposePrompt {
  PurposePrompt._();

  static const _business = ['business', 'delivery', 'errand', 'client', 'travel'];
  static const _personal = ['work', 'medical', 'charitable', 'moving', 'education', 'personal'];
  static const _rated = {'medical', 'charitable', 'moving'};
  static const _kSkipped = 'purpose_prompt_skipped';
  static bool _showing = false;

  /// Shows the question when a closed General trip is waiting for its purpose.
  static Future<void> askIfPending(BuildContext context) async {
    if (_showing) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    _showing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final skipped = prefs.getStringList(_kSkipped) ?? <String>[];
      final since = DateTime.now().toUtc().subtract(const Duration(days: 3)).toIso8601String();
      final rows = await Supabase.instance.client
          .from('session_sections')
          .select('id, total_miles')
          .eq('user_id', userId)
          .eq('gig_app', 'custom')
          .eq('section_status', 'closed')
          .isFilter('irs_purpose', null)
          .gte('end_time', since)
          .order('end_time', ascending: false)
          .limit(5);
      final pending = (rows as List).map((r) => r['id'] as String).where((id) => !skipped.contains(id)).toList();
      TrackingController.purposePendingSectionId = null;
      if (pending.isEmpty || !context.mounted) return;

      final sectionId = pending.first;
      final saved = await TripReviewSheet.show(context, sectionId: sectionId);
      if (!saved) {
        // "Later": do not ask about this trip again here; it stays editable from the list.
        await prefs.setStringList(_kSkipped, [...skipped, sectionId].take(50).toList());
      }
    } catch (_) {
      // Best effort: the trip is saved either way.
    } finally {
      _showing = false;
    }
  }

  /// Right after the End trip button in General mode: asks for the trip that
  /// just closed. "Categorize later" leaves it for the History list.
  static Future<void> askNow(BuildContext context, String sectionId) async {
    if (_showing) return;
    _showing = true;
    try {
      final saved = await TripReviewSheet.show(context, sectionId: sectionId);
      if (!saved) {
        // Later: the dashboard must not ask again, the trips list still has it.
        final prefs = await SharedPreferences.getInstance();
        final skipped = prefs.getStringList(_kSkipped) ?? <String>[];
        await prefs.setStringList(_kSkipped, [...skipped, sectionId].take(50).toList());
      }
    } catch (_) {
      // Best effort: the trip is saved either way.
    } finally {
      _showing = false;
    }
  }

  /// General trips still without a category, newest first.
  static Future<List<Map<String, dynamic>>> uncategorized() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await Supabase.instance.client
        .from('session_sections')
        .select('id, start_time')
        .eq('user_id', userId)
        .eq('gig_app', 'custom')
        .eq('section_status', 'closed')
        .isFilter('irs_purpose', null)
        .order('start_time', ascending: false)
        .limit(200);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// History: walks through every uncategorized General trip, one after the
  /// other. Closing the sheet (Categorize later) stops the walk.
  static Future<void> categorizeAll(BuildContext context) async {
    if (_showing) return;
    _showing = true;
    try {
      final trips = await uncategorized();
      for (var i = 0; i < trips.length; i++) {
        if (!context.mounted) return;
        final id = trips[i]['id'] as String;
        final start = DateTime.tryParse('${trips[i]['start_time']}')?.toLocal();
        final when = start == null ? '' : ' · ${DateFormat('MMM d, hh:mm a').format(start)}';
        final saved = await TripReviewSheet.show(context, sectionId: id, subtitle: '${i + 1} / ${trips.length}$when');
        if (!saved) return;
      }
    } catch (_) {
      // Best effort: what was answered is saved.
    } finally {
      _showing = false;
    }
  }

  /// The purposes sheet alone (History uses it to correct a trip's purpose).
  /// Null when it is dismissed.
  static Future<String?> choose(BuildContext context) => showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _sheet(sheetContext),
      );

  static Widget _sheet(BuildContext context, {String? subtitle, VoidCallback? onEditAddress}) {
    final appState = context.read<AppState>();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6);

    Widget group(String key) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(appState.tr(key), style: TextStyle(fontSize: 12, color: muted)),
          ),
        );

    Widget row(String id) => ListTile(
          title: Text(appState.tr(IrsPurposeCatalog.labelKeyFor(id) ?? id)),
          trailing: _rated.contains(id)
              ? Text('\$', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary))
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          onTap: () => Navigator.pop(context, id),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(appState.tr('purpose_prompt_title'), style: theme.textTheme.titleLarge),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle, style: TextStyle(fontSize: 12, color: muted)),
                ),
              if (onEditAddress != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onEditAddress,
                    icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                    label: Text(appState.tr('purpose_edit_address')),
                  ),
                ),
              const SizedBox(height: 4),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    group('purpose_group_business'),
                    ..._business.map(row),
                    group('purpose_group_personal'),
                    ..._personal.map(row),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(appState.tr('purpose_prompt_later')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
