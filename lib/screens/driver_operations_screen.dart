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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../models/vehicle.dart';
import '../services/vehicle_service.dart';
import '../tracking/tracking_controller.dart';
import '../widgets/tracking_action_button.dart';
import '../widgets/driver_live_map_view.dart';
import 'vehicle_inspection_screen.dart';
import 'report_incident_sheet.dart';
import 'driver_settings_sheet.dart';

class DriverOperationsScreen extends StatefulWidget {
  const DriverOperationsScreen({super.key});

  @override
  State<DriverOperationsScreen> createState() => _DriverOperationsScreenState();
}

class _DriverOperationsScreenState extends State<DriverOperationsScreen> {
  final _vehicleService = VehicleService();
  Vehicle? _vehicle;
  bool _isLoadingVehicle = true;
  bool _tripIsActive = false;

  @override
  void initState() {
    super.initState();
    _tripIsActive = TrackingController.currentState != TrackingState.idle;
    _loadVehicle();
  }

  Future<void> _loadVehicle() async {
    final appState = context.read<AppState>();
    final userId = appState.currentUserId;
    if (userId == null) return;

    final vehicle = await _vehicleService.getActiveOrAssignedVehicle(
      userId,
      organizationId: appState.defaultOrgId,
    );

    if (mounted) {
      setState(() {
        _vehicle = vehicle;
        _isLoadingVehicle = false;
      });
    }
  }

  Future<void> _startInspection(AppState appState, Vehicle vehicle) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VehicleInspectionScreen(vehicle: vehicle)),
    );
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
    final bgColor = isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          appState.tr('driver_ops_title').toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_vehicle != null)
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
                  const SizedBox(height: 28),
                  Center(
                    child: TrackingActionButton(
                      // A fleet-ops trip has no gig-platform to pick --
                      // 'custom' + 'business' is the only sensible default
                      // in this context, not a choice the driver needs to
                      // make (the whole point of this screen is to remove
                      // that decision, not ask it via a different UI).
                      selectedGigApp: 'custom',
                      selectedIrsPurpose: 'business',
                      onTripStarted: () => setState(() => _tripIsActive = true),
                      onTripEnded: () {
                        setState(() => _tripIsActive = false);
                        _loadVehicle();
                      },
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
