// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/tracking_action_button.dart - VERSIÓN ALINEADA Y LIMPIA

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../tracking/tracking_controller.dart';
import '../tracking/gps_watchdog.dart';
import '../errors/app_error.dart';

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

  // DriverOperationsScreen needs to know the moment tracking actually
  // starts (running, not just "the button was tapped") to reveal the
  // live map + incident-report button -- same reasoning as onTripEnded
  // above, just for the opposite transition.
  final VoidCallback? onTripStarted;

  // Roadmap gap closed (pedido explícito): a failed or missing DVIR
  // inspection should block tracking from starting -- v1 deliberately
  // left this unenforced (see driver_operations_screen.dart's own
  // comment on the pre-trip checklist card). Optional and Gig-only-safe
  // by construction: DashboardScreen (Gig) never passes this, so `idle`
  // there behaves exactly as before -- no DVIR concept applies to a
  // personal vehicle. When provided and it resolves false, `_message`
  // is shown instead of starting.
  final Future<bool> Function()? canStart;
  final String? cannotStartMessage;

  // Fleet Sprint 4 (open/rotating vehicle assignment, 2026-09-09): the
  // vehicle a driver picked themselves via FleetVehiclePickerScreen when
  // their org's vehicle_assignment_mode is 'open'. Threaded straight
  // through to TrackingController.startTripFlow -- see its own doc
  // comment. Always null for Gig and for 'fixed'-mode fleet drivers.
  final String? preSelectedVehicleId;

  // Hourly classes (fleet shift blocks, 2026-09-29): called right before
  // the trip starts. Starts the class server-side (start_shift_block, which
  // enforces the start window) and returns its id so the trip is tied to
  // it; throws when the class can't start (shown like any other error).
  // Returns null when there is no class schedule -- a plain fleet trip --
  // and '' when no class can start right now (the caller already told the
  // driver why), which cancels the start.
  final Future<String?> Function()? startShiftBlock;
  // The class was started but the trip then didn't (odometer/GPS step
  // failed or was abandoned): undo it so the class can be started again.
  final Future<void> Function(String blockId)? onShiftBlockStartFailed;

  // Gig dashboard tracking card (2026-10-01, explicit user request): one
  // row -- status text on the left, START/PAUSE/RESUME + END pills on the
  // right -- instead of the big round buttons. Same handlers either way.
  final bool compact;

  const TrackingActionButton({
    super.key,
    required this.selectedGigApp,
    this.selectedIrsPurpose,
    this.onTripEnded,
    this.onTripStarted,
    this.canStart,
    this.cannotStartMessage,
    this.preSelectedVehicleId,
    this.startShiftBlock,
    this.onShiftBlockStartFailed,
    this.compact = false,
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
          if (widget.canStart != null) {
            final allowed = await widget.canStart!();
            if (!allowed) {
              // Subscription-tier enforcement (2026-09-04): a canStart
              // caller can now handle its own feedback (e.g. a real dialog
              // with an upgrade CTA, see dashboard_screen.dart's free-trial
              // gate) by passing null cannotStartMessage on purpose --
              // showing this snackbar too would just stack a redundant,
              // possibly mismatched message on top of whatever canStart
              // already showed. Fleet's DVIR gate is unaffected: it always
              // passes its own cannotStartMessage explicitly (see
              // driver_operations_screen.dart), never relies on this
              // fallback text.
              if (mounted && widget.cannotStartMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(widget.cannotStartMessage!),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
              return;
            }
            if (!mounted) return;
          }
          final shiftBlockId = await widget.startShiftBlock?.call();
          if (!mounted || shiftBlockId == '') return;
          await TrackingController.startTripFlow(
            context: context,
            gigApp: gigApp,
            irsPurpose: gigApp == 'custom' ? widget.selectedIrsPurpose : null,
            // Fleet Phase 3: null for Gig -- see the param's own doc comment
            // in tracking_controller.dart for why this needs to be threaded
            // through at all (RLS visibility for fleet admins).
            organizationId: null,
            preSelectedVehicleId: null,
            shiftBlockId: shiftBlockId,
          );
          if (TrackingController.currentState == TrackingState.running && mounted) {
            _pulseController.repeat();
            widget.onTripStarted?.call();
          } else if (shiftBlockId != null) {
            await widget.onShiftBlockStartFailed?.call(shiftBlockId);
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
          // Resuming with GPS (or its permission) off would restart the clock with no way to
          // record miles: tell the driver what to fix instead of a generic failure.
          if (!await GpsWatchdog.locationReady()) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(appState.tr('gps_resume_blocked')),
                  backgroundColor: Colors.orange.shade800,
                  action: SnackBarAction(
                    label: appState.tr('gps_open_settings'),
                    textColor: Colors.white,
                    onPressed: GpsWatchdog.openSettings,
                  ),
                ),
              );
            }
            break;
          }
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
        final appError = AppError.from(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appError.display(appState.tr(appError.messageKey))),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _handleEndTrip(AppState appState) async {
    if (TrackingController.activeSessionId == null) return;

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

    if (TrackingController.lastStopDiscarded && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.tr('trip_discarded_no_miles'))),
      );
    }

    // Explicit user request (2026-09-08, with a concrete example): the
    // Auto Detection toggle used to stay armed indefinitely after a trip
    // ended (by design, to keep listening for the next one) -- but the
    // user wants pressing Stop Tracking to disarm it too, the same as
    // manually flipping the toggle off, not just the visual flash added
    // earlier today. Runs after stopTracking() is already confirmed OK,
    // so this never interferes with actually closing the trip.
    if (appState.autoDetectEnabled) {
      await appState.setAutoDetectEnabled(false);
    }

    if (mounted) setState(() {});

    // 2026-10-29 (pedido explícito): ya no se fuerza foto de cierre al terminar un
    // viaje. Las fotos son por calendario (el 1 de cada mes, o el 1 y el 15 en
    // Premium): la primera foto de un periodo nuevo cierra el anterior (roll-forward
    // del servidor), y iniciar un viaje sigue bloqueado hasta que exista la foto del
    // periodo en curso (needsCheckpointStartThisWeek en tracking_controller).
    widget.onTripEnded?.call();
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

    if (widget.compact) return _buildCompact(appState, state);

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

  Widget _buildCompact(AppState appState, TrackingState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final subColor = isDark ? Colors.white54 : const Color(0xFF6B6250);
    // Card colors (explicit user request, 2026-10-01): off = red dot,
    // live = blue (dot + PAUSE pill), paused = orange. The big round
    // button elsewhere keeps its own colors (_getButtonColor).
    const liveBlue = Color(0xFF2C6C99);
    final isIdle = state == TrackingState.idle;
    final color = state == TrackingState.running ? liveBlue : _getButtonColor(state);
    final app = TrackingController.currentGigApp;

    final String title;
    final String subtitle;
    if (isIdle) {
      title = appState.tr('ready_to_track');
      subtitle = appState.tr('ready_to_track_body');
    } else if (state == TrackingState.paused) {
      title = appState.tr('tracking_paused_label');
      subtitle = app == null ? '' : app.toUpperCase();
    } else {
      title = appState.tr('tracking_active');
      subtitle = app == null ? '' : app.toUpperCase();
    }

    Widget pill({required VoidCallback onTap, required IconData icon, required String label,
        required Color bg, required Color fg, Color? border, bool big = false}) {
      return Material(
        color: bg,
        shape: StadiumBorder(side: border == null ? BorderSide.none : BorderSide(color: border, width: 1.5)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            // START is bigger (2026-10-09) so it wins over the Premium
            // auto-detect button next to it.
            padding: big
                ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: fg, size: big ? 28 : 20),
              SizedBox(width: big ? 8 : 6),
              Text(label,
                  style: TextStyle(
                      color: fg, fontSize: big ? 16.5 : 13, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
            ]),
          ),
        ),
      );
    }

    return Row(
      children: [
        // Pulsing dot while running, same cue the big button's ring gives.
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) => Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isIdle ? Colors.red.shade600 : color,
              boxShadow: state == TrackingState.running
                  ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4 + 6 * _pulseController.value)]
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: subColor),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        pill(
          onTap: () => _handlePress(appState),
          icon: _getIcon(state),
          label: _getLabel(appState, state),
          bg: color,
          fg: Colors.white,
          big: isIdle,
        ),
        if (!isIdle) ...[
          const SizedBox(width: 8),
          pill(
            onTap: () => _handleEndTrip(appState),
            icon: Icons.stop_rounded,
            label: appState.tr('end').toUpperCase(),
            bg: isDark ? const Color(0xFF1C1812) : Colors.white,
            fg: Colors.red.shade700,
            border: Colors.red.shade200,
          ),
        ],
      ],
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