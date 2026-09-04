// Olympus Mont Systems LLC - ControlMiles
// lib/screens/vehicle_detail_screen.dart
//
// Perfil de vehículo de SOLO LECTURA (explicit user requirement: "que se
// pueda entrar en el perfil del auto registrado no para editar el auto si
// no para revisar que las millas suban conforme al registro"). No hay
// ningún campo editable acá — solo dos fuentes de verdad puestas una junto
// a la otra para que el usuario pueda verificar que van de la mano:
//   1. Millas calculadas por GPS (VehicleService.totalTrackedMiles, suma de
//      sessions.total_miles ya cerradas para este vehículo).
//   2. Evidencia real de odómetro por foto, semana a semana
//      (vehicle_odometer_checkpoints vía OdometerCaptureService.
//      listCheckpoints) -- la foto inicial del vehículo es, en la práctica,
//      el primer checkpoint que exista.
// Deliberadamente NO se reconcilian ambas cifras en una sola ("¿coinciden
// exactamente?") -- son evidencia de naturaleza distinta (GPS continuo vs.
// lectura puntual fotografiada) y won't match to the mile; se muestran
// lado a lado para que el usuario juzgue por sí mismo si van razonablemente
// alineadas.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../models/vehicle.dart';
import '../services/odometer_capture_service.dart';
import '../services/vehicle_service.dart';

class VehicleDetailScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  final VehicleService _vehicleService = VehicleService();
  final OdometerCaptureService _odometerService = OdometerCaptureService();

  bool _loading = true;
  double _trackedMiles = 0.0;
  List<Map<String, dynamic>> _checkpoints = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _vehicleService.totalTrackedMiles(widget.vehicle.id),
        _odometerService.listCheckpoints(widget.vehicle.id),
      ]);
      if (!mounted) return;
      setState(() {
        _trackedMiles = results[0] as double;
        _checkpoints = results[1] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      debugPrint('[VehicleDetailScreen] Error loading: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // BUG FIX (hardcoded-string audit): esta pantalla mostraba "mi" fijo sin
  // pasar por tr('mile_short')/tr('kilometer_short') ni respetar
  // appState.useMetricSystem -- mismo criterio ya usado en
  // history_screen.dart para las millas de un viaje. Los valores en DB
  // siempre están en millas (ver AppConfig), la conversión es solo de
  // presentación.
  String _formatMiles(double miles, AppState appState) {
    if (appState.useMetricSystem) {
      return '${(miles * 1.60934).toStringAsFixed(0)} ${appState.tr('kilometer_short')}';
    }
    return '${miles.toStringAsFixed(0)} ${appState.tr('mile_short')}';
  }

  void _openPhoto(String? url) {
    if (url == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final v = widget.vehicle;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(appState.tr('vehicle_profile_title').toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildVehicleCard(v, appState, isDark),
                  const SizedBox(height: 16),
                  _buildMilesCard(appState, isDark),
                  const SizedBox(height: 20),
                  Text(
                    appState.tr('odometer_checkpoints_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  if (_checkpoints.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        appState.tr('no_odometer_checkpoints'),
                        style: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                      ),
                    )
                  else
                    ..._checkpoints.map((c) => _buildCheckpointCard(c, appState, isDark)),
                ],
              ),
            ),
    );
  }

  Widget _buildVehicleCard(Vehicle v, AppState appState, bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_car_filled_rounded, color: Color(0xFF475569)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(v.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text("${v.year ?? ''} • ${v.color ?? ''}",
                style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[700])),
            if (v.vin != null && v.vin!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${appState.tr('vin_label')}: ${v.vin}', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(appState.tr('current_odometer'),
                    style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[700])),
                Text(
                  v.odometer != null ? _formatMiles(v.odometer!, appState) : '—',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilesCard(AppState appState, bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.timeline_rounded, color: Color(0xFF22C55E)),
        title: Text(appState.tr('tracked_miles_gps')),
        trailing: Text(
          _formatMiles(_trackedMiles, appState),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF22C55E)),
        ),
      ),
    );
  }

  Widget _buildCheckpointCard(Map<String, dynamic> c, AppState appState, bool isDark) {
    final weekStart = DateTime.tryParse(c['week_start_date'] as String? ?? '');
    final weekEnd = weekStart?.add(const Duration(days: 6));
    final dateFmt = DateFormat('MM/dd');

    final startValue = (c['start_odometer_value'] as num?)?.toDouble();
    final startImage = c['start_odometer_image_url'] as String?;
    final endValue = (c['end_odometer_value'] as num?)?.toDouble();
    final endImage = c['end_odometer_image_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              weekStart != null && weekEnd != null
                  ? appState
                      .tr('checkpoint_week_label')
                      .replaceFirst('{date}', '${dateFmt.format(weekStart)}–${dateFmt.format(weekEnd)}')
                  : '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildReadingTile(
                  label: appState.tr('checkpoint_start'),
                  value: startValue,
                  imageUrl: startImage,
                  isDark: isDark,
                  appState: appState,
                ),
                const SizedBox(width: 12),
                _buildReadingTile(
                  label: appState.tr('checkpoint_end'),
                  value: endValue,
                  imageUrl: endImage,
                  pendingLabel: endValue == null ? appState.tr('checkpoint_pending_close') : null,
                  isDark: isDark,
                  appState: appState,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingTile({
    required String label,
    required double? value,
    required String? imageUrl,
    required bool isDark,
    required AppState appState,
    String? pendingLabel,
  }) {
    return Expanded(
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _openPhoto(imageUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null
                  ? Image.network(imageUrl, width: 48, height: 48, fit: BoxFit.cover)
                  : Container(
                      width: 48,
                      height: 48,
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      child: const Icon(Icons.image_not_supported_rounded, size: 18, color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey)),
                Text(
                  value != null ? _formatMiles(value, appState) : (pendingLabel ?? '—'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
