// Olympus Mont Systems LLC - ControlMiles
// lib/views/regular_trips_screen.dart
//
// Regular Trips (2026-11-09): routes the driver repeats. A General trip that starts
// and ends on a saved route classifies itself when it closes (the database does it).
// Routes are saved here, from a finished trip, or by accepting a suggestion that
// appears the third time the same route gets the same category.

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/app_state.dart';
import '../models/gig_app.dart';
import '../services/notification_service.dart';
import '../services/trip_address_service.dart';
import '../services/trip_rules_service.dart';
import '../widgets/brand_loader.dart';
import '../widgets/purpose_prompt.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_edits.dart';
import '../widgets/cm_dark_app_bar.dart';

class RegularTripDraft {
  final double? startLatitude;
  final double? startLongitude;
  final String? startAddress;
  final double? endLatitude;
  final double? endLongitude;
  final String? endAddress;
  final String? purpose;

  const RegularTripDraft({
    this.startLatitude,
    this.startLongitude,
    this.startAddress,
    this.endLatitude,
    this.endLongitude,
    this.endAddress,
    this.purpose,
  });
}

class RegularTripFlow {
  RegularTripFlow._();

  static const _kDismissed = 'regular_trip_suggestions_dismissed';
  static bool _asking = false;

  /// Only finished General trips with both ends recorded, on Premium.
  static bool canSave(TripData trip, AppState s) =>
      s.premiumEntitled &&
      trip.editable &&
      trip.sections.first.startLatitude != null &&
      trip.sections.last.endLatitude != null;

  static Future<void> openFromTrip(BuildContext context, TripData trip) {
    final first = trip.sections.first;
    final last = trip.sections.last;
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegularTripEditorScreen(
          draft: RegularTripDraft(
            startLatitude: first.startLatitude,
            startLongitude: first.startLongitude,
            startAddress: first.startAddress,
            endLatitude: last.endLatitude,
            endLongitude: last.endLongitude,
            endAddress: last.endAddress,
            purpose: trip.purpose,
          ),
        ),
      ),
    );
  }

  /// A new route may cover trips that still have no category: asks before touching them.
  static Future<void> offerApplyPast(BuildContext context, String id) async {
    final s = context.read<AppState>();
    final count = await TripRulesService.countPast(id);
    if (count == 0 || !context.mounted) return;
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('regular_trip_apply_title')),
        content: Text(s.tr('regular_trip_apply_body').replaceAll('{n}', '$count')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.tr('regular_trip_apply_no'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.tr('regular_trip_apply_yes'))),
        ],
      ),
    );
    if (apply == true) await TripRulesService.applyToPast(id);
  }

  /// After the driver classifies a trip. Best effort: never gets in the way of the save.
  static Future<void> suggestAfterCategorized(String sectionId) async {
    if (_asking) return;
    _asking = true;
    try {
      final data = await TripRulesService.suggestFor(sectionId);
      if (data == null) return;
      String c(String key) => (data[key] as num).toStringAsFixed(3);
      final key = '${c('start_latitude')},${c('start_longitude')}|${c('end_latitude')},${c('end_longitude')}|${data['purpose']}';
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getStringList(_kDismissed) ?? <String>[];
      if (dismissed.contains(key)) return;

      // Let the category sheet finish closing first.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final nav = NotificationService.instance.navigatorKey?.currentState;
      final context = nav?.overlay?.context;
      if (nav == null || context == null || !context.mounted) return;
      final s = context.read<AppState>();
      final purpose = data['purpose'] as String;
      final from = (data['start_address'] as String?) ?? s.tr('regular_trip_saved_place');
      final to = (data['end_address'] as String?) ?? s.tr('regular_trip_saved_place');
      final accept = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.tr('regular_trip_suggest_title')),
          content: Text(s
              .tr('regular_trip_suggest_body')
              .replaceAll('{n}', '${data['count']}')
              .replaceAll('{from}', from)
              .replaceAll('{to}', to)
              .replaceAll('{purpose}', s.tr(IrsPurposeCatalog.labelKeyFor(purpose) ?? purpose))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.tr('regular_trip_suggest_no'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.tr('regular_trip_suggest_yes'))),
          ],
        ),
      );
      if (accept == true) {
        await nav.push(
          MaterialPageRoute(
            builder: (_) => RegularTripEditorScreen(
              draft: RegularTripDraft(
                startLatitude: (data['start_latitude'] as num).toDouble(),
                startLongitude: (data['start_longitude'] as num).toDouble(),
                startAddress: data['start_address'] as String?,
                endLatitude: (data['end_latitude'] as num).toDouble(),
                endLongitude: (data['end_longitude'] as num).toDouble(),
                endAddress: data['end_address'] as String?,
                purpose: purpose,
              ),
            ),
          ),
        );
      } else if (accept == false) {
        await prefs.setStringList(_kDismissed, [...dismissed, key].take(100).toList());
      }
    } catch (e) {
      debugPrint('[RegularTrips] suggestion failed: $e');
    } finally {
      _asking = false;
    }
  }
}

