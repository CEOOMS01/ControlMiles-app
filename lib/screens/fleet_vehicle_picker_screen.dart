// Olympus Mont Systems LLC - ControlMiles
// lib/screens/fleet_vehicle_picker_screen.dart
//
// Fleet Sprint 4 (open/rotating vehicle assignment, explicit user
// requirement, 2026-09-09): reached from DriverOperationsScreen only when
// the org's vehicle_assignment_mode is 'open' (admin-configured
// exclusively on the web dashboard, per the standing rule) AND this
// driver has no fixed assignment. Lists the org's vehicles that aren't
// currently claimed by another driver's open session (see
// VehicleService.listAvailableFleetVehicles), driver taps one, pops the
// chosen Vehicle back to the caller. A driver's own choice for THIS
// trip, not a standing assignment -- nothing here writes to
// vehicles.assigned_driver_id.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../models/vehicle.dart';
import '../services/vehicle_service.dart';

class FleetVehiclePickerScreen extends StatefulWidget {
  final String organizationId;

  const FleetVehiclePickerScreen({super.key, required this.organizationId});

  @override
  State<FleetVehiclePickerScreen> createState() => _FleetVehiclePickerScreenState();
}

class _FleetVehiclePickerScreenState extends State<FleetVehiclePickerScreen> {
  final _vehicleService = VehicleService();
  List<Vehicle> _vehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final vehicles = await _vehicleService.listAvailableFleetVehicles(widget.organizationId);
    if (mounted) {
      setState(() {
        _vehicles = vehicles;
        _isLoading = false;
      });
    }
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
        title: Text(appState.tr('fleet_vehicle_picker_title')),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _vehicles.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        appState.tr('fleet_vehicle_picker_empty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: subTextColor, fontSize: 14),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _vehicles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final vehicle = _vehicles[index];
                      return Material(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(context, vehicle),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.local_shipping_rounded,
                                    color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vehicle.displayName,
                                        style: TextStyle(
                                            fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
                                      ),
                                      if (vehicle.displayId != null)
                                        Text(
                                          vehicle.displayId!,
                                          style: TextStyle(fontSize: 12, color: subTextColor),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: subTextColor),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
