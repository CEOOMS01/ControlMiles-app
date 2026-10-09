// Olympus Mont Systems LLC - ControlMiles
// lib/screens/driver_operations_screen.dart
//
// Dedicated home screen for fleet_driver accounts -- explicit user
// requirement: pre-trip checklist, start tracking, mid-trip incident
// reporting, live self-location map, and nothing else (Settings is
// reachable, but scoped down to just language + dark mode, see
// driver_settings_sheet.dart).
//
// This REVERSES Fleet Phase 3's own decision to reuse DashboardScreen
// for fleet_driver (that phase deliberately deleted a separate
// FleetDriverHomeScreen once sharing worked) -- flagged here explicitly
// rather than silently diverging, since that earlier decision has its
// own detailed rationale in tracking_controller.dart/app_routes.dart.
// The difference this time: the earlier screen was a thin placeholder
// with nothing Dashboard didn't already do; this one is a genuinely
// different, deliberately restricted operational flow, not a
// duplicate of Dashboard's gig-app-carousel/reports/settings surface.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/app_state.dart';
import '../models/vehicle.dart';
import 'fuel_purchase_capture_screen.dart';
import '../routes/app_routes.dart';
import '../models/vehicle_inspection.dart';
import '../services/vehicle_service.dart';
import '../services/inspection_service.dart';
import '../services/shift_block_service.dart';
import '../errors/app_error.dart';
import '../tracking/tracking_controller.dart';
import '../services/driver_notification_service.dart';
import 'driver_notifications_screen.dart';
import '../widgets/tracking_action_button.dart';
import '../widgets/driver_live_map_view.dart';
import '../widgets/org_mode_switcher.dart';
import '../widgets/school_routes_card.dart';
import 'fleet_vehicle_picker_screen.dart';
import 'register_own_vehicle_screen.dart';
import 'vehicle_inspection_screen.dart';
import 'inspection_detail_screen.dart';
import 'report_incident_sheet.dart';
import 'driver_settings_sheet.dart';

class DriverOperationsScreen extends StatefulWidget {
  const DriverOperationsScreen({super.key});

  @override
  State<DriverOperationsScreen> createState() => _DriverOperationsScreenState();
}