class RegularTripsScreen extends StatefulWidget {
  const RegularTripsScreen({super.key});

  @override
  State<RegularTripsScreen> createState() => _RegularTripsScreenState();
}

class _RegularTripsScreenState extends State<RegularTripsScreen> {
  TripClassificationSettings? _settings;
  List<RegularTrip> _trips = const [];
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await TripRulesService.loadSettings();
      final trips = await TripRulesService.list();
      if (mounted) {
        setState(() {
          _settings = settings;
          _trips = trips;
          _failed = false;
        });
      }
    } catch (e) {
      debugPrint('[RegularTrips] load failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _toggle(void Function(TripClassificationSettings) change) async {
    final settings = _settings!;
    setState(() => change(settings));
    try {
      await TripRulesService.saveSettings(settings);
    } catch (e) {
      if (mounted) TripEdits.showError(context, e);
      await _load();
    }
  }

  Future<void> _open({RegularTrip? existing}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RegularTripEditorScreen(existing: existing)),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final theme = Theme.of(context);
    final muted = TextStyle(fontSize: 14, height: 1.4, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7));
    final settings = _settings;

    return Scaffold(
      appBar: cmDarkAppBar(context, s.tr('regular_trips_title')),
      body: settings == null
          ? Center(child: _failed ? Text(s.tr('error')) : const BrandLoader(size: 36))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(s.tr('regular_trips_hint'), style: muted),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.tr('regular_trips_title'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  value: settings.regularEnabled,
                  onChanged: (v) => _toggle((x) => x.regularEnabled = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.tr('regular_trips_suggestions'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(s.tr('regular_trips_suggestions_hint')),
                  value: settings.suggestionsEnabled,
                  onChanged: settings.regularEnabled ? (v) => _toggle((x) => x.suggestionsEnabled = v) : null,
                ),
                const SizedBox(height: 8),
                Text(s.tr('trip_rules_general_only'), style: muted),
                const Divider(height: 32),
                if (_trips.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Text(s.tr('regular_trips_empty'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(s.tr('regular_trips_empty_hint'), textAlign: TextAlign.center, style: muted),
                      ],
                    ),
                  ),
                for (final trip in _trips)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.repeat_rounded),
                    title: Text(
                      '${trip.startAny ? s.tr('regular_trip_any') : (trip.startAddress ?? s.tr('regular_trip_saved_place'))} → ${trip.endAddress ?? s.tr('regular_trip_saved_place')}',
                    ),
                    subtitle: Text(s.tr(IrsPurposeCatalog.labelKeyFor(trip.purpose) ?? trip.purpose)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _open(existing: trip),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => _open(),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(s.tr('regular_trips_add')),
                  ),
                ),
              ],
            ),
    );
  }
}

class RegularTripEditorScreen extends StatefulWidget {
  final RegularTrip? existing;
  final RegularTripDraft? draft;

  const RegularTripEditorScreen({super.key, this.existing, this.draft});

  @override
  State<RegularTripEditorScreen> createState() => _RegularTripEditorScreenState();
}

class _RegularTripEditorScreenState extends State<RegularTripEditorScreen> {
  final _start = TextEditingController();
  final _end = TextEditingController();
  bool _startAny = false;
  (double, double)? _startPoint;
  (double, double)? _endPoint;
  String? _purpose;
  bool _saving = false;

  static String _pointText(double lat, double lng) => '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final d = widget.draft;
    if (e != null) {
      _startAny = e.startAny;
      if (e.startLatitude != null && e.startLongitude != null) _startPoint = (e.startLatitude!, e.startLongitude!);
      _start.text = e.startAddress ?? (_startPoint == null ? '' : _pointText(_startPoint!.$1, _startPoint!.$2));
      _endPoint = (e.endLatitude, e.endLongitude);
      _end.text = e.endAddress ?? _pointText(e.endLatitude, e.endLongitude);
      _purpose = e.purpose;
    } else if (d != null) {
      if (d.startLatitude != null && d.startLongitude != null) _startPoint = (d.startLatitude!, d.startLongitude!);
      if (d.endLatitude != null && d.endLongitude != null) _endPoint = (d.endLatitude!, d.endLongitude!);
      _start.text = d.startAddress ?? (_startPoint == null ? '' : _pointText(_startPoint!.$1, _startPoint!.$2));
      _end.text = d.endAddress ?? (_endPoint == null ? '' : _pointText(_endPoint!.$1, _endPoint!.$2));
      _purpose = d.purpose;
    }
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  Future<void> _useCurrent(bool start) async {
    try {
      final p = await Geolocator.getCurrentPosition();
      final address = await TripAddressService.lookup(p.latitude, p.longitude);
      if (!mounted) return;
      setState(() {
        final text = address ?? _pointText(p.latitude, p.longitude);
        if (start) {
          _startPoint = (p.latitude, p.longitude);
          _start.text = text;
        } else {
          _endPoint = (p.latitude, p.longitude);
          _end.text = text;
        }
      });
    } catch (e) {
      if (mounted) TripEdits.showError(context, e);
    }
  }

