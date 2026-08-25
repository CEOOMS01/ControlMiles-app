// Olympus Mont Systems LLC - ControlMiles
// lib/screens/vehicle_screen.dart
//
// Pantalla dedicada a gestión de vehículo (antes vivía dentro de
// ProfileScreen) + módulo nuevo de mantenimiento (cambio de aceite, etc.).
// Dos pestañas: "Mi Vehículo" (CRUD movido de Profile, sin cambios de
// comportamiento) y "Mantenimiento" (nuevo).
//
// NOTA (limitación real, no oculta): vehicles.odometer es un valor que el
// usuario ingresa una vez al agregar el vehículo — no se actualiza solo con
// las millas que la app trackea por viaje (son sistemas separados, y no hay
// "editar vehículo" por decisión explícita del usuario: para corregirlo hay
// que archivar y agregar uno nuevo). Por eso "Mantenimiento" NO calcula un
// badge automático de "vencido" comparando contra el odómetro — sería
// engañoso con un dato que puede estar desactualizado hace meses. Solo
// muestra el próximo umbral guardado (millaje y/o fecha) como referencia.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/vehicle_makes.dart';
import '../logic/app_state.dart';
import '../models/maintenance_record.dart';
import '../models/vehicle.dart';
import '../services/maintenance_service.dart';
import '../services/vehicle_service.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  final VehicleService _vehicleService = VehicleService();
  final MaintenanceService _maintenanceService = MaintenanceService();

  late final TabController _tabController;

  // ── Vehículos ──
  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  bool _addingVehicle = false;

  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _mileageController = TextEditingController();
  final TextEditingController _customMakeController = TextEditingController();
  String? _selectedMake;
  bool _setAsActiveOnAdd = true;

  // ── Mantenimiento ──
  Vehicle? _selectedVehicleForMaintenance;
  List<MaintenanceRecord> _maintenanceRecords = [];
  bool _maintenanceLoading = false;
  bool _addingRecord = false;

  String _recordType = MaintenanceType.all.first.id;
  DateTime _recordDate = DateTime.now();
  final TextEditingController _recordOdometerController = TextEditingController();
  final TextEditingController _recordCostController = TextEditingController();
  final TextEditingController _recordNotesController = TextEditingController();
  final TextEditingController _recordNextDueOdometerController = TextEditingController();
  DateTime? _recordNextDueDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadVehicles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _yearController.dispose();
    _mileageController.dispose();
    _customMakeController.dispose();
    _recordOdometerController.dispose();
    _recordCostController.dispose();
    _recordNotesController.dispose();
    _recordNextDueOdometerController.dispose();
    super.dispose();
  }

  String? get _userId => _supabase.auth.currentUser?.id;

  // ════════════════════════════════════════════════════════════
  // VEHÍCULOS (movido de ProfileScreen, mismo comportamiento)
  // ════════════════════════════════════════════════════════════
  Future<void> _loadVehicles() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      final data = await _vehicleService.listVehicles(userId);
      if (!mounted) return;
      setState(() => _vehicles = data);

      // Mantiene la selección de mantenimiento apuntando a un vehículo
      // válido: prioriza el activo, si no existe usa el primero, si no hay
      // ninguno la deja en null (empty state).
      final stillValid = _selectedVehicleForMaintenance != null &&
          data.any((v) => v.id == _selectedVehicleForMaintenance!.id);
      if (!stillValid) {
        Vehicle? next;
        if (data.isNotEmpty) {
          next = data.firstWhere((v) => v.isActive, orElse: () => data.first);
        }
        setState(() => _selectedVehicleForMaintenance = next);
      }
      await _loadMaintenanceRecords();
    } catch (e) {
      debugPrint('[VehicleScreen] Error loading vehicles: $e');
    }
  }

  // BUG FIX (pedido explícito, nueva regla multi-auto): la DB ahora
  // bloquea cualquier cambio de vehículo activo mientras hay un viaje sin
  // cerrar (trigger tr_vehicles_block_switch_during_session). Esto
  // detecta ese caso específico por el texto de la excepción y muestra
  // el mensaje limpio i18n en vez del PostgrestException crudo -- mismo
  // patrón que login_screen.dart usa para credenciales inválidas.
  String _friendlyVehicleError(Object e, AppState appState) {
    final raw = e.toString();
    if (raw.contains('cambiar de vehículo activo mientras tienes un viaje en curso')) {
      return appState.tr('vehicle_switch_blocked_active_session') ??
          'You can\'t change your active vehicle while a trip is in progress.';
    }
    return raw.replaceFirst('Exception: ', '');
  }

  Future<void> _setActiveVehicle(String vehicleId, AppState appState) async {
    final userId = _userId;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      await _vehicleService.setActiveVehicle(userId, vehicleId);
      await _loadVehicles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyVehicleError(e, appState)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteVehicle(String vehicleId, AppState appState) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appState.tr('delete_vehicle')),
        content: Text(appState.tr('delete_vehicle_confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(appState.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(appState.tr('delete')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final userId = _userId;
      if (userId == null) return;
      await _vehicleService.deleteVehicle(userId, vehicleId);
      await _loadVehicles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appState.tr('vehicle_deleted_success')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyVehicleError(e, appState)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addVehicle(AppState appState) async {
    final userId = _userId;
    if (userId == null) return;

    final resolvedMake = _selectedMake == kOtherVehicleMake
        ? _customMakeController.text.trim()
        : (_selectedMake ?? '');

    if (resolvedMake.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.tr('field_required')), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _vehicleService.addVehicle(
        userId: userId,
        make: resolvedMake,
        model: _modelController.text.trim(),
        color: _colorController.text.trim(),
        year: int.tryParse(_yearController.text.trim()),
        odometer: double.tryParse(_mileageController.text.trim()),
        // Primer vehículo del usuario: se marca activo automáticamente.
        // Si ya tiene otros, respeta el checkbox del formulario.
        setAsActive: _vehicles.isEmpty ? true : _setAsActiveOnAdd,
      );

      _selectedMake = null;
      _customMakeController.clear();
      _modelController.clear();
      _colorController.clear();
      _yearController.clear();
      _mileageController.clear();
      setState(() {
        _addingVehicle = false;
        _setAsActiveOnAdd = true;
      });

      await _loadVehicles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appState.tr('vehicle_added_success')), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyVehicleError(e, appState)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════════
  // MANTENIMIENTO (nuevo)
  // ════════════════════════════════════════════════════════════
  Future<void> _loadMaintenanceRecords() async {
    final vehicle = _selectedVehicleForMaintenance;
    if (vehicle == null) {
      setState(() => _maintenanceRecords = []);
      return;
    }

    setState(() => _maintenanceLoading = true);
    try {
      final records = await _maintenanceService.listRecords(vehicle.id);
      if (!mounted) return;
      setState(() => _maintenanceRecords = records);
    } catch (e) {
      debugPrint('[VehicleScreen] Error loading maintenance records: $e');
    } finally {
      if (mounted) setState(() => _maintenanceLoading = false);
    }
  }

  Future<void> _addMaintenanceRecord(AppState appState) async {
    final userId = _userId;
    final vehicle = _selectedVehicleForMaintenance;
    if (userId == null || vehicle == null) return;

    setState(() => _isLoading = true);
    try {
      await _maintenanceService.addRecord(
        userId: userId,
        vehicleId: vehicle.id,
        type: _recordType,
        performedAt: _recordDate,
        odometerAtService: double.tryParse(_recordOdometerController.text.trim()),
        nextDueOdometer: double.tryParse(_recordNextDueOdometerController.text.trim()),
        nextDueDate: _recordNextDueDate,
        cost: double.tryParse(_recordCostController.text.trim()),
        notes: _recordNotesController.text,
      );

      _recordOdometerController.clear();
      _recordCostController.clear();
      _recordNotesController.clear();
      _recordNextDueOdometerController.clear();
      setState(() {
        _addingRecord = false;
        _recordType = MaintenanceType.all.first.id;
        _recordDate = DateTime.now();
        _recordNextDueDate = null;
      });

      await _loadMaintenanceRecords();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appState.tr('maintenance_record_added_success')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteMaintenanceRecord(String recordId, AppState appState) async {
    setState(() => _isLoading = true);
    try {
      await _maintenanceService.deleteRecord(recordId);
      await _loadMaintenanceRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appState.tr('maintenance_record_deleted_success')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${appState.tr('error')}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(appState.tr('vehicle').toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(icon: const Icon(Icons.directions_car_rounded), text: appState.tr('my_vehicle')),
            Tab(icon: const Icon(Icons.build_rounded), text: appState.tr('maintenance')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVehicleTab(appState, isDark),
          _buildMaintenanceTab(appState, isDark),
        ],
      ),
    );
  }

  // ── Tab 1: Mi Vehículo ──────────────────────────────────────
  Widget _buildVehicleTab(AppState appState, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: _addingVehicle
          ? _buildVehicleForm(appState, isDark)
          : Column(
              children: [
                if (_vehicles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(appState.tr('no_vehicle_registered'),
                        style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                  ),
                ..._vehicles.map((v) => _buildVehicleCard(v, appState, isDark)),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextButton.icon(
                    onPressed: () => setState(() => _addingVehicle = true),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: Text(appState.tr('add_vehicle')),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVehicleCard(Vehicle v, AppState appState, bool isDark) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      // BUG FIX (pedido explícito, cuadros invisibles en modo día): la
      // tarjeta inactiva no tenía borde -- blanco sobre el fondo #F8FAFC
      // del scaffold, contraste casi nulo. Ahora usa el mismo token de
      // borde que el resto de la app.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: v.isActive
            ? const BorderSide(color: Color(0xFF22C55E), width: 1.5)
            : BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        leading: const Icon(Icons.directions_car_filled_rounded, color: Color(0xFF475569)),
        title: Row(
          children: [
            Flexible(child: Text(v.displayName, style: const TextStyle(fontWeight: FontWeight.bold))),
            if (v.isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('ACTIVO',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF22C55E))),
              ),
            ],
          ],
        ),
        subtitle: Text("${v.year ?? ''} • ${v.color ?? ''}"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!v.isActive)
              IconButton(
                icon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF475569)),
                tooltip: 'Marcar como activo',
                onPressed: _isLoading ? null : () => _setActiveVehicle(v.id, appState),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: _isLoading ? null : () => _deleteVehicle(v.id, appState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleForm(AppState appState, bool isDark) {
    final isFirstVehicle = _vehicles.isEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedMake,
                  decoration: InputDecoration(labelText: appState.tr('make')),
                  hint: const Text('Ej: Toyota, Nissan'),
                  isExpanded: true,
                  items: kVehicleMakes
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedMake = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _modelController, decoration: InputDecoration(labelText: appState.tr('model')))),
            ],
          ),
          if (_selectedMake == kOtherVehicleMake) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customMakeController,
              decoration: const InputDecoration(labelText: 'Especifica la marca'),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _yearController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: appState.tr('year')))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _colorController, decoration: InputDecoration(labelText: appState.tr('color')))),
            ],
          ),
          TextField(controller: _mileageController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: appState.tr('odometer'))),
          if (!isFirstVehicle)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _setAsActiveOnAdd,
              onChanged: (v) => setState(() => _setAsActiveOnAdd = v ?? true),
              title: const Text('Usar como vehículo activo', style: TextStyle(fontSize: 13)),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => setState(() => _addingVehicle = false), child: Text(appState.tr('cancel'))),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isLoading ? null : () => _addVehicle(appState),
                child: Text(appState.tr('save')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Mantenimiento ────────────────────────────────────
  Widget _buildMaintenanceTab(AppState appState, bool isDark) {
    if (_vehicles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            appState.tr('no_vehicle_registered'),
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          if (_vehicles.length > 1) _buildVehiclePicker(appState, isDark),
          if (_addingRecord)
            _buildMaintenanceForm(appState, isDark)
          else ...[
            if (_maintenanceLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: CircularProgressIndicator(),
              )
            else if (_maintenanceRecords.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Text(appState.tr('no_maintenance_records'),
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
              )
            else
              ..._maintenanceRecords.map((r) => _buildMaintenanceRecordCard(r, appState, isDark)),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextButton.icon(
                onPressed: _selectedVehicleForMaintenance == null
                    ? null
                    : () => setState(() => _addingRecord = true),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: Text(appState.tr('add_maintenance_record')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVehiclePicker(AppState appState, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: DropdownButtonFormField<String>(
        value: _selectedVehicleForMaintenance?.id,
        decoration: InputDecoration(
          labelText: appState.tr('select_vehicle'),
          border: const OutlineInputBorder(),
        ),
        items: _vehicles
            .map((v) => DropdownMenuItem(value: v.id, child: Text(v.displayName)))
            .toList(),
        onChanged: (id) {
          final vehicle = _vehicles.firstWhere((v) => v.id == id);
          setState(() => _selectedVehicleForMaintenance = vehicle);
          _loadMaintenanceRecords();
        },
      ),
    );
  }

  Widget _buildMaintenanceRecordCard(MaintenanceRecord r, AppState appState, bool isDark) {
    final meta = r.typeMeta;
    final dateFmt = DateFormat('MM/dd/yyyy');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF475569).withOpacity(0.12),
          child: Icon(meta.icon, color: const Color(0xFF475569), size: 20),
        ),
        title: Text(appState.tr(meta.labelKey), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateFmt.format(r.performedAt)),
            if (r.odometerAtService != null)
              Text('${appState.tr('odometer')}: ${r.odometerAtService!.toStringAsFixed(0)}'),
            if (r.cost != null) Text('${appState.tr('cost_optional')}: \$${r.cost!.toStringAsFixed(2)}'),
            if (r.nextDueOdometer != null)
              Text('${appState.tr('next_due_odometer_optional')}: ${r.nextDueOdometer!.toStringAsFixed(0)}'),
            if (r.nextDueDate != null)
              Text('${appState.tr('next_due_date_optional')}: ${dateFmt.format(r.nextDueDate!)}'),
            if (r.notes != null && r.notes!.isNotEmpty) Text(r.notes!),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
          onPressed: _isLoading ? null : () => _deleteMaintenanceRecord(r.id, appState),
        ),
      ),
    );
  }

  Widget _buildMaintenanceForm(AppState appState, bool isDark) {
    final dateFmt = DateFormat('MM/dd/yyyy');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _recordType,
            decoration: InputDecoration(labelText: appState.tr('maintenance_type')),
            isExpanded: true,
            items: MaintenanceType.all
                .map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Row(
                        children: [
                          Icon(t.icon, size: 18, color: const Color(0xFF475569)),
                          const SizedBox(width: 8),
                          Text(appState.tr(t.labelKey)),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _recordType = v ?? _recordType),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(appState.tr('service_date')),
            subtitle: Text(dateFmt.format(_recordDate)),
            trailing: const Icon(Icons.calendar_today_rounded, size: 18),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _recordDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _recordDate = picked);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _recordOdometerController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: appState.tr('odometer_at_service')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _recordCostController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: appState.tr('cost_optional')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _recordNextDueOdometerController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: appState.tr('next_due_odometer_optional')),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(appState.tr('next_due_date_optional')),
            subtitle: Text(_recordNextDueDate != null ? dateFmt.format(_recordNextDueDate!) : '—'),
            trailing: const Icon(Icons.calendar_today_rounded, size: 18),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _recordNextDueDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(DateTime.now().year + 5),
              );
              if (picked != null) setState(() => _recordNextDueDate = picked);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _recordNotesController,
            maxLines: 2,
            decoration: InputDecoration(labelText: appState.tr('notes_optional')),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _addingRecord = false),
                child: Text(appState.tr('cancel')),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isLoading ? null : () => _addMaintenanceRecord(appState),
                child: Text(appState.tr('save')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
