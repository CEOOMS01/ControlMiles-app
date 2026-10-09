// Olympus Mont Systems LLC - ControlMiles
// lib/screens/monitor_home_screen.dart
//
// Bus monitor home (2026-10-09; plan section 8). A monitor (member_role
// 'monitor', invited only from the web, School transportation fleets only)
// keeps the student list of the routes they're on today: no trips, no miles,
// no vehicle. When the driver starts a route, the monitor opens it and marks
// students; starting and finishing stay with the driver.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../widgets/school_routes_card.dart';
import 'driver_operations_screen.dart';
import 'driver_settings_sheet.dart';

/// The fleet member home: bus monitors get [MonitorHomeScreen], everyone
/// else the driver's [DriverOperationsScreen].
class FleetMemberHome extends StatelessWidget {
  const FleetMemberHome({super.key});

  @override
  Widget build(BuildContext context) {
    final isMonitor = context.select<AppState, bool>((s) => s.isMonitor);
    return isMonitor ? const MonitorHomeScreen() : const DriverOperationsScreen();
  }
}

class MonitorHomeScreen extends StatefulWidget {
  const MonitorHomeScreen({super.key});

  @override
  State<MonitorHomeScreen> createState() => _MonitorHomeScreenState();
}

class _MonitorHomeScreenState extends State<MonitorHomeScreen> {
  // Rebuilding the card reloads today's routes (a route the driver just
  // started shows up as "Open route").
  int _reload = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _reload++);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF6B6250);
    final orgId = appState.defaultOrgId;
    return Scaffold(
      appBar: AppBar(
        title: Text(appState.tr('monitor_home_title')),
        backgroundColor: isDark ? const Color(0xFF1C1812) : const Color(0xFF211C14),
        foregroundColor: Colors.white,
        // Website-style ink header with a rounded bottom (warm palette, 2026-10-09).
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(22))),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => showDriverSettingsSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => setState(() => _reload++),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (appState.firstName != null)
                Text(
                  appState.tr('monitor_hello').replaceFirst('{name}', appState.firstName!),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              const SizedBox(height: 6),
              Text(appState.tr('monitor_hint'), style: TextStyle(color: subTextColor, height: 1.4)),
              const SizedBox(height: 16),
              if (orgId != null)
                SchoolRoutesCard(
                  key: ValueKey(_reload),
                  organizationId: orgId,
                  tripIsActive: false,
                  monitorMode: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
