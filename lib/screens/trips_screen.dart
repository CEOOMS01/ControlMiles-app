// Olympus Mont Systems LLC - ControlMiles
// lib/screens/trips_screen.dart
//
// The trips list (2026-11-06): month summary, a "No category" tab for the trips that
// still need one, and one card per trip (the same card as the pop-up over the
// Dashboard when a trip ends). Not wired to a route yet.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/irs_rates.dart';
import '../i18n/app_texts.dart';
import '../logic/app_state.dart';
import '../models/gig_app.dart';
import '../theme/cm_colors.dart';
import '../widgets/brand_loader.dart';
import '../widgets/purpose_prompt.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_edits.dart';

enum _Filter { unclassified, all, summary }

class TripsScreen extends StatefulWidget {
  /// Rows in the shape the server returns (a session with `session_sections`), to draw
  /// the page without a connection -- used by the layout test.
  final List<Map<String, dynamic>>? previewRows;
  const TripsScreen({super.key, this.previewRows});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  bool _loading = true;
  List<TripData> _trips = [];
  _Filter _filter = _Filter.all;
  String? _month; // 'yyyy-MM'
  final Set<String> _open = {};
  Set<String> _adminOrgIds = {};

  static const _businessGroup = {'business', 'delivery', 'errand', 'client', 'travel'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── data ────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    final preview = widget.previewRows;
    if (preview != null) {
      _apply(preview, const []);
      return;
    }
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final since = DateTime.now().toUtc().subtract(const Duration(days: 365));
      final data = await Supabase.instance.client
          .from('sessions')
          .select('*, session_sections(*)')
          .eq('user_id', userId)
          // Personal trips only: fleet trips live in ControlMiles Fleet.
          .isFilter('organization_id', null)
          .gte('start_time', since.toIso8601String())
          .order('start_time', ascending: false);

      final adminRows = await Supabase.instance.client
          .from('organization_members')
          .select('organization_id')
          .eq('user_id', userId)
          .eq('is_active', true)
          .inFilter('member_role', ['owner', 'admin']);

      _apply((data as List).cast<Map<String, dynamic>>(), adminRows as List);
    } catch (e) {
      debugPrint('[TripsScreen] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(List<Map<String, dynamic>> data, List adminRows) {
    // The trip being recorded is not a finished trip.
    final trips = [
      for (final row in data)
        if (TripData.fromRow(row).session.isClosed) TripData.fromRow(row),
    ];
    if (!mounted) return;
    setState(() {
      _trips = trips;
      _adminOrgIds = {for (final r in adminRows) r['organization_id'] as String};
      _month ??= trips.isEmpty ? null : _monthKey(trips.first.start);
      _loading = false;
    });
  }

  String _monthKey(DateTime? d) => d == null ? '' : DateFormat('yyyy-MM').format(d.toLocal());

  List<String> get _months {
    final keys = <String>{for (final t in _trips) _monthKey(t.start)}..remove('');
    return keys.toList()..sort((a, b) => b.compareTo(a));
  }

  List<TripData> get _monthTrips => _trips.where((t) => _monthKey(t.start) == _month).toList();
  List<TripData> get _pending => _trips.where((t) => t.needsCategory).toList();

  // ── actions ─────────────────────────────────────────────────────────────

  Future<void> _purpose(TripData t, String purpose) async {
    if (await TripEdits.setPurpose(context, t, purpose) && mounted) setState(() {});
  }

  Future<void> _more(TripData t) async {
    final picked = await PurposePrompt.choose(context);
    if (picked != null) await _purpose(t, picked);
  }

  Future<void> _categorizeAll() async {
    await PurposePrompt.categorizeAll(context);
    if (mounted) _load();
  }

  Future<void> _delete(TripData trip) async {
    final appState = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appState.tr('delete_trip_confirm_title')),
        content: Text(appState.tr('delete_trip_confirm_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(appState.tr('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(appState.tr('delete_trip')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final rows = await Supabase.instance.client.from('sessions').delete().eq('id', trip.session.id).select('id');
      // RLS refuses by deleting nothing, not by erroring.
      if ((rows as List).isEmpty) {
        throw const PostgrestException(message: 'Not allowed to delete this trip', code: '42501');
      }
      if (!mounted) return;
      setState(() => _trips.remove(trip));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.tr('delete_trip_success'))));
    } catch (e) {
      if (mounted) TripEdits.showError(context, e);
    }
  }

  bool _canDelete(TripData t) => t.session.organizationId == null || _adminOrgIds.contains(t.session.organizationId);

  // ── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? CmColors.night : CmColors.cream,
      appBar: AppBar(
        title: Text(s.tr('history').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: dark ? CmColors.nightCard : const Color(0xFF2E281F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: BrandLoader())
          : _trips.isEmpty
              ? _empty(s, dark)
              : RefreshIndicator(onRefresh: _load, child: _content(s, dark)),
    );
  }

  Widget _empty(AppState s, bool dark) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.route_rounded, size: 48, color: dark ? Colors.white38 : CmColors.inkDim),
              const SizedBox(height: 12),
              Text(s.tr('trips_empty'), textAlign: TextAlign.center, style: TextStyle(color: dark ? Colors.white70 : CmColors.inkDim, height: 1.4)),
            ],
          ),
        ),
      );

  Widget _content(AppState s, bool dark) {
    final month = _monthTrips;
    final visible = switch (_filter) {
      _Filter.unclassified => _pending,
      _Filter.all => month,
      _Filter.summary => <TripData>[],
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        _monthHeader(s, dark, month),
        const SizedBox(height: 12),
        _filters(s),
        const SizedBox(height: 12),
        if (_filter == _Filter.summary)
          _summary(s, dark, month)
        else if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              s.tr(_filter == _Filter.unclassified ? 'trips_all_categorized' : 'trips_none_this_month'),
              textAlign: TextAlign.center,
              style: TextStyle(color: dark ? Colors.white60 : CmColors.inkDim),
            ),
          )
        else ...[
          if (_filter == _Filter.unclassified)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton.icon(
                onPressed: _categorizeAll,
                icon: const Icon(Icons.label_outline_rounded, size: 18),
                label: Text(s.tr('trips_categorize_one_by_one')),
              ),
            ),
          for (final t in visible)
            TripCard(
              trip: t,
              onPurpose: (p) => _purpose(t, p),
              onMore: () => _more(t),
              onEditAddress: () async {
                if (await TripEdits.editAddresses(context, t) && mounted) setState(() {});
              },
              onNote: () async {
                if (await TripEdits.editNote(context, t) && mounted) setState(() {});
              },
              onDelete: _canDelete(t) ? () => _delete(t) : null,
              detailsOpen: _open.contains(t.session.id),
              onToggleDetails: () => setState(() => _open.contains(t.session.id) ? _open.remove(t.session.id) : _open.add(t.session.id)),
            ),
        ],
      ],
    );
  }

  Widget _monthHeader(AppState s, bool dark, List<TripData> month) {
    final miles = month.fold<double>(0, (a, t) => a + t.miles);
    final money = month.fold<double>(0, (a, t) => a + t.deduction);
    final lang = s.currentLanguage.code;
    final label = _month == null ? '' : DateFormat('MMMM yyyy', lang).format(DateTime.parse('${_month!}-01'));

    Widget stat(String title, String value, {Color? tint, Color? fg, bool note = false}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: tint ?? (dark ? CmColors.nightCard : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dark ? CmColors.ink : CmColors.sand),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: fg ?? (dark ? Colors.white60 : CmColors.inkDim))),
                    ),
                    if (note) ...[
                      const SizedBox(width: 3),
                      InkWell(
                        onTap: () => showDeductionNote(context),
                        child: Icon(Icons.help_outline_rounded, size: 14, color: fg),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: fg ?? (dark ? Colors.white : CmColors.ink))),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PopupMenuButton<String>(
          onSelected: (v) => setState(() => _month = v),
          itemBuilder: (_) => [
            for (final m in _months) PopupMenuItem(value: m, child: Text(DateFormat('MMMM yyyy', lang).format(DateTime.parse('$m-01')))),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: dark ? Colors.white : CmColors.ink)),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, color: dark ? Colors.white70 : CmColors.inkDim),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            stat(s.tr('trips_stat_trips'), '${month.length}'),
            const SizedBox(width: 8),
            stat('${s.tr('trips_stat_distance')} (${tripUnit(s)})', tripDistance(s, miles)),
            const SizedBox(width: 8),
            stat(
              s.tr('trips_stat_deduction'),
              tripMoney(money),
              tint: dark ? const Color(0xFF12304A) : const Color(0xFFE6F1FB),
              fg: dark ? const Color(0xFF85B7EB) : const Color(0xFF185FA5),
              note: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _filters(AppState s) {
    final pending = _pending.length;
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget chip(_Filter f, String text) {
      final on = _filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(text),
          selected: on,
          onSelected: (_) => setState(() => _filter = f),
          showCheckmark: false,
          selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: dark ? 0.35 : 0.14),
          labelStyle: TextStyle(fontWeight: on ? FontWeight.w800 : FontWeight.w600),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(_Filter.unclassified, '${s.tr('trips_filter_unclassified')}${pending > 0 ? ' · $pending' : ''}'),
          chip(_Filter.all, s.tr('trips_filter_all')),
          chip(_Filter.summary, s.tr('trips_filter_summary')),
        ],
      ),
    );
  }

  /// Month totals by category.
  Widget _summary(AppState s, bool dark, List<TripData> month) {
    final miles = <String, double>{};
    final money = <String, double>{};
    for (final t in month) {
      for (final sec in t.sections) {
        final key = sec.gigApp == 'custom' ? (sec.irsPurpose ?? 'none') : 'business';
        final group = _businessGroup.contains(key) ? 'business' : key;
        miles[group] = (miles[group] ?? 0) + sec.totalMiles;
        final rate = ratePerMileCentsForPurpose(sec.gigApp == 'custom' ? sec.irsPurpose : 'business', sec.startTime);
        money[group] = (money[group] ?? 0) + sec.totalMiles * rate / 100.0;
      }
    }
    final keys = miles.keys.toList()..sort((a, b) => (money[b] ?? 0).compareTo(money[a] ?? 0));
    if (keys.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Text(s.tr('trips_none_this_month'), textAlign: TextAlign.center, style: TextStyle(color: dark ? Colors.white60 : CmColors.inkDim)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: dark ? CmColors.nightCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? CmColors.ink : CmColors.sand),
      ),
      child: Column(
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) Divider(height: 1, color: dark ? CmColors.ink : CmColors.sand),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      keys[i] == 'none' ? s.tr('trips_no_category') : s.tr(IrsPurposeCatalog.labelKeyFor(keys[i]) ?? keys[i]),
                      style: TextStyle(fontWeight: FontWeight.w700, color: dark ? Colors.white : CmColors.ink),
                    ),
                  ),
                  Text('${tripDistance(s, miles[keys[i]]!)} ${tripUnit(s)}', style: TextStyle(color: dark ? Colors.white70 : CmColors.inkDim)),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 64,
                    child: Text(tripMoney(money[keys[i]]!), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