  Future<(double, double)?> _resolve(String text) async {
    if (text.trim().isEmpty) return null;
    try {
      final found = await Geocoding().locationFromAddress(text.trim()).timeout(const Duration(seconds: 8));
      if (found.isEmpty) return null;
      return (found.first.latitude, found.first.longitude);
    } catch (e) {
      debugPrint('[RegularTrips] address not found: $e');
      return null;
    }
  }

  Future<void> _save() async {
    final s = context.read<AppState>();
    if (_purpose == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.tr('regular_trip_choose_purpose'))));
      return;
    }
    setState(() => _saving = true);
    try {
      final start = _startAny ? null : (_startPoint ?? await _resolve(_start.text));
      final end = _endPoint ?? await _resolve(_end.text);
      if (!mounted) return;
      if ((!_startAny && start == null) || end == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.tr('regular_trip_address_not_found'))));
        setState(() => _saving = false);
        return;
      }
      String? text(TextEditingController c) {
        final v = c.text.trim();
        return v.isEmpty ? null : (v.length > 300 ? v.substring(0, 300) : v);
      }

      final fields = <String, dynamic>{
        'start_any': _startAny,
        'start_latitude': start?.$1,
        'start_longitude': start?.$2,
        'start_address': _startAny ? null : text(_start),
        'end_latitude': end.$1,
        'end_longitude': end.$2,
        'end_address': text(_end),
        'purpose': _purpose,
      };
      final existing = widget.existing;
      if (existing != null) {
        await TripRulesService.update(existing.id, fields);
      } else {
        final id = await TripRulesService.create(fields);
        if (!mounted) return;
        await RegularTripFlow.offerApplyPast(context, id);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        TripEdits.showError(context, e);
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final s = context.read<AppState>();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(s.tr('regular_trip_delete_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.tr('regular_trip_delete'))),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await TripRulesService.delete(widget.existing!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) TripEdits.showError(context, e);
    }
  }

  Widget _field(AppState s, TextEditingController controller, String hint, bool start) => TextField(
        controller: controller,
        maxLength: 300,
        onChanged: (_) => setState(() {
          if (start) {
            _startPoint = null;
          } else {
            _endPoint = null;
          }
        }),
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          suffixIcon: IconButton(
            tooltip: s.tr('regular_trip_use_current'),
            icon: const Icon(Icons.my_location_rounded),
            onPressed: () => _useCurrent(start),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    const label = TextStyle(fontWeight: FontWeight.w700);
    final purpose = _purpose;

    return Scaffold(
      appBar: cmDarkAppBar(
        context,
        s.tr(widget.existing == null ? 'regular_trips_add' : 'regular_trips_title'),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: s.tr('regular_trip_delete'),
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(s.tr('regular_trip_from'), style: label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(s.tr('regular_trip_specific')),
                selected: !_startAny,
                onSelected: (_) => setState(() => _startAny = false),
              ),
              ChoiceChip(
                label: Text(s.tr('regular_trip_any')),
                selected: _startAny,
                onSelected: (_) => setState(() => _startAny = true),
              ),
            ],
          ),
          if (!_startAny) ...[
            const SizedBox(height: 8),
            _field(s, _start, s.tr('regular_trip_start_hint'), true),
          ],
          const SizedBox(height: 20),
          Text(s.tr('regular_trip_to'), style: label),
          _field(s, _end, s.tr('regular_trip_end_hint'), false),
          const SizedBox(height: 20),
          Text(s.tr('regular_trip_classify_as'), style: label),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(purpose == null
                ? s.tr('regular_trip_choose_purpose')
                : s.tr(IrsPurposeCatalog.labelKeyFor(purpose) ?? purpose)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final picked = await PurposePrompt.choose(context, dismissKey: 'cancel');
              if (picked != null) setState(() => _purpose = picked);
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(s.tr('address_save')),
            ),
          ),
        ],
      ),
    );
  }
}
