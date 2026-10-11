// Olympus Mont Systems LLC - ControlMiles
// lib/screens/fleet_dashboard_screen.dart
//
// The fleet owner/admin's home in the app -- deliberately minimal
// (explicit user request, 2026-09-30: "la app móvil del owner no debe
// estar tan cargada, solo lo mínimo; todo lo pesado se gestiona en la
// web"). Same split as Samsara's / Motive's manager apps: the phone is for
// a quick look (who's driving right now, alerts, the live map); drivers,
// vehicles, IFTA, branches, schedules, fuel and settings are managed on
// controlmiles.com. The app's old IFTA and driver-management screens are
// no longer reachable from here.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/app_state.dart';
import '../models/organization.dart';
import '../routes/app_routes.dart';
import '../services/organization_service.dart';

const _webDashboardUrl = 'https://controlmiles.com/admin';

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
  int _onTrip = 0;
  int _vehicles = 0;
  int _openAlerts = 0;
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
      final client = Supabase.instance.client;
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final results = await Future.wait<dynamic>([
        _organizationService.getOrganization(orgId),
        client
            .from('vehicles')
            .select('id, active_session_id')
            .eq('organization_id', orgId)
            .eq('is_archived', false),
        client
            .from('fuel_anomalies')
            .select('id')
            .eq('organization_id', orgId)
            .eq('status', 'open')
            .count(CountOption.exact),
        _organizationService.getTotalMilesInRange(orgId, start: monthStart, end: now),
      ]);

      if (!mounted) return;
      final vehicles = (results[1] as List);
      setState(() {
        _organization = results[0] as Organization?;
        _vehicles = vehicles.length;
        _onTrip = vehicles.where((v) => (v as Map)['active_session_id'] != null).length;
        _openAlerts = (results[2] as PostgrestResponse).count;
        _monthMiles = results[3] as double;
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

  Future<void> _openWeb() async {
    await launchUrl(Uri.parse(_webDashboardUrl), mode: LaunchMode.externalApplication);
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
    final primary = Theme.of(context).colorScheme.primary;

    Widget stat(IconData icon, String label, String value, {Color? accent}) => Expanded(
          child: _StatCard(
            icon: icon,
            label: label,
            value: value,
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
            subTextColor: subTextColor,
            accent: accent ?? primary,
          ),
        );

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
            icon: Icon(Icons.settings_outlined, color: subTextColor),
            tooltip: appState.tr('settings'),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
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
                        const SizedBox(height: 4),
                        Text(
                          _organization?.name ?? '',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            stat(Icons.navigation_rounded, appState.tr('owner_stat_on_trip'), '$_onTrip / $_vehicles'),
                            const SizedBox(width: 12),
                            stat(
                              Icons.local_gas_station_rounded,
                              appState.tr('owner_stat_fuel_alerts'),
                              '$_openAlerts',
                              accent: _openAlerts > 0 ? const Color(0xFFDC2626) : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            stat(Icons.speed_rounded, appState.tr('fleet_stat_month_miles'), _monthMiles.toStringAsFixed(1)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, AppRoutes.fleetLiveMap),
                            icon: const Icon(Icons.map_rounded, size: 18),
                            label: Text(
                              appState.tr('fleet_live_map_title').toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.desktop_windows_rounded, color: primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      appState.tr('owner_manage_on_web_title'),
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                appState.tr('owner_manage_on_web_body'),
                                style: TextStyle(fontSize: 12.5, height: 1.4, color: subTextColor),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _openWeb,
                                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                  label: Text(
                                    appState.tr('owner_manage_on_web_button').toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                  ),
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
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
