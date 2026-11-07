// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/trip_card.dart
//
// One trip as a card (2026-11-06): miles and when, the route map, where it started
// and ended, what it is worth, the category as tap targets and the small actions.
// The same card is the pop-up over the Dashboard when a trip ends and each row of
// the trips list, so the driver sees one design everywhere.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/irs_rates.dart';
import '../i18n/app_texts.dart';
import '../logic/app_state.dart';
import '../models/gig_app.dart';
import '../models/session_section.dart';
import '../models/tracking_session.dart';
import '../theme/cm_colors.dart';
import 'brand_loader.dart';

/// One trip (a session) with its sections -- or, in the My Trips list, ONE section of a
/// session that switched gig app ([segment]), so each leg is its own card.
class TripData {
  final TrackingSession session;
  final List<SessionSection> sections;
  final String? mapToken;
  final bool segment;
  /// False for a segment card that is not the trip's last leg.
  final bool endsTrip;
  TripData(this.session, this.sections, this.mapToken, {this.segment = false, this.endsTrip = true});

  /// Unique per card: a session plus, for a segment, its section.
  String get key => segment ? '${session.id}/${sections.first.id}' : session.id;

  /// The list's cards: a trip with several segments becomes one card per segment, each
  /// with its own addresses, miles, time, category and route map (2026-11-06).
  static List<TripData> splitFromRow(Map<String, dynamic> row) {
    final whole = TripData.fromRow(row);
    if (whole.sections.length <= 1) return [whole];
    return [
      for (final sec in whole.sections)
        TripData(whole.session, [sec], whole.mapToken, segment: true, endsTrip: sec == whole.sections.last),
    ];
  }

  /// From a `sessions` row that has its `session_sections` inside.
  factory TripData.fromRow(Map<String, dynamic> row) {
    final session = TrackingSession.fromMap(row);
    final sections = ((row['session_sections'] as List?) ?? [])
        .map((s) => SessionSection.fromMap(s))
        .where((s) => s.isClosed)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return TripData(session, sections, row['map_token'] as String?);
  }

  bool get isGeneral => sections.any((s) => s.gigApp == 'custom');

  /// General history can be changed (2026-11-07, explicit decision). A gig-app segment
  /// is a record of the work: only [canEditEndAddress] applies to it, and it can still
  /// be deleted at the driver's own responsibility. Miles are never edited, in any mode.
  bool get editable => sections.isNotEmpty && sections.every((s) => s.gigApp == 'custom');

  /// The address where the trip ended is only approximate, so it can be corrected.
  bool get canEditEndAddress => editable || (sections.isNotEmpty && endsTrip);

  /// The category the driver gave a General trip (null while it has none).
  String? get purpose {
    for (final s in sections) {
      if (s.gigApp == 'custom' && s.irsPurpose != null) return s.irsPurpose;
    }
    return null;
  }

  bool get needsCategory => isGeneral && purpose == null;

  double get miles {
    final fromSections = sections.fold<double>(0, (a, s) => a + s.totalMiles);
    return fromSections > 0 ? fromSections : session.totalMiles;
  }

  int get seconds => segment
      ? sections.first.effectiveDurationSeconds
      : (session.effectiveDurationSeconds ?? sections.fold<int>(0, (a, s) => a + s.effectiveDurationSeconds));

  DateTime? get start => segment ? sections.first.startTime : (session.startTime ?? (sections.isEmpty ? null : sections.first.startTime));
  DateTime? get end => segment ? sections.first.endTime : (session.endTime ?? (sections.isEmpty ? null : sections.last.endTime));

  String? get fromAddress => sections.isEmpty ? null : sections.first.startAddress;
  String? get toAddress => sections.isEmpty ? null : sections.last.endAddress;
  bool get hasNote => sections.isNotEmpty && (sections.first.notes ?? '').isNotEmpty;

  /// Money this trip is worth: each section at the rate of its own category and day.
  double get deduction {
    var cents = 0.0;
    for (final s in sections) {
      final purpose = s.gigApp == 'custom' ? s.irsPurpose : 'business';
      cents += s.totalMiles * ratePerMileCentsForPurpose(purpose, s.startTime);
    }
    return cents / 100.0;
  }
}

