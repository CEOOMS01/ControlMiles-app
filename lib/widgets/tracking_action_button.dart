// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/tracking_action_button.dart - VERSIÓN ALINEADA Y LIMPIA

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../tracking/tracking_controller.dart';
import '../screens/odometer_capture_screen.dart';

class TrackingActionButton extends StatefulWidget {
  final String? selectedGigApp;
  // BUG FIX (irs_purpose nunca se guardaba): la categoría IRS elegida para
  // Custom/Truck vivía solo en el estado del Dashboard — este widget nunca
  // la recibía, así que startTripFlow() jamás la pasaba al crear la
  // primera sección del viaje.
  final String? selectedIrsPurpose;

  // BUG FIX (dashboard no se refrescaba tras terminar un viaje): Dashboard
  // solo recargaba Recent Trips en initState() o pull-to-refresh manual —
  // nada avisaba cuando un viaje terminaba desde este botón. Callback
  // opcional para que el padre (DashboardScreen) recargue su propio estado
  // justo después de que stopTracking() confirme el cierre.
  final VoidCallback? onTripEnded;

  const TrackingActionButton({
    super.key,
    required this.selectedGigApp,
    this.selectedIrsPurpose,
    this.onTripEnded,
  });

  @override
  State<TrackingActionButton> createState() => _TrackingActionButtonState();
}

class _TrackingActionButtonState extends State<TrackingActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handlePress(AppState appState) async {
    if (!mounted) return;

    final currentState = TrackingController.currentState;
    final gigApp = widget.selectedGigApp ?? TrackingController.currentGigApp;

    if (gigApp == null || gigApp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appState.tr('select_an_activity_before_starting_tracking'),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      switch (currentState) {
        case TrackingState.idle:
          await TrackingController.startTripFlow(
            context: context,
            gigApp: gigApp,
            irsPurpose: gigApp == 'custom' ? widget.selectedIrsPurpose : null,
            // Fleet Phase 3: null for Gig -- see the param's own doc comment
            // in tracking_controller.dart for why this needs to be threaded
            // through at all (RLS visibility for fleet admins).
            organizationId: appState.isFleetDriver ? appState.defaultOrgId : null,
          );
          if (TrackingController.currentState == TrackingState.running && mounted) {
            _pulseController.repeat();
          }
          break;

        case TrackingState.running:
          // BUG FIX (pedido explícito, alerta de hallazgos relacionados):
          // antes el pulso se detenía sin importar si pauseTracking() de
          // verdad tuvo éxito -- ahora solo se detiene si la pausa se
          // confirmó; si falla, se avisa y el tracking real sigue
          // corriendo (el pulso también, honestamente).
          final pausedOk = await TrackingController.pauseTracking();
          if (pausedOk) {
            _pulseController.stop();
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(appState.tr('pause_failed')),
                backgroundColor: Colors.red,
              ),
            );
          }
          break;

        case TrackingState.paused:
          // Mismo criterio: el pulso solo vuelve a animar si resumeTracking()
          // confirmó que de verdad reanudó (GPS + DB + estado).
          final resumedOk = await TrackingController.resumeTracking();
          if (resumedOk) {
            if (mounted) _pulseController.repeat();
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(appState.tr('resume_failed')),
                backgroundColor: Colors.red,
              ),
            );
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${appState.tr('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _handleEndTrip(AppState appState) async {
    if (TrackingController.activeSessionId == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OdometerCaptureScreen(
          sessionId: TrackingController.activeSessionId!,
          isStart: false,
        ),
      ),
    );

    if (result == null || result['success'] != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appState.tr('odometer_required_to_end'),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // BUG FIX (pedido explícito, alerta de hallazgos relacionados): antes
    // el pulso se reseteaba y Dashboard recargaba Recent Trips sin
    // confirmar que stopTracking() de verdad cerró la sesión -- si el
    // update final a `sessions` fallaba, la sesión se quedaba abierta en
    // DB para siempre mientras la UI ya decía "viaje terminado". Ahora
    // solo se resetea/recarga si stopTracking() confirmó el cierre real.
    final stoppedOk = await TrackingController.stopTracking();

    if (!stoppedOk) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appState.tr('end_trip_failed')),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {});
      }
      return;
    }

    _pulseController.reset();

    // (comentario original conservado): se notifica DESPUÉS de que
    // stopTracking() confirmó el cierre (cierre de sección final + suma
    // de duración + update de sessions), no antes — así el padre recarga
    // solo cuando los datos ya están persistidos.
    widget.onTripEnded?.call();

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final state = TrackingController.currentState;
    final isRunning = state == TrackingState.running;
    final isIdle = state == TrackingState.idle;

    // Sincronizar animación
    if (isRunning && !_pulseController.isAnimating) {
      _pulseController.repeat();
    } else if (!isRunning && _pulseController.isAnimating) {
      _pulseController.stop();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botón principal
          GestureDetector(
            onTap: () => _handlePress(appState),
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isRunning)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 80 + (50 * _pulseController.value),
                          height: 80 + (50 * _pulseController.value),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _getButtonColor(state)
                                  .withValues(alpha: 0.6 - _pulseController.value * 0.4),
                              width: 4,
                            ),
                          ),
                        );
                      },
                    ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: _getButtonColor(state),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _getButtonColor(state).withValues(alpha: 0.4),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_getIcon(state), color: Colors.white, size: 36),
                        const SizedBox(height: 6),
                        Text(
                          _getLabel(appState, state),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botón End Trip
          if (!isIdle) ...[
            const SizedBox(width: 24),
            GestureDetector(
              onTap: () => _handleEndTrip(appState),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 78,
                width: 78,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.shade200, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stop, color: Colors.red.shade700, size: 26),
                    const SizedBox(height: 4),
                    Text(
                      appState.tr('end').toUpperCase(),
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getButtonColor(TrackingState state) {
    if (state == TrackingState.running) return Colors.red.shade700;
    if (state == TrackingState.paused) return Colors.orange.shade700;
    return Theme.of(context).colorScheme.primary;
  }

  IconData _getIcon(TrackingState state) {
    if (state == TrackingState.running) return Icons.pause;
    if (state == TrackingState.paused) return Icons.play_arrow;
    return Icons.play_arrow;
  }

  String _getLabel(AppState appState, TrackingState state) {
    if (state == TrackingState.running) return appState.tr('pause').toUpperCase();
    if (state == TrackingState.paused) return appState.tr('resume').toUpperCase();
    return appState.tr('start').toUpperCase();
  }
}