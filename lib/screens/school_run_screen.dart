// Olympus Mont Systems LLC - ControlMiles
// lib/screens/school_run_screen.dart
//
// School transportation (2026-10-09): the driver runs one school route.
// Stops in order (the next one highlighted), each with the students who get
// on or off there; one tap marks a student. Arrival at a stop is marked by
// the server from the bus's live location (phone locked or not); while this
// screen is open it also checks the phone's position every 15 s, and the
// driver can mark it by hand. Finishing requires the "no child left on
// board" walk-through, recorded with time and place.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';

import '../errors/app_error.dart';
import '../logic/app_state.dart';
import '../services/school_route_service.dart';

class SchoolRunScreen extends StatefulWidget {
  final String organizationId;
  final String routeId;

  const SchoolRunScreen({super.key, required this.organizationId, required this.routeId});

  @override
  State<SchoolRunScreen> createState() => _SchoolRunScreenState();
}

class _SchoolRunScreenState extends State<SchoolRunScreen> {
  final _service = SchoolRouteService();
  SchoolRoute? _route;
  bool _loading = true;
  bool _busy = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _refresh();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final routes = await _service.myRoutesToday(widget.organizationId);
      final route = routes.where((r) => r.id == widget.routeId).firstOrNull;
      if (mounted) {
        setState(() {
          _route = route;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[SchoolRun] refresh failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Foreground arrival check, on top of the server's own (live location).
  Future<void> _tick() async {
    final route = _route;
    final runId = route?.runId;
    if (route == null || runId == null || !route.inProgress) return;
    try {
      final permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.always || permission == geo.LocationPermission.whileInUse) {
        final pos = await geo.Geolocator.getLastKnownPosition();
        if (pos != null) {
          for (final s in route.stops) {
            if (s.arrived) continue;
            final d = geo.Geolocator.distanceBetween(pos.latitude, pos.longitude, s.latitude, s.longitude);
            if (d <= s.radiusMeters) await _service.markArrived(runId, s.id);
          }
        }
      }
    } catch (e) {
      debugPrint('[SchoolRun] arrival check failed: $e');
    }
    await _refresh();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      final err = AppError.from(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.display(appState.tr(err.messageKey))), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish(AppState appState) async {
    final route = _route;
    final runId = route?.runId;
    if (route == null || runId == null) return;
    var checked = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(appState.tr('school_child_check_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(appState.tr('school_child_check_body')),
              if (route.onBoard > 0) ...[
                const SizedBox(height: 10),
                Text(
                  appState.tr('school_still_on_board').replaceFirst('{n}', '${route.onBoard}'),
                  style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: checked,
                onChanged: (v) => setLocal(() => checked = v ?? false),
                title: Text(appState.tr('school_child_check_confirm')),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(appState.tr('cancel'))),
            FilledButton(
              onPressed: checked ? () => Navigator.pop(ctx, true) : null,
              child: Text(appState.tr('school_finish_route')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    geo.Position? pos;
    try {
      pos = await geo.Geolocator.getLastKnownPosition();
    } catch (_) {}
    await _run(() => _service.complete(runId, latitude: pos?.latitude, longitude: pos?.longitude));
    if (mounted && (_route?.completed ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.tr('school_route_finished'))));
      Navigator.pop(context, true);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final primary = Theme.of(context).colorScheme.primary;
    final route = _route;

    return Scaffold(
      appBar: AppBar(
        title: Text(route?.name ?? appState.tr('school_routes_today')),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : route == null
                ? Center(child: Text(appState.tr('school_no_routes_today')))
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          [
                            appState.tr('school_stops_progress')
                                .replaceFirst('{done}', '${route.stops.where((s) => s.arrived).length}')
                                .replaceFirst('{total}', '${route.stops.length}'),
                            appState.tr('school_on_board').replaceFirst('{n}', '${route.onBoard}'),
                          ].join(' · '),
                          style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
                        ),
                        const SizedBox(height: 12),
                        for (final s in route.stops) ...[
                          _stopCard(appState, route, s, cardColor, textColor, subTextColor, borderColor, primary),
                          const SizedBox(height: 10),
                        ],
                        if (route.inProgress) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _busy ? null : () => _finish(appState),
                              icon: const Icon(Icons.flag_rounded),
                              label: Text(appState.tr('school_finish_route').toUpperCase()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                        if (route.completed)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(appState.tr('school_route_completed'),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _stopCard(
    AppState appState,
    SchoolRoute route,
    SchoolStop s,
    Color cardColor,
    Color textColor,
    Color subTextColor,
    Color borderColor,
    Color primary,
  ) {
    final isNext = route.inProgress && route.nextStop?.id == s.id;
    final runId = route.runId;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isNext ? primary : borderColor, width: isNext ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                s.arrived ? Icons.check_circle_rounded : (isNext ? Icons.navigation_rounded : Icons.circle_outlined),
                color: s.arrived ? Colors.green.shade600 : (isNext ? primary : subTextColor),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s.seq}. ${s.name}',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: textColor)),
                    Text(
                      [
                        if (s.scheduledTime != null) _clock(s.scheduledTime),
                        if (isNext) appState.tr('school_next_stop'),
                        if (s.arrived) appState.tr('school_arrived'),
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                  ],
                ),
              ),
              if (isNext && !s.arrived && runId != null)
                TextButton(
                  onPressed: _busy ? null : () => _run(() => _service.markArrived(runId, s.id)),
                  child: Text(appState.tr('school_mark_arrived')),
                ),
            ],
          ),
          if (s.students.isNotEmpty) ...[
            const SizedBox(height: 6),
            // Attendance colors (user rule, 2026-10-09): blue = picked up /
            // dropped off (a pick-up is the day's attendance); red = the bus
            // reached the stop and the student wasn't marked -- absent at a
            // pick-up, or STILL ON THE BUS at a drop-off -- so nobody is
            // ever forgotten. Not reached yet: neutral.
            for (final st in s.students)
              Builder(builder: (_) {
                final missed = !st.done && (s.arrived || route.completed);
                final color = st.done
                    ? Colors.blue.shade700
                    : missed
                        ? Colors.red.shade700
                        : subTextColor;
                final status = st.action == 'board'
                    ? (st.done ? 'school_present' : missed ? 'school_absent' : 'school_got_on')
                    : (st.done ? 'school_dropped_off' : missed ? 'school_not_dropped' : 'school_got_off');
                return Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: (st.done || missed) ? color.withValues(alpha: 0.08) : null,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(left: BorderSide(color: color, width: 4)),
                  ),
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 4),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.blue.shade700,
                    value: st.done,
                    onChanged: (!route.inProgress || runId == null || _busy)
                        ? null
                        : (v) => _run(() => _service.setRider(runId, s.id, st.id, st.action, v ?? false)),
                    title: Text(st.name, style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      appState.tr(status) +
                          (st.grade != null ? ' · ${appState.tr('school_grade')} ${st.grade}' : ''),
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }
}