const _businessGroup = {'business', 'delivery', 'errand', 'client', 'travel'};
const _mapBase = 'https://controlmiles.com/api/trip-map';

String tripDistance(AppState s, double miles) {
  final v = s.useMetricSystem ? miles * 1.60934 : miles;
  return v < 10 ? v.toStringAsFixed(2) : v.toStringAsFixed(1);
}

String tripUnit(AppState s) => s.tr(s.useMetricSystem ? 'kilometer_short' : 'mile_short');
String tripMoney(double v) => '\$${v.toStringAsFixed(2)}';

String tripSpan(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final m = seconds ~/ 60;
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${m % 60} min';
}

/// "Not guaranteed" note shown from the question mark next to every deduction figure.
void showDeductionNote(BuildContext context) {
  final s = context.read<AppState>();
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.tr('trips_stat_deduction')),
      content: Text(s.tr('trips_deduction_note')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.tr('ok')))],
    ),
  );
}

String tripClock(DateTime? d) => d == null ? '--' : DateFormat('h:mm a').format(d.toLocal());

class TripCard extends StatelessWidget {
  final TripData trip;
  final ValueChanged<String> onPurpose;
  final VoidCallback onMore;
  final VoidCallback onEditAddress;
  final VoidCallback onNote;

  /// Only the list shows these two.
  final VoidCallback? onDelete;
  final VoidCallback? onToggleDetails;
  final bool detailsOpen;

  /// Inside the pop-up the card has no border or margin of its own.
  final bool framed;

