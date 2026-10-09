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
//
// Day colors (user rule + 4 adjustments, 2026-10-09; computed by the
// server): blue = on track; red = rode this morning but hasn't come out for
// the PM bus (go ask at the school) or not dropped off; yellow = didn't ride
// this morning -- not expected, a stop with only yellow riders can be
// skipped, but the driver can still board them; gray = red resolved with a
// reason (parent pick-up, early dismissal, activity, other). The route
// can't be finished with a child on board or an unresolved red.
//
// 2026-10-09 (plan section 8):
//  * Countdown: when the bus reaches a stop, students have 5 minutes to come
//    out (server grace period); the stop shows the time left, and the screen
//    refreshes the moment it ends.
//  * Bus monitor (route.isMonitor): keeps the list of the run the driver
//    started; no "Mark arrived", no "Finish route".
//  * Driver: the list locks while the bus is moving (over ~7 mph) -- marking
//    is done stopped, or by the monitor.

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
  // Countdown + driving lock.
  Timer? _secondTicker;
  StreamSubscription<geo.Position>? _positionSub;
  bool _moving = false;
  DateTime? _lastPositionAt;
  static const _movingSpeed = 3.0; // m/s, ~7 mph

  @override
  void initState() {
    super.initState();
    _refresh();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
    _secondTicker = Timer.periodic(const Duration(seconds: 1), (_) => _everySecond());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _secondTicker?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  void _everySecond() {
    if (!mounted) return;
    final route = _route;
    // No fresh position for 20 s: assume stopped (GPS lost, app paused).
    if (_moving && (_lastPositionAt == null || DateTime.now().difference(_lastPositionAt!).inSeconds > 20)) {
      setState(() => _moving = false);
    }
    if (route == null || !route.inProgress) return;
    final now = DateTime.now();
    var counting = false;
    var justEnded = false;
    for (final st in route.stops) {
      final left = st.graceLeft(now);
      if (left != null) {
        counting = true;
        if (left.inMilliseconds <= 1000) justEnded = true;
      }
    }
    if (counting) setState(() {});
    // The server decides red / absent at the end of the grace period.
    if (justEnded) Future.delayed(const Duration(seconds: 2), _refresh);
  }

  /// Driver only: lock the list while the bus moves.
  Future<void> _watchSpeed(SchoolRoute route) async {
    if (_positionSub != null || route.isMonitor || !route.inProgress) return;
    try {
      final permission = await geo.Geolocator.checkPermission();
      if (permission != geo.LocationPermission.always && permission != geo.LocationPermission.whileInUse) return;
      _positionSub = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(accuracy: geo.LocationAccuracy.high, distanceFilter: 5),
      ).listen((pos) {
        _lastPositionAt = DateTime.now();
        final moving = pos.speed > _movingSpeed;
        if (mounted && moving != _moving) setState(() => _moving = moving);
      }, onError: (e) => debugPrint('[SchoolRun] position stream: $e'));
    } catch (e) {
      debugPrint('[SchoolRun] speed watch failed: $e');
    }
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
        if (route != null) _watchSpeed(route);
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
    if (route == null) return;
    // Not running (a monitor waiting for the driver) or a monitor: refresh
    // only -- stop arrival is the driver's (and the server's).
    if (runId == null || !route.inProgress || route.isMonitor) {
      await _refresh();
      return;
    }
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
      final raw = e.toString();
      final String message;
      if (raw.contains('STUDENTS_STILL_ON_BOARD')) {
        message = appState.tr('school_err_on_board');
      } else if (raw.contains('UNRESOLVED_STUDENTS')) {
        message = appState.tr('school_err_unresolved');
      } else {
        final err = AppError.from(e);
        message = err.display(appState.tr(err.messageKey));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
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
              if (route.unresolved > 0) ...[
                const SizedBox(height: 10),
                Text(
                  appState.tr('school_unresolved_count').replaceFirst('{n}', '${route.unresolved}'),
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

  static const _reasons = ['parent_pickup', 'early_dismissal', 'activity', 'other'];

  /// Resolve a red (or expected) PM rider who won't ride: a reason turns
  /// them gray and counts as attendance.
  Future<void> _release(AppState appState, String runId, SchoolStop stop, SchoolStudent st) async {
    String? reason;
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(appState.tr('school_release_title').replaceFirst('{name}', st.name)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioGroup<String>(
                  groupValue: reason,
                  onChanged: (v) => setLocal(() => reason = v),
                  child: Column(
                    children: [
                      for (final r in _reasons)
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: r,
                          title: Text(appState.tr('school_reason_$r')),
                        ),
                    ],
                  ),
                ),
                TextField(
                  controller: noteCtrl,
                  maxLength: 300,
                  onChanged: (_) => setLocal(() {}),
                  decoration: InputDecoration(labelText: appState.tr('school_release_note')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(appState.tr('cancel'))),
            FilledButton(
              onPressed: reason == null || (reason == 'other' && noteCtrl.text.trim().isEmpty)
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: Text(appState.tr('save')),
            ),
          ],
        ),
      ),
    );
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (ok != true || reason == null) return;
    await _run(() => _service.setRider(runId, stop.id, st.id, 'released', true,
        reason: reason, note: note.isEmpty ? null : note));
  }

  Widget _banner(String text, IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
          ],
        ),
      );

  String _clock(String? hhmmss) {
    if (hhmmss == null || hhmmss.length < 5) return '';
    final h = int.parse(hhmmss.substring(0, 2));
    return '${h % 12 == 0 ? 12 : h % 12}:${hhmmss.substring(3, 5)} ${h < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1C1812) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF6B6250);
    final borderColor = isDark ? const Color(0xFF2E281F) : const Color(0xFFE3D9C4);
    final primary = Theme.of(context).colorScheme.primary;
    final route = _route;

    return Scaffold(
      appBar: AppBar(
        title: Text(route?.name ?? appState.tr('school_routes_today')),
        backgroundColor: isDark ? const Color(0xFF1C1812) : const Color(0xFF211C14),
        foregroundColor: Colors.white,
        // Website-style ink header with a rounded bottom (warm palette, 2026-10-09).
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(22))),
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
                        if (route.isMonitor) ...[
                          const SizedBox(height: 8),
                          _banner(
                            route.inProgress ? appState.tr('school_monitor_view') : appState.tr('monitor_waiting_driver'),
                            Icons.badge_rounded,
                            primary,
                          ),
                        ],
                        if (!route.isMonitor && _moving && route.inProgress) ...[
                          const SizedBox(height: 8),
                          _banner(appState.tr('school_driving_locked'), Icons.do_not_touch_rounded, Colors.orange.shade800),
                        ],
                        const SizedBox(height: 12),
                        for (final s in route.stops) ...[
                          _stopCard(appState, route, s, cardColor, textColor, subTextColor, borderColor, primary),
                          const SizedBox(height: 10),
                        ],
                        if (route.inProgress && !route.isMonitor) ...[
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
                        if (!s.arrived && s.skippable) appState.tr('school_skip_stop'),
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                    if (route.inProgress && s.graceLeft(DateTime.now()) != null)
                      Builder(builder: (_) {
                        final left = s.graceLeft(DateTime.now())!;
                        final mmss =
                            '${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';
                        return Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_rounded, size: 16, color: Colors.orange.shade800),
                              const SizedBox(width: 6),
                              Text(
                                appState.tr('school_countdown').replaceFirst('{time}', mmss),
                                style: TextStyle(fontWeight: FontWeight.w800, color: Colors.orange.shade800),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
              if (isNext && !s.arrived && runId != null && !route.isMonitor)
                TextButton(
                  onPressed: _busy ? null : () => _run(() => _service.markArrived(runId, s.id)),
                  child: Text(appState.tr('school_mark_arrived')),
                ),
            ],
          ),
          if (s.students.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final st in s.students)
              Builder(builder: (_) {
                final color = switch (st.status) {
                  'blue' => Colors.blue.shade700,
                  'red' => Colors.red.shade700,
                  'yellow' => Colors.amber.shade800,
                  'gray' => Colors.blueGrey.shade500,
                  _ => subTextColor,
                };
                final decided = const {'blue', 'red', 'yellow', 'gray'}.contains(st.status);
                final board = st.action == 'board';
                final String label;
                if (st.status == 'gray') {
                  label = '${appState.tr('school_released')}: ${appState.tr('school_reason_${st.releaseReason ?? 'other'}')}'
                      '${st.releaseNote != null ? ' · ${st.releaseNote}' : ''}';
                } else {
                  label = appState.tr(switch ((st.status, board)) {
                    ('blue', true) => 'school_present',
                    ('blue', false) => 'school_dropped_off',
                    ('red', true) => 'school_not_out',
                    ('red', false) => 'school_not_dropped',
                    ('yellow', true) when route.routeType == 'school_pm' => 'school_absent_today',
                    ('yellow', true) => 'school_absent',
                    ('yellow', false) => 'school_absent_today',
                    ('expected', _) => 'school_expected',
                    ('on_board', _) => 'school_on_bus',
                    (_, true) => 'school_got_on',
                    (_, false) => 'school_got_off',
                  });
                }
                // Driver: no taps while the bus moves (the monitor, or a stop).
                final canEdit = route.inProgress && runId != null && !_busy && (route.isMonitor || !_moving);
                // A PM rider expected (or red) can be resolved with a reason;
                // a released one can be undone.
                final canRelease = canEdit && board && route.routeType == 'school_pm' &&
                    (st.status == 'red' || st.status == 'expected');
                final canUndo = canEdit && board && st.status == 'gray';
                return Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: decided ? color.withValues(alpha: 0.08) : null,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(left: BorderSide(color: color, width: 4)),
                  ),
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 4),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.blue.shade700,
                    value: st.done,
                    // Yellow doesn't block: a parent may have taken them to school.
                    onChanged: canEdit
                        ? (v) => _run(() => _service.setRider(runId, s.id, st.id, st.action, v ?? false))
                        : null,
                    title: Text(st.name, style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      label + (st.grade != null ? ' · ${appState.tr('school_grade')} ${st.grade}' : ''),
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    secondary: canRelease
                        ? TextButton(
                            onPressed: () => _release(appState, runId, s, st),
                            child: Text(appState.tr('school_resolve')),
                          )
                        : canUndo
                            ? TextButton(
                                onPressed: () => _run(() => _service.setRider(runId, s.id, st.id, 'released', false)),
                                child: Text(appState.tr('school_undo')),
                              )
                            : null,
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }
}
