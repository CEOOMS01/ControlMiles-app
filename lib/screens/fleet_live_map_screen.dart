// Olympus Mont Systems LLC - ControlMiles
// lib/screens/fleet_live_map_screen.dart
//
// Fleet Phase 5: admin-only live map. Shows each org vehicle's last known
// position (written by update_vehicle_location, throttled to ~15s per
// active fleet trip -- see tracking_controller.dart's _smartSync) plus
// geofence circles for whichever vehicle is selected, and lets the admin
// draw a new geofence by tapping the map.
//
// BUG FIX / roadmap gap closed (pedido explícito, hardest-to-easiest pass):
// originally refreshed on a plain 20s polling timer -- the roadmap this
// screen was built against explicitly called for "a realtime channel, not
// just polling". Replaced with a real Supabase Realtime subscription
// (postgres_changes on vehicles UPDATE + vehicle_geofence_alerts INSERT,
// both filtered to this org) -- position updates now arrive over the
// websocket the moment update_vehicle_location writes them, not up to 20s
// later. One REST fetch still happens on open (_load(initial: true)) to
// populate the initial state; Realtime only pushes CHANGES going forward,
// it doesn't replace an initial snapshot read.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/app_state.dart';
import '../models/vehicle.dart';
import '../models/vehicle_geofence.dart';
import '../services/geofence_service.dart';
import '../services/organization_service.dart';

class FleetLiveMapScreen extends StatefulWidget {
  const FleetLiveMapScreen({super.key});

  @override
  State<FleetLiveMapScreen> createState() => _FleetLiveMapScreenState();
}

class _FleetLiveMapScreenState extends State<FleetLiveMapScreen> {
  final _organizationService = OrganizationService();
  final _geofenceService = GeofenceService();
  final _mapController = MapController();

