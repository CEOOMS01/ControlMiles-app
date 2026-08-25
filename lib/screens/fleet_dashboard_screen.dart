// Olympus Mont Systems LLC - ControlMiles
// lib/screens/fleet_dashboard_screen.dart
//
// Fleet Phase 1 scope, exactly as scoped in the roadmap: a read-only
// aggregate view of data the app already collects. No driver management,
// no vehicle assignment, no live map yet -- those are Phase 2+.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../models/organization.dart';
import '../routes/app_routes.dart';
import '../services/organization_service.dart';

class FleetDashboardScreen extends StatefulWidget {
  const FleetDashboardScreen({super.key});

  @override
  State<FleetDashboardScreen> createState() => _FleetDashboardScreenState();
}

class _FleetDashboardScreenState extends State<FleetDashboardScreen> {
  final _organizationService = OrganizationService();
  bool _loading = true;
  String? _error;
  Organization? _organization;
  int _memberCount = 0;
  double _monthMiles = 0.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final orgId = appState.defaultOrgId;

    if (orgId == null) {
      setState(() {
        _loading = false;
        _error = 'no_org';
      });
      return;
    }

    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final results = await Future.wait([
        _organizationService.getOrganization(orgId),
        _organizationService.listMembers(orgId),
        _organizationService.getTotalMilesInRange(orgId, start: monthStart, end: now),
      ]);

      if (!mounted) return;
      setState(() {
        _organization = results[0] as Organization?;
        _memberCount = (results[1] as List).length;
        _monthMiles = results[2] as double;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[FleetDashboard] Load failed: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
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
        title: Text(
          appState.tr('fleet_dashboard'),
          style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.map_rounded, color: subTextColor),
            tooltip: appState.tr('fleet_live_map_title'),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.fleetLiveMap),
          ),
          IconButton(
            icon: Icon(Icons.groups_rounded, color: subTextColor),
            tooltip: appState.tr('driver_management'),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.fleetRoster),
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: subTextColor),
            onPressed: () => _logout(appState),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error == 'no_org'
                ? _EmptyOrgState(textColor: textColor, subTextColor: subTextColor)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          _organization?.name ?? '',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
                        ),
                        const SizedBox(height: 6),
                        _ComplianceBadge(
                          isRegulated: _organization?.isRegulatedCmv ?? false,
                          primary: primary,
                          subTextColor: subTextColor,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.groups_rounded,
                                label: appState.tr('fleet_stat_members'),
                                value: '$_memberCount',
                                cardColor: cardColor,
                                borderColor: borderColor,
                                textColor: textColor,
                                subTextColor: subTextColor,
                                accent: primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.speed_rounded,
                                label: appState.tr('fleet_stat_month_miles'),
                                value: _monthMiles.toStringAsFixed(1),
                                cardColor: cardColor,
                                borderColor: borderColor,
                                textColor: textColor,
                                subTextColor: subTextColor,
                                accent: primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _ComplianceBadge extends StatelessWidget {
  final bool isRegulated;
  final Color primary;
  final Color subTextColor;

  const _ComplianceBadge({required this.isRegulated, required this.primary, required this.subTextColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isRegulated ? Colors.orange : primary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        isRegulated ? 'REGULATED CMV' : 'LIGHT DUTY',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: isRegulated ? Colors.orange : primary,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color subTextColor;
  final Color accent;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.subTextColor,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11.5, color: subTextColor)),
        ],
      ),
    );
  }
}

class _EmptyOrgState extends StatelessWidget {
  final Color textColor;
  final Color subTextColor;

  const _EmptyOrgState({required this.textColor, required this.subTextColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping_outlined, size: 48, color: subTextColor),
            const SizedBox(height: 12),
            Text(
              'No organization found for this account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