class _DriverOperationsScreenState extends State<DriverOperationsScreen>
    with WidgetsBindingObserver {
  final _vehicleService = VehicleService();
  final _inspectionService = InspectionService();
  Vehicle? _vehicle;
  VehicleInspection? _latestInspection;
  bool _isLoadingVehicle = true;
  bool _tripIsActive = false;
  bool _revocationDialogShown = false;

  // Fleet Sprint 4 (open/rotating vehicle assignment, 2026-09-09): only
  // relevant when the org's vehicle_assignment_mode is 'open' (web-admin
  // configured) AND this driver has no fixed assignment. _openModeVehicleId
  // is the driver's own per-trip pick (FleetVehiclePickerScreen), threaded
  // into TrackingActionButton -- never written to
  // vehicles.assigned_driver_id, and resets naturally each time this
  // screen is recreated (after ShiftEndedScreen -> "Start next shift").
  bool _openAssignmentMode = false;
  String? _openModeVehicleId;

  // Shift schedule (2026-09-30): with no fixed assignment, today's
  // scheduled shift (web Shifts page) supplies the vehicle -- from 60 min
  // before it starts until it ends, in the fleet's timezone. _todayShift
  // is shown on screen; 'upcoming' explains when the driver can start.
  Map<String, dynamic>? _todayShift;
  // Owner-operators: the fleet allows drivers to register their own truck.
  bool _ownVehicleAllowed = false;
  // Fleet setting (defaulted by profile, 2026-09-30): car fleets don't
  // require a daily pre-trip inspection; trucks/buses/construction do.
  bool _pretripRequired = true;

  // Hourly classes (fleet shift blocks, 2026-09-29). Null until loaded, and
  // empty (hasBlocks == false) for a fleet without a class schedule today --
  // then this screen behaves exactly as before (one trip = one turno).
  final _shiftService = ShiftBlockService();

  // Driver messages (2026-09-30): after-trip safety notes + the 15-day
  // summary, behind the bell in the app bar -- not a card on this screen.
  final _notificationService = DriverNotificationService();
  int _unreadMessages = 0;
  ShiftDay? _shiftDay;
  Timer? _shiftTicker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tripIsActive = TrackingController.currentState != TrackingState.idle;
    _loadVehicle();
    _loadShiftDay();
    _loadUnreadMessages();
    // "Open to start" / "Missed" depend on the clock, not only on data.
    _shiftTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && (_shiftDay?.hasBlocks ?? false)) setState(() {});
    });
  }

  @override
  void dispose() {
    _shiftTicker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadShiftDay() async {
    final orgId = context.read<AppState>().defaultOrgId;
    if (orgId == null) return;
    try {
      final day = await _shiftService.getMyDay(orgId);
      if (mounted) setState(() => _shiftDay = day);
    } catch (e) {
      debugPrint('[DriverOps] shift day load failed: $e');
    }
  }

  /// TrackingActionButton.startShiftBlock: null = no class schedule (plain
  /// trip); '' = nothing can start now (driver told why); else the class id.
  Future<String?> _startShiftBlock() async {
    final appState = context.read<AppState>();
    await _loadShiftDay();
    final day = _shiftDay;
    if (day == null || !day.hasBlocks) return null;
    final now = DateTime.now();
    final block = day.openToStart(now);
    if (block == null) {
      final next = day.nextUpcoming(now);
      final msg = next == null
          ? appState.tr('shift_no_more_classes')
          : appState.tr('shift_next_opens_at').replaceFirst('{time}', _clock(next.opensAt));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      return '';
    }
    await _shiftService.start(block.id);
    return block.id;
  }

  Future<void> _onShiftBlockStartFailed(String blockId) async {
    try {
      await _shiftService.abortStart(blockId);
    } catch (e) {
      debugPrint('[DriverOps] abort class start failed: $e');
    }
    await _loadShiftDay();
  }

  /// Class schedule: ending a trip ends the class and keeps the day open
  /// (no GPS until the next class). Without a schedule: the old turno end.
  Future<void> _onTripEnded() async {
    final orgId = context.read<AppState>().defaultOrgId;
    if (orgId != null) {
      try {
        final day = await _shiftService.getMyDay(orgId);
        final current = day.inProgress;
        if (current != null) await _shiftService.end(current.id);
        if (day.hasBlocks) {
          await _loadShiftDay();
          if (mounted) setState(() => _tripIsActive = false);
          return;
        }
      } catch (e) {
        debugPrint('[DriverOps] ending class failed: $e');
      }
    }
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.shiftEnded, (route) => false);
  }

  Future<void> _endDay(AppState appState) async {
    final orgId = appState.defaultOrgId;
    if (orgId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appState.tr('shift_end_day_confirm_title')),
        content: Text(appState.tr('shift_end_day_confirm_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(appState.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(appState.tr('shift_end_day'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _shiftService.closeDay(orgId);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.shiftEnded, (route) => false);
    } catch (e) {
      if (!mounted) return;
      final err = AppError.from(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.display(appState.tr(err.messageKey))), backgroundColor: Colors.red),
      );
    }
  }

  String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  String _wallClock(String hhmmss) {
    final parts = hhmmss.split(':');
    final hour = int.parse(parts[0]);
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${parts[1]} ${hour < 12 ? 'AM' : 'PM'}';
  }

  Widget _buildClassesCard(
    AppState appState,
    Color cardColor,
    Color textColor,
    Color subTextColor,
    Color borderColor,
  ) {
    final day = _shiftDay!;
    final now = DateTime.now();
    final primary = Theme.of(context).colorScheme.primary;

    ({String label, Color color}) chip(ShiftBlock b) {
      final late = (b.lateMinutes ?? 0) > 0
          ? ' · ${appState.tr('shift_class_late').replaceFirst('{min}', '${b.lateMinutes}')}'
          : '';
      if (b.isInProgress) return (label: appState.tr('shift_class_in_progress') + late, color: primary);
      if (b.isDone) return (label: appState.tr('shift_class_done') + late, color: Colors.green.shade700);
      if (b.isMissed(now)) return (label: appState.tr('shift_class_missed'), color: Colors.red.shade700);
      if (b.isOpenToStart(now)) return (label: appState.tr('shift_class_open'), color: Colors.orange.shade800);
      return (label: appState.tr('shift_class_scheduled'), color: subTextColor);
    }

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
            appState.tr('shift_classes_today').toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: subTextColor),
          ),
          const SizedBox(height: 10),
          for (final b in day.blocks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_wallClock(b.startTime)} – ${_wallClock(b.endTime)}',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor),
                        ),
                        if ((b.note ?? '').isNotEmpty || b.vehicleText.isNotEmpty)
                          Text(
                            [b.note ?? '', b.vehicleText].where((x) => x.isNotEmpty).join(' · '),
                            style: TextStyle(fontSize: 12, color: subTextColor),
                          ),
                      ],
                    ),
                  ),
                  Builder(builder: (_) {
                    final c = chip(b);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        c.label,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.color),
                      ),
                    );
                  }),
                ],
              ),
            ),
          if (day.workdayOpen && !_tripIsActive) ...[
            const SizedBox(height: 10),
            Text(appState.tr('shift_between_classes'), style: TextStyle(fontSize: 12, color: subTextColor)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _endDay(appState),
                icon: const Icon(Icons.logout_rounded),
                label: Text(appState.tr('shift_end_day')),
              ),
            ),
          ],
          if (day.workdayClosed) ...[
            const SizedBox(height: 10),
            Text(
              appState.tr('shift_day_closed'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: subTextColor),
            ),
          ],
        ],
      ),
    );
  }

  // Fleet Sprint 3 (revocation, explicit user requirement, 2026-09-09):
  // "check-on-next-action" -- app foreground is the most common re-entry
  // point, so this is what makes revocation feel immediate in practice
  // without a persistent Realtime subscription. Deliberately does NOT
  // interrupt an already-active trip (the DB trigger only blocks a NEW
  // session insert, never touches one already open) -- only warns and
  // blocks the NEXT one.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkMembershipStillActive();
      _loadUnreadMessages();
    }
  }

  Future<void> _checkMembershipStillActive() async {
    if (_revocationDialogShown || !mounted) return;
    final appState = context.read<AppState>();
    final orgId = appState.defaultOrgId;
    if (!appState.isFleetDriver || orgId == null) return;

    try {
      final stillActive = await Supabase.instance.client
          .rpc('check_active_org_membership', params: {'p_org_id': orgId});
      if (stillActive == true || !mounted) return;

      _revocationDialogShown = true;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(appState.tr('org_access_revoked_title')),
            content: Text(appState.tr('org_access_revoked_body')),
            actions: [
              FilledButton(
                onPressed: () async {
                  // BUG FIX (pedido explícito, logout que no navega):
                  // capturar el Navigator raíz ANTES del await, no el
                  // context puntual del diálogo -- ver el mismo fix en
                  // main_drawer.dart para el detalle completo del bug.
                  final rootNavigator = Navigator.of(dialogContext, rootNavigator: true);
                  await appState.signOutAndClear();
                  rootNavigator.pushNamedAndRemoveUntil(
                    AppRoutes.login,
                    (route) => false,
                  );
                },
                child: Text(appState.tr('sign_out')),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      // Fails open -- a lookup hiccup must never lock out a still-active
      // driver; the DB trigger remains the real floor regardless.
    }
  }

  Future<void> _loadUnreadMessages() async {
    try {
      final n = await _notificationService.unreadCount();
      if (mounted) setState(() => _unreadMessages = n);
    } catch (e) {
      debugPrint('[DriverOps] unread messages failed: $e');
    }
  }

  Future<void> _openMessages() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverNotificationsScreen()));
    _loadUnreadMessages();
  }

  Future<void> _loadVehicle() async {
    final appState = context.read<AppState>();
    final userId = appState.currentUserId;
    final orgId = appState.defaultOrgId;
    if (userId == null) return;

    final vehicle = await _vehicleService.getActiveOrAssignedVehicle(
      userId,
      organizationId: orgId,
    );

    // Today's scheduled shift: its vehicle when there's no fixed
    // assignment; shown either way so the driver knows their hours.
    Map<String, dynamic>? todayShift;
    Vehicle? resolved = vehicle;
    var ownAllowed = false;
    var pretripRequired = true;
    if (orgId != null) {
      try {
        final rows = await Supabase.instance.client.rpc('my_shift_today', params: {'p_organization_id': orgId});
        if (rows is List && rows.isNotEmpty) {
          todayShift = Map<String, dynamic>.from(rows.first as Map);
          final shiftVehicle = todayShift['vehicle_id'] as String?;
          if (resolved == null && todayShift['status'] == 'open' && shiftVehicle != null) {
            resolved = await _vehicleService.getActiveOrAssignedVehicle(
              userId,
              organizationId: orgId,
              preSelectedVehicleId: shiftVehicle,
            );
          }
        }
      } catch (e) {
        debugPrint('[DriverOps] today shift lookup failed: $e');
      }
      try {
        final org = await Supabase.instance.client
            .from('organizations')
            .select('allow_driver_owned_vehicles, require_pretrip_inspection')
            .eq('id', orgId)
            .maybeSingle();
        ownAllowed = (org?['allow_driver_owned_vehicles'] as bool?) ?? false;
        pretripRequired = (org?['require_pretrip_inspection'] as bool?) ?? true;
      } catch (_) {}
    }

    // Fleet Sprint 4: no fixed assignment found -- check whether this
    // org even allows picking one before offering that UI at all.
    var openMode = false;
    if (resolved == null && orgId != null) {
      final assignmentMode = await _vehicleService.getVehicleAssignmentMode(orgId);
      openMode = assignmentMode == 'open';
    }

    // Read-only ("modo lectura del lado del conductor" -- explicit user
    // requirement): the last inspection on record for this vehicle,
    // theirs or a previous driver's. RLS alone decides what this can
    // ever return -- see vehicle_inspections_select_assigned_vehicle_latest.
    final latestInspection =
        resolved != null ? await _inspectionService.getLatestForVehicle(resolved.id) : null;

    if (mounted) {
      setState(() {
        _vehicle = resolved;
        _todayShift = todayShift;
        _ownVehicleAllowed = ownAllowed;
        _pretripRequired = pretripRequired;
        // A shift's vehicle rides into the trip the same way an
        // open-mode pick does.
        if (vehicle == null && resolved != null) _openModeVehicleId = resolved.id;
        _latestInspection = latestInspection;
        _isLoadingVehicle = false;
        _openAssignmentMode = openMode;
      });
    }
  }

  Future<void> _pickVehicle() async {
    final appState = context.read<AppState>();
    final orgId = appState.defaultOrgId;
    if (orgId == null) return;

    final picked = await Navigator.push<Vehicle>(
      context,
      MaterialPageRoute(builder: (_) => FleetVehiclePickerScreen(organizationId: orgId)),
    );
    if (picked == null || !mounted) return;

    final latestInspection = await _inspectionService.getLatestForVehicle(picked.id);
    if (mounted) {
      setState(() {
        _vehicle = picked;
        _openModeVehicleId = picked.id;
        _latestInspection = latestInspection;
      });
    }
  }

  Future<void> _startInspection(AppState appState, Vehicle vehicle) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VehicleInspectionScreen(vehicle: vehicle)),
    );
    // Refresh only this vehicle's inspection. Reloading the whole screen
    // (as before, 2026-09-30 fix) dropped a vehicle picked in 'open'
    // assignment mode -- it isn't an assignment -- and left the driver
    // with no vehicle and no way to start.
    final latest = await _inspectionService.getLatestForVehicle(vehicle.id);
    if (mounted) setState(() => _latestInspection = latest);
  }

  /// Today's latest inspection for this vehicle is a passing pre-trip.
  bool get _preTripPassedToday {
    final inspection = _latestInspection;
    if (inspection == null || inspection.inspectionType != 'pre_trip' || !inspection.isPass) {
      return false;
    }
    final today = DateTime.now();
    final submitted = inspection.createdAt.toLocal();
    return submitted.year == today.year && submitted.month == today.month && submitted.day == today.day;
  }

  /// Today's pre-trip found a defect.
  bool get _preTripFailedToday {
    final inspection = _latestInspection;
    if (inspection == null || inspection.inspectionType != 'pre_trip' || inspection.isPass) return false;
    final today = DateTime.now();
    final submitted = inspection.createdAt.toLocal();
    return submitted.year == today.year && submitted.month == today.month && submitted.day == today.day;
  }

  /// The step the driver must do before a trip, made visible (2026-09-30:
  /// "no hay forma de hacer el pre-trip inspection, debe visualizarse").
  /// No vehicle -> say so (fixed mode: the admin assigns one on the web);
  /// vehicle but no passing pre-trip today -> the inspection is step 1.
  Widget? _buildNextStepCard(AppState appState, Color textColor, Color subTextColor) {
    if (_tripIsActive) return null;
    if (_vehicle == null) {
      if (_openAssignmentMode) return null; // the "Select vehicle" button is the step
      final shift = _todayShift;
      final upcoming = shift != null && shift['status'] == 'upcoming';
      return _stepCard(
        icon: upcoming ? Icons.schedule_rounded : Icons.no_transfer_rounded,
        color: const Color(0xFFB45309),
        title: appState.tr(upcoming ? 'driver_shift_upcoming_title' : 'driver_no_vehicle_title'),
        body: upcoming
            ? appState
                .tr('driver_shift_upcoming_body')
                .replaceFirst('{start}', _hhmm(shift['start_time']))
                .replaceFirst('{end}', _hhmm(shift['end_time']))
            : appState.tr('driver_no_vehicle_body'),
        textColor: textColor,
        subTextColor: subTextColor,
        action: _ownVehicleAllowed && !upcoming
            ? SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _registerOwnVehicle(),
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: Text(
                    appState.tr('own_vehicle_button').toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              )
            : null,
      );
    }
    if (_preTripPassedToday) return null;
    final failed = _preTripFailedToday;
    // Optional inspection: only surface a failed one (the defect matters).
    if (!_pretripRequired && !failed) return null;
    return _stepCard(
      icon: failed ? Icons.error_rounded : Icons.fact_check_rounded,
      color: failed ? const Color(0xFFDC2626) : Theme.of(context).colorScheme.primary,
      title: appState.tr(failed ? 'pretrip_failed_title' : 'pretrip_required_title'),
      body: appState.tr(failed ? 'pretrip_failed_body' : 'pretrip_required_body'),
      textColor: textColor,
      subTextColor: subTextColor,
      action: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _startInspection(appState, _vehicle!),
          icon: const Icon(Icons.checklist_rounded, size: 18),
          label: Text(
            appState.tr(failed ? 'pretrip_redo_button' : 'pretrip_start_button').toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: failed ? const Color(0xFFDC2626) : Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  String _hhmm(dynamic t) {
    final s = (t as String?) ?? '';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  Future<void> _registerOwnVehicle() async {
    final orgId = context.read<AppState>().defaultOrgId;
    if (orgId == null) return;
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RegisterOwnVehicleScreen(organizationId: orgId)),
    );
    if (created == true && mounted) {
      setState(() => _isLoadingVehicle = true);
      await _loadVehicle();
    }
  }

  Widget _stepCard({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    required Color textColor,
    required Color subTextColor,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(fontSize: 12.5, height: 1.35, color: subTextColor)),
          if (action != null) ...[const SizedBox(height: 12), action],
        ],
      ),
    );
  }

  Future<void> _logFuelPurchase(Vehicle vehicle) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FuelPurchaseCaptureScreen(vehicle: vehicle)),
    );
  }

  void _viewLatestInspection() {
    if (_latestInspection == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionDetailScreen(
          inspection: _latestInspection!,
          vehicleName: _vehicle?.displayName ?? '',
        ),
      ),
    );
  }

  // Roadmap gap closed (pedido explícito, "de mas dificil a mas facil"):
  // v1 recorded inspections but never actually gated trip start on them
  // (see vehicle_inspection.dart's own comment). Requires today's latest
  // inspection for THIS vehicle to be a passing pre-trip check --
  // post-trip or a stale prior day's pass don't count, matching real DVIR
  // practice (a fresh pre-trip check each day/vehicle change).
  Future<bool> _canStartTrip() async {
    if (!_pretripRequired) return true;
    final inspection = _latestInspection;
    if (inspection == null) return false;
    if (inspection.inspectionType != 'pre_trip') return false;
    if (!inspection.isPass) return false;

    final today = DateTime.now();
    final submitted = inspection.createdAt.toLocal();
    return submitted.year == today.year &&
        submitted.month == today.month &&
        submitted.day == today.day;
  }

  void _reportIncident(AppState appState) {
    final orgId = appState.defaultOrgId;
    if (orgId == null) return;
    showReportIncidentSheet(
      context,
      organizationId: orgId,
      sessionId: TrackingController.activeSessionId,
      vehicleId: _vehicle?.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF12100C) : const Color(0xFFFAF6EE);
    final cardColor = isDark ? const Color(0xFF1C1812) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF6B6250);
    final borderColor = isDark ? const Color(0xFF2E281F) : const Color(0xFFE3D9C4);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          appState.tr('driver_ops_title').toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        backgroundColor: isDark ? const Color(0xFF1F4E6F) : const Color(0xFF2C6C99),
        foregroundColor: Colors.white,
        // Brand-blue header with a rounded bottom (warm palette, 2026-10-09).
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(22))),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: appState.tr('notif_title'),
            onPressed: _openMessages,
            icon: Badge(
              isLabelVisible: _unreadMessages > 0,
              label: Text('$_unreadMessages'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showDriverSettingsSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingVehicle
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Fleet Sprint 2 (dual-mode UX, 2026-09-09): only renders
                  // for a genuine hybrid driver (real personal trip
                  // history on file) -- an exclusive corporate driver
                  // invited straight into Fleet mode sees nothing here,
                  // matching the spec's "no necesita configurar vehículos
                  // personales" requirement. See OrgModeSwitcher's own
                  // header comment for the exact eligibility check.
                  const OrgModeSwitcher(),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_shipping_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _vehicle?.displayName ?? appState.tr('fleet_no_vehicle_assigned'),
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
                              ),
                              if (_vehicle?.displayId != null)
                                Text(
                                  _vehicle!.displayId!,
                                  style: TextStyle(fontSize: 12, color: subTextColor),
                                ),
                              if (_todayShift != null)
                                Text(
                                  appState
                                      .tr('driver_shift_today')
                                      .replaceFirst('{start}', _hhmm(_todayShift!['start_time']))
                                      .replaceFirst('{end}', _hhmm(_todayShift!['end_time'])),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: subTextColor),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_buildNextStepCard(appState, textColor, subTextColor) case final step?) ...[
                    step,
                    const SizedBox(height: 12),
                  ],
                  // Fleet Sprint 4: only offered when this org is 'open'
                  // mode and no fixed assignment resolved -- 'fixed'-mode
                  // drivers and drivers with a real assignment never see
                  // this button at all.
                  if (_vehicle == null && _openAssignmentMode)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _pickVehicle,
                        icon: const Icon(Icons.local_shipping_rounded, size: 18),
                        label: Text(
                          appState.tr('fleet_select_vehicle_button').toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  if (_vehicle != null && (_preTripPassedToday || !_pretripRequired))
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _startInspection(appState, _vehicle!),
                        icon: const Icon(Icons.checklist_rounded, size: 18),
                        label: Text(
                          appState.tr('inspection_start').toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                  if (_vehicle != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _logFuelPurchase(_vehicle!),
                        icon: const Icon(Icons.receipt_long_rounded, size: 18),
                        label: Text(
                          appState.tr('fuel_log_purchase_button').toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                  ],
                  if (_latestInspection != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _viewLatestInspection,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _latestInspection!.isPass
                                ? borderColor
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _latestInspection!.isPass
                                  ? Icons.check_circle_rounded
                                  : Icons.error_rounded,
                              size: 18,
                              color: _latestInspection!.isPass
                                  ? Colors.green.shade600
                                  : Colors.red.shade600,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                appState.tr(
                                  _latestInspection!.isPass
                                      ? 'inspection_result_pass'
                                      : 'inspection_result_fail',
                                ),
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: textColor),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: subTextColor, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_shiftDay?.hasBlocks ?? false) ...[
                    const SizedBox(height: 20),
                    _buildClassesCard(appState, cardColor, textColor, subTextColor, borderColor),
                  ],
                  // School transportation (2026-10-09): today's school
                  // routes; renders nothing when the driver has none.
                  if (appState.defaultOrgId != null) ...[
                    const SizedBox(height: 20),
                    SchoolRoutesCard(organizationId: appState.defaultOrgId!, tripIsActive: _tripIsActive),
                  ],
                  const SizedBox(height: 28),
                  // A closed day can't start anything (DB: WORKDAY_ALREADY_CLOSED).
                  if (!(_shiftDay?.workdayClosed ?? false) && (_vehicle != null || _tripIsActive))
                  Center(
                    child: TrackingActionButton(
                      // A fleet-ops trip has no gig-platform to pick --
                      // 'custom' + 'business' is the only sensible default
                      // in this context, not a choice the driver needs to
                      // make (the whole point of this screen is to remove
                      // that decision, not ask it via a different UI).
                      selectedGigApp: 'custom',
                      selectedIrsPurpose: 'business',
                      // A class's own vehicle wins over the driver's pick.
                      preSelectedVehicleId:
                          _shiftDay?.openToStart(DateTime.now())?.vehicleId ?? _openModeVehicleId,
                      startShiftBlock: _startShiftBlock,
                      onShiftBlockStartFailed: _onShiftBlockStartFailed,
                      canStart: _canStartTrip,
                      cannotStartMessage: appState.tr('dvir_required_before_start'),
                      onTripStarted: () => setState(() => _tripIsActive = true),
                      // Fleet Sprint 3 (shift-scoped privacy, explicit
                      // user request, 2026-09-09): ending a turno navigates
                      // straight to the ShiftEndedScreen dead end -- fires
                      // after any mandatory weekly odometer-close dialog
                      // already resolved (see tracking_action_button.dart's
                      // reordering of this exact callback). Gig's Dashboard
                      // never does this -- scoped to fleet_driver only.
                      // Hourly classes (2026-09-29): with a class schedule,
                      // ending the trip ends the class and the day stays
                      // open -- see _onTripEnded.
                      onTripEnded: _onTripEnded,
                    ),
                  ),
                  if (_tripIsActive) ...[
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _reportIncident(appState),
                        icon: const Icon(Icons.report_problem_outlined, color: Colors.red),
                        label: Text(
                          appState.tr('report_incident_button'),
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      appState.tr('driver_ops_live_location').toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: subTextColor),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(height: 320, child: const DriverLiveMapView()),
                  ],
                ],
              ),
      ),
    );
  }
}
