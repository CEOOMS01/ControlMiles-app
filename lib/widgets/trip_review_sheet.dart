// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/trip_review_sheet.dart
//
// The pop-up over the Dashboard when a trip ends (2026-11-06): the trip card itself,
// with its map, addresses and category chips. Picking a category saves it and the
// pop-up goes away. Closing it without picking leaves the trip as it is -- nothing
// is locked: the category, the addresses and the note can be changed later from the
// trips list, also after a category was given.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/app_state.dart';
import '../theme/cm_colors.dart';
import 'brand_loader.dart';
import 'purpose_prompt.dart';
import 'trip_card.dart';
import 'trip_edits.dart';

class TripReviewSheet {
  TripReviewSheet._();

  /// Opens the card of the trip that holds [sectionId]. True when a category was
  /// saved; false when the driver closed it ("later").
  static Future<bool> show(BuildContext context, {required String sectionId, String? subtitle}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _Body(sectionId: sectionId, subtitle: subtitle),
    );
    return saved == true;
  }
}

class _Body extends StatefulWidget {
  final String sectionId;
  final String? subtitle;
  const _Body({required this.sectionId, this.subtitle});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  TripData? _trip;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final sec = await client.from('session_sections').select('session_id').eq('id', widget.sectionId).single();
      final row = await client.from('sessions').select('*, session_sections(*)').eq('id', sec['session_id'] as String).single();
      if (mounted) setState(() => _trip = TripData.fromRow(row));
    } catch (e) {
      debugPrint('[TripReviewSheet] load failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _pick(String purpose) async {
    final trip = _trip!;
    if (await TripEdits.setPurpose(context, trip, purpose) && mounted) Navigator.pop(context, true);
  }

  Future<void> _more() async {
    final picked = await PurposePrompt.choose(context);
    if (picked != null) await _pick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final trip = _trip;

    return Container(
      decoration: BoxDecoration(
        color: dark ? CmColors.nightCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 38, height: 4, decoration: BoxDecoration(color: dark ? CmColors.ink : CmColors.sand, borderRadius: BorderRadius.circular(2))),
            if (widget.subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(widget.subtitle!, style: TextStyle(fontSize: 12, color: dark ? Colors.white60 : CmColors.inkDim)),
              ),
            Flexible(
              child: SingleChildScrollView(
                child: trip == null
                    ? SizedBox(
                        height: 220,
                        child: Center(
                          child: _failed ? Text(s.tr('trips_none_this_month')) : const BrandLoader(size: 36),
                        ),
                      )
                    : TripCard(
                        trip: trip,
                        framed: false,
                        onPurpose: _pick,
                        onMore: _more,
                        onEditAddress: () async {
                          if (await TripEdits.editAddresses(context, trip) && mounted) setState(() {});
                        },
                        onNote: () async {
                          if (await TripEdits.editNote(context, trip) && mounted) setState(() {});
                        },
                      ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.tr('purpose_prompt_later')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
