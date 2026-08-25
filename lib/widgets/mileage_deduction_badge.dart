// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/mileage_deduction_badge.dart
//
// Reemplaza el badge "StandardCM" (Cloud Sync) del Dashboard. Ese badge
// estaba roto: CloudStatusService pegaba a una tabla `tracking_sessions` y
// a `session_sections.is_closed` — ninguna de las dos existe en la DB real
// (son `sessions` y `section_status`) — así que `isOnline` quedaba
// permanentemente en `false` y el badge mostraba "offline" en rojo sin
// importar la conexión real, corriendo timers cada 10-30s todo el día para
// nada.
//
// Se reemplaza por algo con valor directo: millas acumuladas del año
// calendario en curso + estimado de deducción IRS (misma tarifa que ya usa
// el PDF de reportes — ver lib/data/irs_rates.dart, fuente única).
//
// BUG FIX (pedido explícito): el estimado en dólares NO debe dar a entender
// que es la deducción oficial del IRS. El badge solo muestra la cifra; el
// disclaimer completo (qué tarifa se usa, que ControlMiles no es el IRS ni
// está afiliado, que es solo referencia informativa) vive detrás de un tap
// — nunca impreso en el badge en sí.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/irs_rates.dart';
import '../logic/app_state.dart';

class MileageDeductionBadge extends StatefulWidget {
  const MileageDeductionBadge({super.key});

  @override
  State<MileageDeductionBadge> createState() => _MileageDeductionBadgeState();
}

class _MileageDeductionBadgeState extends State<MileageDeductionBadge> {
  double _yearMiles = 0.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadYearMiles();
  }

  Future<void> _loadYearMiles() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Año calendario en curso, hora local — el IRS declara por año
      // calendario para conductores individuales (no hay noción de "año
      // fiscal" custom acá, a diferencia de un negocio).
      final nowLocal = DateTime.now();
      final yearStartLocal = DateTime(nowLocal.year, 1, 1);

      // Mismo patrón que TrackingController.stopTracking() usa para sumar
      // duración de secciones: trae las filas del período y suma en
      // cliente. Volumen esperado (viajes de un usuario en un año) es bajo
      // — no amerita una función agregada en DB todavía.
      final rows = await Supabase.instance.client
          .from('sessions')
          .select('total_miles')
          .eq('user_id', user.id)
          .eq('is_closed', true)
          .gte('start_time', yearStartLocal.toUtc().toIso8601String());

      final sum = (rows as List).fold<double>(
        0.0,
        (acc, r) => acc + ((r['total_miles'] as num?)?.toDouble() ?? 0.0),
      );

      if (!mounted) return;
      setState(() {
        _yearMiles = sum;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[MileageDeductionBadge] Error loading year miles: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDisclaimer(AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appState.tr('irs_estimate_title')),
        content: Text(appState.tr('irs_estimate_disclaimer')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(appState.tr('ok')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (_loading) {
      return const SizedBox(
        height: 34,
        width: 34,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final deduction = calculateIrsDeductionEstimate(_yearMiles);

    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => _showDisclaimer(appState),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.blue),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.speed_rounded, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                '${_yearMiles.toStringAsFixed(0)} mi · ≈\$${deduction.toStringAsFixed(0)} '
                '${appState.tr('year_miles_deduction_estimate')}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
