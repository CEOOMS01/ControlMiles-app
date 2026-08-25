// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/vehicle_selector.dart - VERSIÓN ALINEADA CON DB v3

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';

class VehicleSelector extends StatefulWidget {
  final Function(String?, Map<String, dynamic>?) onVehicleSelected;

  const VehicleSelector({
    super.key,
    required this.onVehicleSelected,
  });

  @override
  State<VehicleSelector> createState() => _VehicleSelectorState();
}

class _VehicleSelectorState extends State<VehicleSelector> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _vehicles = [];
  bool _loading = true;
  String? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final data = await _supabase
          .from('vehicles')
          .select()
          .or('owner_user_id.eq.${user.id},organization_id.is.not.null') // soporta fleet
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _vehicles = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("[VehicleSelector ERROR] $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectVehicle(Map<String, dynamic>? vehicle) {
    setState(() => _selectedVehicleId = vehicle?["id"] as String?);

    widget.onVehicleSelected(
      vehicle?["id"] as String?,
      vehicle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appState.tr('vehicle') ?? 'Vehicle',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),

        if (_vehicles.isEmpty)
          Text(
            appState.tr('no_vehicle_registered') ?? 'No vehicle registered yet',
            style: const TextStyle(color: Colors.grey),
          )
        else
          ..._vehicles.map((vehicle) {
            final id = vehicle["id"] as String?;
            final make = vehicle["make"] ?? "";
            final model = vehicle["model"] ?? "";
            final year = vehicle["year"]?.toString() ?? "";
            final color = vehicle["color"] ?? "";

            final label = "$year $make $model".trim();

            return Card(
              elevation: _selectedVehicleId == id ? 4 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _selectedVehicleId == id ? Colors.blue : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.directions_car,
                  color: _selectedVehicleId == id ? Colors.blue : Colors.grey,
                ),
                title: Text(
                  label.isEmpty ? "Vehicle" : label,
                  style: TextStyle(
                    fontWeight: _selectedVehicleId == id ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text("${appState.tr('vehicle_color') ?? 'Color'}: $color"),
                trailing: _selectedVehicleId == id
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () => _selectVehicle(vehicle),
              ),
            );
          }),

        if (_selectedVehicleId != null)
          TextButton.icon(
            onPressed: () => _selectVehicle(null),
            icon: const Icon(Icons.close, size: 16),
            label: Text(appState.tr('cancel') ?? 'Cancel'),
          ),
      ],
    );
  }
}