  const TripCard({
    super.key,
    required this.trip,
    required this.onPurpose,
    required this.onMore,
    required this.onEditAddress,
    required this.onNote,
    this.onDelete,
    this.onToggleDetails,
    this.detailsOpen = false,
    this.framed = true,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : CmColors.ink;
    final dim = dark ? Colors.white60 : CmColors.inkDim;
    final money = trip.deduction;
    final day = trip.start == null ? '' : DateFormat('EEE d MMM', s.currentLanguage.code).format(trip.start!.toLocal());

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(tripDistance(s, trip.miles), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ink, height: 1.1)),
                        const SizedBox(width: 4),
                        Text(tripUnit(s), style: TextStyle(fontSize: 13, color: dim)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('$day · ${tripClock(trip.start)} – ${tripClock(trip.end)} · ${tripSpan(trip.seconds)}', style: TextStyle(fontSize: 12, color: dim)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    tripMoney(money),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: money > 0 ? (dark ? const Color(0xFF85B7EB) : const Color(0xFF185FA5)) : dim,
                    ),
                  ),
                  InkWell(
                    onTap: () => showDeductionNote(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s.tr('trips_stat_deduction'), style: TextStyle(fontSize: 11, color: dim)),
                        const SizedBox(width: 3),
                        Icon(Icons.help_outline_rounded, size: 14, color: dim),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (trip.mapToken != null)
          SizedBox(
            height: 130,
            width: double.infinity,
            child: SvgPicture.network(
              '$_mapBase/${trip.session.id}/${trip.mapToken}?${trip.segment ? 'section=${trip.sections.first.id}&' : ''}lite=1',
              fit: BoxFit.cover,
              placeholderBuilder: (_) => const Center(child: BrandLoader(size: 28)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Column(
            children: [
              _stop(Icons.circle, const Color(0xFF3B6D11), trip.fromAddress ?? s.tr('trips_address_unknown'), tripClock(trip.start), ink, dim),
              const SizedBox(height: 6),
              _stop(Icons.square_rounded, const Color(0xFFD85A30), trip.toAddress ?? s.tr('trips_address_unknown'), tripClock(trip.end), ink, dim),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: _categories(context, s, dark),
        ),
        Divider(height: 1, color: dark ? CmColors.ink : CmColors.sand),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            children: [
              if (trip.canEditEndAddress)
                _action(Icons.edit_location_alt_outlined, s.tr('trips_edit_address'), onEditAddress, dim),
              if (trip.editable)
                _action(trip.hasNote ? Icons.sticky_note_2_rounded : Icons.note_add_outlined, s.tr('trips_note'), onNote, dim),
              if (onToggleDetails != null)
                _action(detailsOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, s.tr('trips_details'), onToggleDetails!, dim),
              if (onDelete != null) _action(Icons.delete_outline_rounded, s.tr('trips_delete'), onDelete!, Colors.red.shade400),
            ],
          ),
        ),
        if (detailsOpen) _details(s, dark),
      ],
    );

    if (!framed) return body;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: dark ? CmColors.nightCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? CmColors.ink : CmColors.sand),
      ),
      clipBehavior: Clip.antiAlias,
      child: body,
    );
  }

  Widget _stop(IconData icon, Color color, String address, String time, Color ink, Color dim) => Row(
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: ink))),
          const SizedBox(width: 8),
          Text(time, style: TextStyle(fontSize: 12, color: dim)),
        ],
      );

  Widget _action(IconData icon, String label, VoidCallback onTap, Color color) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 2),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: color)),
              ],
            ),
          ),
        ),
      );

  /// General trips: tap the category. Gig-app trips are Business by themselves.
  Widget _categories(BuildContext context, AppState s, bool dark) {
    if (!trip.isGeneral) {
      final names = {for (final sec in trip.sections) GigAppCatalog.byId(sec.gigApp).name}.join(', ');
      return _pill(context, '${s.tr(IrsPurposeCatalog.labelKeyFor('business') ?? 'business')} · $names', true, null, dark, locked: true);
    }

    final p = trip.purpose;
    final business = p != null && _businessGroup.contains(p);
    final quick = <(String, String)>[
      ('business', IrsPurposeCatalog.labelKeyFor('business') ?? 'business'),
      ('personal', IrsPurposeCatalog.labelKeyFor('personal') ?? 'personal'),
      ('medical', IrsPurposeCatalog.labelKeyFor('medical') ?? 'medical'),
      ('charitable', IrsPurposeCatalog.labelKeyFor('charitable') ?? 'charitable'),
    ];
    final inQuick = p != null && (business || quick.any((q) => q.$1 == p));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: CmColors.amber, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(s.tr('trips_pick_category'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dark ? Colors.white70 : CmColors.inkDim)),
              ],
            ),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final q in quick) _pill(context, s.tr(q.$2), q.$1 == 'business' ? business : p == q.$1, () => onPurpose(q.$1), dark),
            _pill(
              context,
              p != null && !inQuick ? s.tr(IrsPurposeCatalog.labelKeyFor(p) ?? p) : s.tr('trips_more'),
              p != null && !inQuick,
              onMore,
              dark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _pill(BuildContext context, String text, bool selected, VoidCallback? onTap, bool dark, {bool locked = false}) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: dark ? 0.28 : 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? accent : (dark ? CmColors.ink : CmColors.sand), width: selected ? 1.4 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (locked) ...[Icon(Icons.lock_outline_rounded, size: 13, color: accent), const SizedBox(width: 5)],
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? accent : (dark ? Colors.white70 : CmColors.inkDim)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _details(AppState s, bool dark) {
    final ink = dark ? Colors.white : CmColors.ink;
    final dim = dark ? Colors.white60 : CmColors.inkDim;
    return Container(
      color: dark ? CmColors.night : CmColors.cream,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final sec in trip.sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(GigAppCatalog.byId(sec.gigApp).icon, size: 16, color: GigAppCatalog.byId(sec.gigApp).color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(GigAppCatalog.byId(sec.gigApp).name, style: TextStyle(fontWeight: FontWeight.w700, color: ink))),
                  Text('${tripDistance(s, sec.totalMiles)} ${tripUnit(s)} · ${tripSpan(sec.effectiveDurationSeconds)}', style: TextStyle(fontSize: 12, color: dim)),
                ],
              ),
            ),
          if (trip.hasNote) Text('“${trip.sections.first.notes}”', style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: dim)),
          if (trip.session.cgcDecisionId != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, size: 14, color: dim),
                  const SizedBox(width: 6),
                  Text(s.tr('trip_sealed_badge'), style: TextStyle(fontSize: 12, color: dim)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
