// Olympus Mont Systems LLC - ControlMiles
// lib/screens/fleet_state_mileage_screen.dart
//
// Fleet Phase 6, piece 1: miles-per-state report. Defaults to the current
// IFTA quarter since that's the reporting cadence this exists for, but any
// custom range works too. NOT a fileable IFTA return by itself -- see
// ifta_service.dart's own comment on why (no fuel-gallons-per-jurisdiction
// data exists in this app).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../models/vehicle.dart';
import '../services/ifta_service.dart';
import '../services/organization_service.dart';

class FleetStateMileageScreen extends StatefulWidget {
  const FleetStateMileageScreen({super.key});

  @override
  State<FleetStateMileageScreen> createState() => _FleetStateMileageScreenState();
}

class _FleetStateMileageScreenState extends State<FleetStateMileageScreen> {
  final _iftaService = IftaService();
  final _organizationService = OrganizationService();

  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  List<Vehicle> _vehicles = [];
  String? _selectedVehicleId;
  List<StateMileage> _results = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final quarter = ((now.month - 1) ~/ 3);
    _rangeStart = DateTime(now.year, quarter * 3 + 1, 1);
    _rangeEnd = DateTime(now.year, quarter * 3 + 3 + 1, 0);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final orgId = context.read<AppState>().defaultOrgId;
    if (orgId == null) {
      setState(() {
        _isLoading = false;
        _error = 'no_org';
      });
      return;
    }

    try {
      final vehicles = await _organizationService.listOrgVehicles(orgId);
      final results = await _iftaService.computeStateMileage(
        organizationId: orgId,
        start: _rangeStart,
        end: _rangeEnd,
        vehicleId: _selectedVehicleId,
      );
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
    );
    if (picked == null) return;
    setState(() {
      _rangeStart = picked.start;
      _rangeEnd = picked.end;
    });
    _load();
  }

  double get _totalMiles => _results.fold(0.0, (sum, r) => sum + r.miles);

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
        title: Text(appState.tr('ifta_state_mileage_title')),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_rounded),
            tooltip: appState.tr('ifta_pick_range'),
            onPressed: _pickRange,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${_rangeStart.toLocal().toString().split(' ').first} — ${_rangeEnd.toLocal().toString().split(' ').first}',
                style: TextStyle(fontSize: 13, color: subTextColor, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (_vehicles.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ChoiceChip(
                        label: Text(appState.tr('ifta_all_vehicles')),
                        selected: _selectedVehicleId == null,
                        onSelected: (_) {
                          setState(() => _selectedVehicleId = null);
                          _load();
                        },
                      ),
                      const SizedBox(width: 8),
                      for (final v in _vehicles) ...[
                        ChoiceChip(
                          label: Text(v.displayName.isEmpty ? v.id.substring(0, 6) : v.displayName),
                          selected: _selectedVehicleId == v.id,
                          onSelected: (_) {
                            setState(() => _selectedVehicleId = v.id);
                            _load();
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(appState.tr('ifta_total_miles'),
                        style: TextStyle(fontSize: 13, color: subTextColor, fontWeight: FontWeight.w600)),
                    Text('${_totalMiles.toStringAsFixed(1)} mi',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error == 'no_org')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(appState.tr('ifta_no_org'), textAlign: TextAlign.center, style: TextStyle(color: subTextColor)),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text('${appState.tr('error')}: $_error', style: const TextStyle(color: Colors.red)),
                )
              else if (_results.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(appState.tr('ifta_no_mileage'), textAlign: TextAlign.center, style: TextStyle(color: subTextColor)),
                )
              else
                ..._results.map((r) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(r.stateCode,
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: primary)),
                              ),
                              const SizedBox(width: 12),
                              Text(r.stateName, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                            ],
                          ),
                          Text('${r.miles.toStringAsFixed(1)} mi',
                              style: TextStyle(fontWeight: FontWeight.w900, color: textColor)),
                        ],
                      ),
                    )),
              const SizedBox(height: 20),
              Text(
                appState.tr('ifta_disclaimer'),
                style: TextStyle(fontSize: 11.5, color: subTextColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
