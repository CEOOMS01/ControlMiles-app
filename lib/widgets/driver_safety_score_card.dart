// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/driver_safety_score_card.dart
//
// The driver's own safety score (2026-09-30, alongside the web
// scorecard): same number the fleet admin sees, from the
// driver_safety_scores RPC, which returns only the caller's own rows to a
// non-admin. Shown on the driver screen when no trip is running (never
// while driving), with the last 30 days' events and the change vs the 30
// days before -- the self-coaching loop Motive's driver app has.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/app_state.dart';

class DriverSafetyScoreCard extends StatefulWidget {
  final String organizationId;

  const DriverSafetyScoreCard({super.key, required this.organizationId});

  @override
  State<DriverSafetyScoreCard> createState() => _DriverSafetyScoreCardState();
}

class _ScoreRow {
  final double miles;
  final int harshBraking;
  final int hardAcceleration;
  final int speeding;
  final int? score;

  const _ScoreRow(this.miles, this.harshBraking, this.hardAcceleration, this.speeding, this.score);

  static _ScoreRow? fromRows(dynamic data) {
    if (data is! List || data.isEmpty) return null;
    final m = Map<String, dynamic>.from(data.first as Map);
    num n(String k) => (m[k] as num?) ?? 0;
    return _ScoreRow(
      n('miles').toDouble(),
      n('harsh_braking').toInt(),
      n('hard_acceleration').toInt(),
      n('speeding').toInt(),
      (m['score'] as num?)?.round(),
    );
  }
}

class _DriverSafetyScoreCardState extends State<DriverSafetyScoreCard> {
  _ScoreRow? _current;
  _ScoreRow? _previous;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final now = DateTime.now();
    final client = Supabase.instance.client;
    try {
      final results = await Future.wait([
        client.rpc('driver_safety_scores', params: {
          'p_organization_id': widget.organizationId,
          'p_start_date': _day(now.subtract(const Duration(days: 29))),
          'p_end_date': _day(now),
        }),
        client.rpc('driver_safety_scores', params: {
          'p_organization_id': widget.organizationId,
          'p_start_date': _day(now.subtract(const Duration(days: 59))),
          'p_end_date': _day(now.subtract(const Duration(days: 30))),
        }),
      ]);
      if (!mounted) return;
      setState(() {
        _current = _ScoreRow.fromRows(results[0]);
        _previous = _ScoreRow.fromRows(results[1]);
        _loaded = true;
      });
    } catch (e) {
      debugPrint('[ControlMiles] safety score load failed: $e');
      if (mounted) setState(() => _loaded = true);
    }
  }

  (String, Color) _grade(AppState appState, int? score) {
    if (score == null) return (appState.tr('safety_grade_not_enough'), const Color(0xFF94A3B8));
    if (score >= 90) return (appState.tr('safety_grade_excellent'), const Color(0xFF10B981));
    if (score >= 75) return (appState.tr('safety_grade_good'), const Color(0xFF0EA5E9));
    if (score >= 60) return (appState.tr('safety_grade_coaching'), const Color(0xFFF59E0B));
    return (appState.tr('safety_grade_risk'), const Color(0xFFDC2626));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (!_loaded) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    final score = _current?.score;
    final (label, color) = _grade(appState, score);
    final prev = _previous?.score;
    final delta = score != null && prev != null ? score - prev : null;

    Widget stat(String text, int value) => Expanded(
          child: Column(
            children: [
              Text('$value',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textColor)),
              const SizedBox(height: 2),
              Text(text,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: subTextColor)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appState.tr('safety_score_title').toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: subTextColor),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 4),
                ),
                child: Text(
                  score?.toString() ?? '—',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
                    const SizedBox(height: 2),
                    Text(
                      score == null
                          ? appState.tr('safety_score_not_enough')
                          : delta == null
                              ? appState.tr('safety_score_last30')
                              : appState
                                  .tr('safety_score_vs_prev')
                                  .replaceFirst('{delta}', delta > 0 ? '+$delta' : '$delta'),
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              stat(appState.tr('safety_harsh_braking'), _current?.harshBraking ?? 0),
              stat(appState.tr('safety_hard_acceleration'), _current?.hardAcceleration ?? 0),
              stat(appState.tr('safety_speeding'), _current?.speeding ?? 0),
            ],
          ),
          const SizedBox(height: 12),
          Text(appState.tr('safety_score_tip'), style: TextStyle(fontSize: 11.5, color: subTextColor)),
        ],
      ),
    );
  }
}