  List<Vehicle> _vehicles = [];
  List<VehicleGeofence> _selectedVehicleGeofences = [];
  List<GeofenceAlert> _recentAlerts = [];
  Vehicle? _selectedVehicle;
  bool _isLoading = true;
  bool _isPlacingGeofence = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load(initial: true).then((_) {
      if (!mounted) return;
      final orgId = context.read<AppState>().defaultOrgId;
      if (orgId != null) _subscribeRealtime(orgId);
    });
  }

  @override
  void dispose() {
    if (_channel != null) Supabase.instance.client.removeChannel(_channel!);
    super.dispose();
  }

  void _subscribeRealtime(String orgId) {
    _channel = Supabase.instance.client
        .channel('fleet-live-map-$orgId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'vehicles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'organization_id',
            value: orgId,
          ),
          callback: _onVehicleRealtimeUpdate,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'vehicle_geofence_alerts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'organization_id',
            value: orgId,
          ),
          callback: _onGeofenceAlertRealtimeInsert,
        )
        .subscribe();
  }

  void _onVehicleRealtimeUpdate(PostgresChangePayload payload) {
    if (!mounted) return;
    final updated = Vehicle.fromMap(payload.newRecord);

    setState(() {
      final index = _vehicles.indexWhere((v) => v.id == updated.id);
      if (index != -1) _vehicles[index] = updated;
      if (_selectedVehicle?.id == updated.id) _selectedVehicle = updated;
    });
  }

  void _onGeofenceAlertRealtimeInsert(PostgresChangePayload payload) {
    if (!mounted) return;
    final alert = GeofenceAlert.fromMap(payload.newRecord);
    setState(() => _recentAlerts = [alert, ..._recentAlerts].take(30).toList());
  }

  Future<void> _load({required bool initial}) async {
    final orgId = context.read<AppState>().defaultOrgId;
    if (orgId == null) return;

    try {
      final vehicles = await _organizationService.listOrgVehicles(orgId);
      final alerts = await _geofenceService.listRecentAlerts(orgId, limit: 30);
      if (!mounted) return;

      Vehicle? selected = _selectedVehicle;
      if (selected != null) {
        // Reemplaza con la fila fresca (misma id) para reflejar la última
        // posición -- no basta con dejar el objeto viejo seleccionado.
        selected = vehicles.where((v) => v.id == selected!.id).firstOrNull;
      }
      selected ??= vehicles.where((v) => v.hasLiveLocation).firstOrNull;

      List<VehicleGeofence> geofences = [];
      if (selected != null) {
        geofences = await _geofenceService.listForVehicle(selected.id);
      }

      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _recentAlerts = alerts;
        _selectedVehicle = selected;
        _selectedVehicleGeofences = geofences;
        _isLoading = false;
      });

      if (initial && selected != null && selected.hasLiveLocation) {
        _mapController.move(LatLng(selected.lastLatitude!, selected.lastLongitude!), 13);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectVehicle(Vehicle vehicle) async {
    setState(() => _selectedVehicle = vehicle);
    final geofences = await _geofenceService.listForVehicle(vehicle.id);
    if (!mounted) return;
    setState(() => _selectedVehicleGeofences = geofences);
    if (vehicle.hasLiveLocation) {
      _mapController.move(LatLng(vehicle.lastLatitude!, vehicle.lastLongitude!), 13);
    }
  }

  Future<void> _onMapTap(TapPosition tapPosition, LatLng point) async {
    if (!_isPlacingGeofence || _selectedVehicle == null) return;
    setState(() => _isPlacingGeofence = false);

    final appState = context.read<AppState>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _GeofenceFormDialog(appState: appState),
    );
    if (result == null) return;

    try {
      await _geofenceService.createGeofence(
        vehicleId: _selectedVehicle!.id,
        organizationId: _selectedVehicle!.organizationId!,
        name: result['name'] as String,
        centerLatitude: point.latitude,
        centerLongitude: point.longitude,
        radiusMeters: result['radius'] as double,
      );
      final geofences = await _geofenceService.listForVehicle(_selectedVehicle!.id);
      if (!mounted) return;
      setState(() => _selectedVehicleGeofences = geofences);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${appState.tr('error')}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAlerts(AppState appState) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _AlertsSheet(alerts: _recentAlerts, vehicles: _vehicles, appState: appState),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final primary = Theme.of(context).colorScheme.primary;

    final vehiclesWithLocation = _vehicles.where((v) => v.hasLiveLocation).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(appState.tr('fleet_live_map_title')),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () => _showAlerts(appState),
              ),
              if (_recentAlerts.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${_recentAlerts.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (vehiclesWithLocation.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(appState.tr('fleet_live_map_no_vehicles'),
                        style: TextStyle(color: textColor.withValues(alpha: 0.6))),
                  ),
                if (_vehicles.isNotEmpty)
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _vehicles.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final v = _vehicles[i];
                        final selected = v.id == _selectedVehicle?.id;
                        return ChoiceChip(
                          label: Text(v.displayName.isEmpty ? v.id.substring(0, 6) : v.displayName),
                          selected: selected,
                          onSelected: (_) => _selectVehicle(v),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: vehiclesWithLocation.isNotEmpty
                              ? LatLng(vehiclesWithLocation.first.lastLatitude!, vehiclesWithLocation.first.lastLongitude!)
                              : const LatLng(37.7749, -122.4194),
                          initialZoom: vehiclesWithLocation.isNotEmpty ? 13 : 4,
                          onTap: _onMapTap,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.olympusmont.controlmiles',
                          ),
                          CircleLayer(
                            circles: [
                              for (final g in _selectedVehicleGeofences)
                                if (g.isActive)
                                  CircleMarker(
                                    point: LatLng(g.centerLatitude, g.centerLongitude),
                                    radius: g.radiusMeters,
                                    useRadiusInMeter: true,
                                    color: primary.withValues(alpha: 0.15),
                                    borderStrokeWidth: 2,
                                    borderColor: primary,
                                  ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              for (final v in vehiclesWithLocation)
                                Marker(
                                  point: LatLng(v.lastLatitude!, v.lastLongitude!),
                                  width: 42,
                                  height: 42,
                                  child: GestureDetector(
                                    onTap: () => _selectVehicle(v),
                                    child: Icon(
                                      Icons.local_shipping_rounded,
                                      color: v.id == _selectedVehicle?.id ? Colors.red.shade700 : primary,
                                      size: 34,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (_isPlacingGeofence)
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              appState.tr('fleet_live_map_tap_to_place'),
                              style: const TextStyle(color: Colors.white, fontSize: 12.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _selectedVehicle == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => setState(() => _isPlacingGeofence = !_isPlacingGeofence),
              icon: Icon(_isPlacingGeofence ? Icons.close_rounded : Icons.add_location_alt_rounded),
              label: Text(_isPlacingGeofence
                  ? appState.tr('cancel')
                  : appState.tr('fleet_live_map_add_geofence')),
            ),
    );
  }
}

class _GeofenceFormDialog extends StatefulWidget {
  final AppState appState;
  const _GeofenceFormDialog({required this.appState});

  @override
  State<_GeofenceFormDialog> createState() => _GeofenceFormDialogState();
}

class _GeofenceFormDialogState extends State<_GeofenceFormDialog> {
  final _nameController = TextEditingController();
  final _radiusController = TextEditingController(text: '500');

  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.appState.tr('fleet_live_map_new_geofence')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: widget.appState.tr('fleet_live_map_geofence_name')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _radiusController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: widget.appState.tr('fleet_live_map_geofence_radius'),
              suffixText: 'm',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.appState.tr('cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final radius = double.tryParse(_radiusController.text.trim());
            if (name.isEmpty || radius == null || radius <= 0) return;
            Navigator.pop(context, {'name': name, 'radius': radius});
          },
          child: Text(widget.appState.tr('fleet_live_map_create')),
        ),
      ],
    );
  }
}

class _AlertsSheet extends StatelessWidget {
  final List<GeofenceAlert> alerts;
  final List<Vehicle> vehicles;
  final AppState appState;

  const _AlertsSheet({required this.alerts, required this.vehicles, required this.appState});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(appState.tr('fleet_live_map_alerts_title'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            if (alerts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(appState.tr('fleet_live_map_no_alerts')),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: alerts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final alert = alerts[i];
                    final vehicle = vehicles.where((v) => v.id == alert.vehicleId).firstOrNull;
                    return ListTile(
                      leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      title: Text(vehicle?.displayName ?? alert.vehicleId.substring(0, 6)),
                      subtitle: Text('${alert.distanceMeters.round()}m — ${alert.createdAt.toLocal()}'),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
