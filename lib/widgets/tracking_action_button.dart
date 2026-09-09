// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/tracking_action_button.dart - VERSIÓN ALINEADA Y LIMPIA

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/app_state.dart';
import '../tracking/tracking_controller.dart';
import '../screens/odometer_capture_screen.dart';
import '../services/odometer_capture_service.dart';
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

  const TrackingActionButton({
    super.key,
    required this.selectedGigApp,
    this.selectedIrsPurpose,
    this.onTripEnded,
    this.onTripStarted,
    this.canStart,
    this.cannotStartMessage,
    this.preSelectedVehicleId,
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
          await TrackingController.startTripFlow(
            context: context,
            gigApp: gigApp,
            irsPurpose: gigApp == 'custom' ? widget.selectedIrsPurpose : null,
            // Fleet Phase 3: null for Gig -- see the param's own doc comment
            // in tracking_controller.dart for why this needs to be threaded
            // through at all (RLS visibility for fleet admins).
            organizationId: appState.isFleetDriver ? appState.defaultOrgId : null,
            preSelectedVehicleId: appState.isFleetDriver ? widget.preSelectedVehicleId : null,
          );
          if (TrackingController.currentState == TrackingState.running && mounted) {
            _pulseController.repeat();
            widget.onTripStarted?.call();
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

    // Weekly odometer checkpoint (explicit user request, 2026-09-03):
    // ending a trip no longer requires an odometer photo -- that
    // requirement moved to once per Mon-Sun calendar week (see
    // TrackingController.startTripFlow). Captured before stopTracking()
    // resets TrackingController's static state, so there's still a
    // vehicle id to offer the weekly closing photo against below.
    final vehicleIdForClose = TrackingController.activeVehicleId;

    // Sunday-close hardening (explicit user request, 2026-09-08): captured
    // before stopTracking() clears activeSessionId, same reasoning as
    // vehicleIdForClose above -- need this trip's own start_time to decide
    // whether ITS week's close should be mandatory.
    final sessionIdForClose = TrackingController.activeSessionId;

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

    // Offer -- never block ending the trip on -- this week's closing
    // photo, only when this week actually started and hasn't closed yet.
    // A missed close still rolls forward automatically at the next real
    // capture (server-side, see submit_vehicle_odometer_checkpoint), so
    // skipping this dialog is always safe.
    if (mounted && vehicleIdForClose != null) {
      var needsClose = await OdometerCaptureService()
          .needsCheckpointEndThisWeek(vehicleIdForClose);

      // Sunday-close hardening (explicit user request, 2026-09-08): a trip
      // that STARTED on a Sunday (session start_time, not wall-clock at
      // prompt time -- consistent with how week_start_date/mondayOf()
      // already anchor weeks) makes this week's closing photo mandatory
      // instead of the "Later" option every other weekday still keeps.
      // The real floor stays server-side and unchanged: starting NEXT
      // week's first trip already requires a fresh photo either way
      // (needsCheckpointStartThisWeek), and submit_vehicle_odometer_checkpoint's
      // own roll-forward closes whatever week was left open the moment
      // that photo is submitted -- this only makes the UX ask for it
      // immediately on Sunday instead of deferring to Monday.
      var isMandatory = false;
      if (needsClose && sessionIdForClose != null) {
        try {
          final sessionRow = await Supabase.instance.client
              .from('sessions')
              .select('start_time')
              .eq('id', sessionIdForClose)
              .maybeSingle();
          final startTimeStr = sessionRow?['start_time'] as String?;
          if (startTimeStr != null) {
            isMandatory = DateTime.parse(startTimeStr).toLocal().weekday == DateTime.sunday;
          }
        } catch (_) {
          // Fails open to the existing optional behavior -- a lookup
          // hiccup here must never turn into an unclosable dialog.
        }
      }

      while (needsClose) {
        if (!mounted) break;
        final takePhoto = await showDialog<bool>(
          context: context,
          barrierDismissible: !isMandatory,
          builder: (dialogContext) => PopScope(
            canPop: !isMandatory,
            child: AlertDialog(
              title: Text(appState.tr(isMandatory
                  ? 'weekly_odometer_close_title_mandatory'
                  : 'weekly_odometer_close_title')),
              content: Text(appState.tr(isMandatory
                  ? 'weekly_odometer_close_body_mandatory'
                  : 'weekly_odometer_close_body')),
              actions: [
                if (!isMandatory)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(appState.tr('later')),
                  ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(appState.tr('take_photo')),
                ),
              ],
            ),
          ),
        );

        if (takePhoto != true) break; // only reachable when !isMandatory

        if (!mounted) break;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OdometerCaptureScreen(
              isStart: false,
              weeklyCheckpointMode: true,
              vehicleId: vehicleIdForClose,
            ),
          ),
        );

        if (!mounted) break;
        needsClose = await OdometerCaptureService()
            .needsCheckpointEndThisWeek(vehicleIdForClose);
        if (!isMandatory) break; // optional path never loops back
      }
    }

    // Fires DESPUÉS de que stopTracking() confirmó el cierre real Y de
    // que cualquier foto de cierre semanal obligatoria (domingo) ya se
    // resolvió -- reordenado (2026-09-09) porque el caller de Fleet
    // (DriverOperationsScreen) necesita esperar exactamente este punto
    // antes de navegar a la pantalla de "Turno finalizado"; navegar
    // antes habría desmontado este widget a mitad del diálogo semanal
    // obligatorio.
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