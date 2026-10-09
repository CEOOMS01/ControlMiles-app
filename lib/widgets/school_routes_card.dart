// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/school_routes_card.dart
//
// School transportation (2026-10-09): the driver's school routes for today
// on the fleet driver home. A route starts inside an open trip (the trip
// supplies the GPS and the bus), so with no trip it only says to start one.
// Shows nothing when the driver has no school routes today. In monitorMode
// (bus monitor home, 2026-10-09) there's no trip and no Start: the monitor
// opens a route once the driver has started it.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../errors/app_error.dart';
import '../logic/app_state.dart';
import '../screens/school_run_screen.dart';
import '../services/school_route_service.dart';
import '../tracking/tracking_controller.dart';
import 'cm_card_header.dart';

class SchoolRoutesCard extends StatefulWidget {
  final String organizationId;
  final bool tripIsActive;
  final bool monitorMode;

  const SchoolRoutesCard({
    super.key,
    required this.organizationId,
    required this.tripIsActive,
    this.monitorMode = false,
  });

  @override
  State<SchoolRoutesCard> createState() => _SchoolRoutesCardState();
}

class _SchoolRoutesCardState extends State<SchoolRoutesCard> {
  final _service = SchoolRouteService();
  List<SchoolRoute> _routes = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SchoolRoutesCard old) {
    super.didUpdateWidget(old);
    if (old.tripIsActive != widget.tripIsActive) _load();
  }

  Future<void> _load() async {
    try {
      final routes = await _service.myRoutesToday(widget.organizationId);
      if (mounted) setState(() => _routes = routes);
    } catch (e) {
      debugPrint('[SchoolRoutesCard] load failed: $e');
    }
  }

  String _errorText(AppState appState, Object e) {
    final s = e.toString();
    if (s.contains('ROUTE_ALREADY_COMPLETED')) return appState.tr('school_err_completed');
    if (s.contains('ANOTHER_ROUTE_IN_PROGRESS')) return appState.tr('school_err_other_running');
    if (s.contains('TRIP_NOT_ACTIVE')) return appState.tr('school_start_trip_first');
    final err = AppError.from(e);
    return err.display(appState.tr(err.messageKey));
  }

  Future<void> _open(SchoolRoute route) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SchoolRunScreen(organizationId: widget.organizationId, routeId: route.id),
      ),
    );
    _load();
  }

  Future<void> _start(AppState appState, SchoolRoute route) async {
    final sessionId = TrackingController.activeSessionId;
    if (sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.tr('school_start_trip_first'))));
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.startRun(route.id, sessionId);
      if (!mounted) return;
      await _open(route);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorText(appState, e)), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _clock(String? hhmmss) {
    if (hhmmss == null || hhmmss.length < 5) return '';
    final h = int.parse(hhmmss.substring(0, 2));
    return '${h % 12 == 0 ? 12 : h % 12}:${hhmmss.substring(3, 5)} ${h < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (_routes.isEmpty) {
      return widget.monitorMode ? Text(appState.tr('school_no_routes_today')) : const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1C1812) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF6B6250);
    final borderColor = isDark ? const Color(0xFF2E281F) : const Color(0xFFE3D9C4);
    final primary = Theme.of(context).colorScheme.primary;

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
          CmCardHeader(title: appState.tr('school_routes_today'), inset: true),
          if (!widget.tripIsActive && !widget.monitorMode) ...[
            const SizedBox(height: 6),
            Text(appState.tr('school_start_trip_first'), style: TextStyle(fontSize: 12, color: subTextColor)),
          ],
          const SizedBox(height: 8),
          for (final r in _routes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)),
                        Text(
                          [
                            appState.tr(r.routeType == 'school_pm' ? 'school_route_pm' : 'school_route_am'),
                            if (r.scheduledStartTime != null) _clock(r.scheduledStartTime),
                            if (r.school != null) r.school!,
                            appState.tr('school_stops_progress')
                                .replaceFirst('{done}', '${r.stops.where((s) => s.arrived).length}')
                                .replaceFirst('{total}', '${r.stops.length}'),
                          ].join(' · '),
                          style: TextStyle(fontSize: 12, color: subTextColor),
                        ),
                      ],
                    ),
                  ),
                  if (r.completed)
                    Text(appState.tr('school_route_completed'),
                        style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w700, fontSize: 12))
                  else if (r.inProgress)
                    FilledButton(
                      onPressed: _busy ? null : () => _open(r),
                      child: Text(appState.tr('school_open_route')),
                    )
                  else if (r.isMonitor)
                    SizedBox(
                      width: 120,
                      child: Text(appState.tr('monitor_waiting_driver'),
                          textAlign: TextAlign.end, style: TextStyle(fontSize: 12, color: subTextColor)),
                    )
                  else
                    FilledButton(
                      onPressed: (_busy || !widget.tripIsActive) ? null : () => _start(appState, r),
                      style: FilledButton.styleFrom(backgroundColor: primary),
                      child: Text(appState.tr('school_start_route')),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
