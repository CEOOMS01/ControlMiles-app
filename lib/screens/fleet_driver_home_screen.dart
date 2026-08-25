// Olympus Mont Systems LLC - ControlMiles
// lib/screens/fleet_driver_home_screen.dart
//
// Fleet Phase 2 scope: shows the driver's assigned vehicle, or a waiting
// state if their admin hasn't assigned one yet. Deliberately does NOT wire
// into TrackingController/DashboardScreen's tracking flow yet -- making an
// assigned-not-owned vehicle work end-to-end with GPS tracking, the
// antifraud engine, and trip history is real integration work, scoped
// separately (Phase 3+), not silently half-done here.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../models/vehicle.dart';
import '../routes/app_routes.dart';
import '../services/organization_service.dart';

class FleetDriverHomeScreen extends StatefulWidget {
  const FleetDriverHomeScreen({super.key});

  @override
  State<FleetDriverHomeScreen> createState() => _FleetDriverHomeScreenState();
}

class _FleetDriverHomeScreenState extends State<FleetDriverHomeScreen> {
  final _organizationService = OrganizationService();
  bool _loading = true;
  Vehicle? _vehicle;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AppState>().currentUserId;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final vehicle = await _organizationService.getAssignedVehicle(userId);
      if (mounted) {
        setState(() {
          _vehicle = vehicle;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[FleetDriverHome] Load failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout(AppState appState) async {
    await appState.signOutAndClear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
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
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(appState.tr('app_name'), style: TextStyle(color: textColor, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: subTextColor),
            onPressed: () => _logout(appState),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      appState.tr('fleet_vehicle'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: subTextColor),
                    ),
                    const SizedBox(height: 10),
                    if (_vehicle == null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.directions_car_outlined, size: 40, color: subTextColor),
                            const SizedBox(height: 10),
                            Text(
                              appState.tr('fleet_no_vehicle_assigned'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.local_shipping_rounded, color: primary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _vehicle!.displayName,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                                  ),
                                  if (_vehicle!.year != null)
                                    Text('${_vehicle!.year}', style: TextStyle(fontSize: 12.5, color: subTextColor)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
