// Olympus Mont Systems LLC - ControlMiles
// lib/screens/driver_notifications_screen.dart
//
// The driver's messages (bell icon on the driver screen, 2026-09-30):
// after-trip safety notes and the 15-day driving summary, written here in
// the driver's own language from the numbers the server stored. Opening
// the screen marks them read. The summary links to the full score
// (DriverSafetyScoreScreen), which also lives in Settings.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../services/driver_notification_service.dart';
import 'driver_safety_score_screen.dart';

class DriverNotificationsScreen extends StatefulWidget {
  const DriverNotificationsScreen({super.key});

  @override
  State<DriverNotificationsScreen> createState() => _DriverNotificationsScreenState();
}

class _DriverNotificationsScreenState extends State<DriverNotificationsScreen> {
  final _service = DriverNotificationService();
  List<DriverNotification>? _items;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _service.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _failed = false;
      });
      if (items.any((n) => !n.read)) await _service.markAllRead();
    } catch (e) {
      debugPrint('[ControlMiles] driver notifications load failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// "2 harsh braking · 1 speeding" in the driver's language.
  String _eventsLine(AppState appState, DriverNotification n) {
    final parts = <String>[];
    void add(String key, String label) {
      final v = n.intOf(key);
      if (v > 0) parts.add('$v ${appState.tr(label).toLowerCase()}');
    }

    add('harsh_braking', 'safety_harsh_braking');
    add('hard_acceleration', 'safety_hard_acceleration');
    add('speeding', 'safety_speeding');
    return parts.join(' · ');
  }

  (IconData, Color, String, String) _render(AppState appState, DriverNotification n) {
    if (n.kind == 'trip_safety') {
      final tripDate = n.data['trip_date'] as String? ?? _date(n.createdAt);
      return (
        Icons.warning_amber_rounded,
        const Color(0xFFF59E0B),
        appState.tr('notif_trip_safety_title').replaceFirst('{date}', tripDate),
        '${_eventsLine(appState, n)}. ${appState.tr('notif_trip_safety_tip')}',
      );
    }
    // safety_summary
    final score = n.scoreOf('score');
    final prev = n.scoreOf('previous_score');
    final trend = n.data['trend'] as String? ?? 'steady';
    final miles = (n.data['miles'] as num?)?.round() ?? 0;
    final events = _eventsLine(appState, n);
    final positive = trend == 'better' || trend == 'good' || (score != null && score >= 90);
    final String headline;
    switch (trend) {
      case 'better':
        headline = appState.tr('notif_summary_better');
      case 'worse':
        headline = (score ?? 0) >= 90 ? appState.tr('notif_summary_worse_still_good') : appState.tr('notif_summary_worse');
      case 'good':
        headline = appState.tr('notif_summary_good');
      case 'attention':
        headline = appState.tr('notif_summary_attention');
      case 'unrated':
        headline = appState.tr('notif_summary_unrated');
      default:
        headline = appState.tr('notif_summary_steady');
    }
    final scoreLine = score == null
        ? ''
        : prev == null
            ? appState.tr('notif_summary_score').replaceFirst('{score}', '$score')
            : appState.tr('notif_summary_score_prev').replaceFirst('{score}', '$score').replaceFirst('{prev}', '$prev');
    final body = [
      if (scoreLine.isNotEmpty) scoreLine,
      appState.tr('notif_summary_miles').replaceFirst('{miles}', '$miles'),
      events.isEmpty ? appState.tr('notif_summary_no_events') : events,
    ].join('\n');
    return (
      positive ? Icons.emoji_events_rounded : Icons.insights_rounded,
      positive ? const Color(0xFF10B981) : const Color(0xFF0EA5E9),
      '${appState.tr('notif_summary_title')}: $headline',
      body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    Widget body;
    if (_failed) {
      body = Center(child: Text(appState.tr('notif_load_failed'), style: TextStyle(color: subTextColor)));
    } else if (_items == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items!.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(appState.tr('notif_empty'), textAlign: TextAlign.center, style: TextStyle(color: subTextColor)),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _items!.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final n = _items![i];
            final (icon, color, title, text) = _render(appState, n);
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: n.kind == 'safety_summary'
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DriverSafetyScoreScreen()),
                      )
                  : null,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: n.read ? borderColor : color.withValues(alpha: 0.6)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: textColor)),
                          const SizedBox(height: 4),
                          Text(text, style: TextStyle(fontSize: 12.5, height: 1.35, color: subTextColor)),
                          const SizedBox(height: 6),
                          Text(_date(n.createdAt), style: TextStyle(fontSize: 11, color: subTextColor)),
                        ],
                      ),
                    ),
                    if (n.kind == 'safety_summary') Icon(Icons.chevron_right_rounded, color: subTextColor),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(appState.tr('notif_title')),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SafeArea(child: body),
    );
  }
}
