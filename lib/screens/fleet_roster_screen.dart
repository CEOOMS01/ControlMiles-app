// Olympus Mont Systems LLC - ControlMiles
// lib/screens/fleet_roster_screen.dart
//
// Fleet Phase 2: admin/owner-only. Invite drivers by email (existing
// ControlMiles accounts only -- see OrganizationService.inviteMemberByEmail)
// and assign fleet vehicles to active drivers.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../models/organization.dart';
import '../models/vehicle.dart';
import '../services/organization_service.dart';

class FleetRosterScreen extends StatefulWidget {
  const FleetRosterScreen({super.key});

  @override
  State<FleetRosterScreen> createState() => _FleetRosterScreenState();
}

class _FleetRosterScreenState extends State<FleetRosterScreen> {
  final _organizationService = OrganizationService();
  bool _loading = true;
  List<OrganizationMember> _members = [];
  List<Vehicle> _vehicles = [];

  String? get _orgId => context.read<AppState>().defaultOrgId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final orgId = _orgId;
    if (orgId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _organizationService.listMembers(orgId),
        _organizationService.listOrgVehicles(orgId),
      ]);
      if (mounted) {
        setState(() {
          _members = results[0] as List<OrganizationMember>;
          _vehicles = results[1] as List<Vehicle>;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[FleetRoster] Load failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showInviteDialog(AppState appState) async {
    final controller = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(appState.tr('fleet_invite_dialog_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(hintText: appState.tr('email')),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(appState.tr('cancel'))),
            TextButton(
              onPressed: () async {
                final email = controller.text.trim();
                if (email.isEmpty) return;
                try {
                  final orgId = _orgId;
                  if (orgId == null) return;
                  await _organizationService.inviteMemberByEmail(orgId, email);
                  if (context.mounted) Navigator.pop(ctx);
                  await _load();
                } catch (e) {
                  setDialogState(() => error = e.toString());
                }
              },
              child: Text(appState.tr('fleet_invite_send')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssignVehicleDialog(AppState appState, OrganizationMember driver) async {
    if (_vehicles.isEmpty) return;
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(appState.tr('fleet_assign_vehicle_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final vehicle in _vehicles)
                ListTile(
                  title: Text(vehicle.displayName),
                  subtitle: vehicle.assignedDriverId != null
                      ? Text(appState.tr('fleet_vehicle_already_assigned'), style: const TextStyle(fontSize: 11))
                      : null,
                  onTap: () async {
                    try {
                      await _organizationService.assignVehicle(
                        vehicleId: vehicle.id,
                        driverUserId: driver.userId,
                      );
                      if (context.mounted) Navigator.pop(ctx);
                      await _load();
                    } catch (e) {
                      setDialogState(() => error = e.toString());
                    }
                  },
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(appState.tr('cancel'))),
          ],
        ),
      ),
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
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(appState.tr('driver_management'), style: TextStyle(color: textColor, fontWeight: FontWeight.w900)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteDialog(appState),
        backgroundColor: primary,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: Text(appState.tr('fleet_invite_driver'), style: const TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _members.isEmpty
                ? Center(
                    child: Text(appState.tr('no_data'), style: TextStyle(color: subTextColor)),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final assignedVehicle = _vehicles
                            .where((v) => v.assignedDriverId == member.userId)
                            .cast<Vehicle?>()
                            .firstWhere((v) => true, orElse: () => null);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          member.memberRole.toUpperCase(),
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: primary),
                                        ),
                                        if (!member.isActive) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(100),
                                            ),
                                            child: Text(
                                              appState.tr('fleet_invite_pending'),
                                              style: const TextStyle(fontSize: 9.5, color: Colors.orange, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      assignedVehicle?.displayName ?? appState.tr('fleet_no_vehicle_assigned'),
                                      style: TextStyle(fontSize: 12.5, color: subTextColor),
                                    ),
                                  ],
                                ),
                              ),
                              if (member.isActive && member.memberRole == 'driver')
                                IconButton(
                                  icon: Icon(Icons.local_shipping_outlined, color: subTextColor),
                                  onPressed: () => _showAssignVehicleDialog(appState, member),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
