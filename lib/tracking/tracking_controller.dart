// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/tracking_controller.dart
// VERSIÓN ALINEADA CON BASE DE DATOS v3 + SessionSection limpio

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/session_section.dart';
import '../services/audit_service.dart';
import '../services/local_storage_service.dart';
import '../services/vehicle_service.dart';
import '../services/notification_service.dart';
import '../screens/odometer_capture_screen.dart';
import 'antifraud_engine.dart';
import 'background_gps_service.dart';

enum TrackingState { idle, running, paused }

class TrackingController {
  // ============================================================
  // ESTADO GLOBAL
  // ============================================================
  static SessionSection? activeSection;
  static String? activeSessionId;
  static TrackingState currentState = TrackingState.idle;
  static String? currentGigApp;

  static DateTime _lastDbUpdateTime = DateTime.now();
  static DateTime _lastAuditLogTime = DateTime.now();
  static int _gpTicksProcessed = 0;

  static double _totalSectionMiles = 0.0;
  static double _totalSessionMiles = 0.0;

  // BUG FIX #2 (pausa no sobrevive reinicio): el diseño anterior
  // (_pauseStartedAt + _accumulatedPausedSeconds, un contador que solo
  // sabía "cuánto se ha pausado" en memoria) no tenía forma de
  // reconstruirse tras un reinicio real de la app — esos dos campos static
  // volvían a sus valores por defecto en un isolate nuevo, y cualquier
  // pausa anterior al reinicio se volvía a contar como manejo activo.
  //
  // Nuevo modelo: activeSection.totalDurationSeconds es la duración activa
  // "confirmada" — se banca (persiste) en cada pausa/resume/cierre de
  // sección. _runSegmentStartedAt marca cuándo arrancó el tramo de manejo
  // activo actual. elapsedSectionDuration = base confirmada + tiempo vivo
  // desde _runSegmentStartedAt. Al recuperar el estado (reinicio real,
  // headless, lo que sea), _runSegmentStartedAt se resetea a "ahora" — no
  // hace falta reconstruir ninguna pausa histórica, porque la base ya
  // persistida (en DB o en el checkpoint local) ya la tiene descontada.
  static DateTime? _runSegmentStartedAt;

  // ============================================================
  // GETTERS
  // ============================================================
  static double get activeDistance => _totalSectionMiles;
  static bool get isPaused => currentState == TrackingState.paused;
  static bool get isRunning => currentState == TrackingState.running;

  /// Tiempo transcurrido de la sección actual (se DETIENE correctamente al pausar)
  ///
  /// = base confirmada (activeSection.totalDurationSeconds, banca lo ya
  /// manejado hasta la última pausa/resume/recuperación) + tiempo corrido
  /// desde que arrancó el tramo activo actual (_runSegmentStartedAt).
  static Duration get elapsedSectionDuration {
    if (activeSection == null) return Duration.zero;

    final base = Duration(seconds: activeSection!.totalDurationSeconds ?? 0);

    if (currentState != TrackingState.running || _runSegmentStartedAt == null) {
      return base;
    }

    final liveElapsed = DateTime.now().difference(_runSegmentStartedAt!);
    final total = base + liveElapsed;
    return total.isNegative ? Duration.zero : total;
  }

  // ============================================================
  // RESET ESTADO
  // ============================================================
  static void _resetState() {
    activeSessionId = null;
    activeSection = null;
    currentGigApp = null;
    currentState = TrackingState.idle;
    _totalSectionMiles = 0.0;
    _totalSessionMiles = 0.0;
    _gpTicksProcessed = 0;
    _runSegmentStartedAt = null;
    AntifraudEngine.reset();
    LocalStorageService.clearAllCheckpoint();
  }

  // ============================================================
  // START TRIP FLOW (Flujo principal desde botón)
  // ============================================================
  static Future<void> startTripFlow({
    required BuildContext context,
    required String gigApp,
    String? irsPurpose,
    // Fleet Phase 3: null for a Gig trip. When the caller is a fleet_driver,
    // this is AppState.defaultOrgId -- written onto sessions/session_sections
    // so sessions_select/sections_select RLS (is_org_member(organization_id),
    // built in Phase 1) actually has something to match against. Before this,
    // NOTHING ever wrote organization_id on a real trip -- the org-visibility
    // policy existed but a fleet admin would never have seen a single driver
    // trip through it, since the column was always null regardless of who
    // was driving.
    String? organizationId,
  }) async {
    if (currentState != TrackingState.idle) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final sessionId = const Uuid().v4();
      currentGigApp = gigApp;

      // BUG FIX: sessions.vehicle_id existía en la DB pero ningún código lo
      // escribía (0 de 7 sesiones reales lo tenían seteado) — el "vehículo
      // activo" mostrado en Dashboard nunca quedaba asociado al viaje que
      // en verdad se estaba grabando. Se adjunta acá, en el único punto
      // real de creación de sesión. Si el usuario no tiene vehículo activo,
      // el viaje arranca igual con vehicle_id en null (no bloqueante).
      //
      // Fleet Phase 3: getActiveOrAssignedVehicle() es el único punto de la
      // rama Gig/Fleet para "qué vehículo" -- ver su comentario en
      // VehicleService antes de reimplementar esta decisión en otro lado.
      final activeVehicle = await VehicleService()
          .getActiveOrAssignedVehicle(user.id, organizationId: organizationId);

      // Crear sesión principal
      await Supabase.instance.client.from('sessions').insert({
        "id": sessionId,
        "user_id": user.id,
        "vehicle_id": activeVehicle?.id,
        "organization_id": organizationId,
        "start_time": DateTime.now().toUtc().toIso8601String(),
        "session_status": "active",
        "is_closed": false,
        "total_miles": 0.0,
        "date_key": DateTime.now().toIso8601String().split('T')[0],
      });

      activeSessionId = sessionId;

      // Captura obligatoria de odómetro inicial
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OdometerCaptureScreen(
            sessionId: sessionId,
            isStart: true,
          ),
        ),
      );

      if (result == null || result['success'] != true) {
        await Supabase.instance.client.from("sessions").delete().eq("id", sessionId);
        _resetState();
        return;
      }

      // Iniciar primera sección
      await startNewSection(
        sessionId: sessionId,
        gigApp: gigApp,
        irsPurpose: irsPurpose,
        organizationId: organizationId,
      );

      await BackgroundGpsService.startTracking();
      await _saveLocalCheckpoint();

      currentState = TrackingState.running;

      // BUG FIX (toggle de notificaciones inerte): recordatorio de "viaje
      // olvidado" — se cancela en stopTracking(). Respeta el toggle de
      // Settings internamente (ver NotificationService), así que es seguro
      // llamarlo siempre acá sin chequear el setting en este archivo.
      await NotificationService.instance.scheduleForgottenTripReminder();

      _logDebug('TRIP_START_OK', 'Session and section created successfully');
    } catch (e) {
      _logError('TRIP_FLOW_ERROR', e.toString());
      _resetState();
    }
  }

  // ============================================================
  // START NEW SECTION (usado por startTripFlow — primera sección del viaje)
  // ============================================================
  static Future<void> startNewSection({
    required String sessionId,
    required String gigApp,
    String? irsPurpose,
    String? organizationId,
  }) async {
    // NOTA: switchSection() ya NO llama a startNewSection() — usa el RPC
    // atómico switch_gig_app_section() directamente (ver comentario en
    // switchSection). El único llamador real de startNewSection es
    // startTripFlow(), donde activeSection siempre es null. Este guard
    // queda solo como defensa, no como flujo activo — no duplicar la
    // lógica de cierre-y-creación acá si se agrega otro llamador.
    if (activeSection != null) await endCurrentSection();

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final sectionId = const Uuid().v4();
      final now = DateTime.now().toUtc();

      _lastDbUpdateTime = now;
      _lastAuditLogTime = now;

      final response = await Supabase.instance.client
          .from('session_sections')
          .insert({
            'id': sectionId,
            'session_id': sessionId,
            'user_id': user.id,
            'organization_id': organizationId,
            'gig_app': gigApp,
            'irs_purpose': (gigApp == 'custom') ? irsPurpose : null,
            'section_status': 'active',
            'total_miles': 0.0,
            'total_duration_seconds': 0,
            'start_time': now.toIso8601String(),
            'start_latitude': null,
            'start_longitude': null,
          })
          .select()
          .single();

      activeSection = SessionSection.fromMap(response);
      _totalSectionMiles = 0.0;
      // Sección nueva: el reloj de manejo activo arranca ahora, base en 0
      // (ya viene así de la fila recién insertada).
      _runSegmentStartedAt = DateTime.now();
      AntifraudEngine.reset();

      await _saveLocalCheckpoint();

      await AuditService.logEvent(
        sessionId: sessionId,
        sectionId: sectionId,
        eventType: "SECTION_START",
        payload: {
          "gig_app": gigApp,
          "irs_purpose": irsPurpose,
        },
      );

      _logDebug('SECTION_START_OK',
          'Section started → gig_app: $gigApp, irs_purpose: $irsPurpose');
    } catch (e) {
      _logError('SECTION_START_ERROR', e.toString());
    }
  }

  // ============================================================
  // PAUSE TRACKING
  // ============================================================
  // BUG FIX (pedido explícito, alerta de hallazgos relacionados): antes
  // devolvía Future<void> -- TrackingActionButton detenía el pulso de
  // "tracking activo" sin saber si la pausa de verdad se guardó. Ahora
  // devuelve bool: true solo si el CORE (frenar GPS + actualizar la
  // sección en DB + mover currentState) tuvo éxito. Efectos secundarios
  // (checkpoint local, audit log) van en su propio try/catch, aislados --
  // que fallen esos NO debe reportar "la pausa falló" si el core ya
  // quedó bien guardado (eso sería peor: mostraría "sigue corriendo"
  // sobre un viaje que en realidad ya se pausó bien).
  static Future<bool> pauseTracking() async {
    if (currentState != TrackingState.running) return false;

    try {
      await BackgroundGpsService.stopTracking();

      if (activeSection != null) {
        final elapsedSeconds = elapsedSectionDuration.inSeconds;

        await Supabase.instance.client
            .from('session_sections')
            .update({
              'section_status': 'paused',
              'total_miles': _totalSectionMiles,
              'total_duration_seconds': elapsedSeconds,
              'end_time': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', activeSection!.id);

        activeSection = activeSection!.copyWith(
          status: 'paused',
          totalDurationSeconds: elapsedSeconds,
          endTime: DateTime.now(),
        );
      }

      currentState = TrackingState.paused;
      // Se apaga el reloj de manejo activo — la duración ya quedó bancada
      // arriba en activeSection.totalDurationSeconds.
      _runSegmentStartedAt = null;

      // Efectos secundarios best-effort: si fallan, la pausa YA es real
      // (GPS frenado + DB actualizada + currentState movido arriba), así
      // que no deben tumbar el resultado.
      try {
        await _saveLocalCheckpoint();

        if (activeSessionId != null) {
          await AuditService.logEvent(
            sessionId: activeSessionId!,
            sectionId: activeSection?.id ?? '',
            eventType: "TRACKING_PAUSED",
            payload: {"miles": _totalSectionMiles},
          );
        }
      } catch (e) {
        _logError('PAUSE_SIDE_EFFECT_ERROR', e.toString());
      }

      _logDebug('PAUSED', 'Tracking paused - Timer stopped');
      return true;
    } catch (e) {
      _logError('PAUSE_ERROR', e.toString());
      return false;
    }
  }

  // ============================================================
  // RESUME TRACKING
  // ============================================================
  // BUG FIX (pedido explícito, alerta de hallazgos relacionados): dos
  // problemas acá. (1) Igual que pauseTracking, devolvía Future<void> --
  // el botón reanudaba la animación de pulso sin confirmar que el resume
  // de verdad tuvo éxito. (2) Más grave: el orden original arrancaba
  // BackgroundGpsService.startTracking() y _runSegmentStartedAt ANTES del
  // update a la DB -- si ese update fallaba, el servicio de GPS quedaba
  // corriendo de verdad (batería real gastándose) mientras currentState
  // se quedaba en 'paused' (la asignación a 'running' pasaba después,
  // nunca se alcanzaba). Fuga de recurso silenciosa. Ahora la DB va
  // PRIMERO: si falla, no se toca GPS ni el reloj de manejo activo --
  // nada que revertir.
  static Future<bool> resumeTracking() async {
    if (currentState != TrackingState.paused) return false;
    if (activeSessionId == null || activeSection == null) return false;

    try {
      await Supabase.instance.client
          .from('session_sections')
          .update({
            'section_status': 'active',
            'end_time': null,
          })
          .eq('id', activeSection!.id);

      // Solo tras confirmar la DB se arranca GPS real y el reloj de
      // manejo activo. La base confirmada (activeSection.totalDurationSeconds,
      // guardada al pausar) NO se toca — se le sigue sumando en vivo desde
      // este punto. Esto es justo lo que hace que la duración sobreviva un
      // reinicio real de la app: no hace falta reconstruir ninguna pausa
      // histórica, solo esta base ya persistida (local o en DB).
      await BackgroundGpsService.startTracking();
      _runSegmentStartedAt = DateTime.now();

      activeSection = activeSection!.copyWith(
        status: 'active',
        endTime: null,
        // totalDurationSeconds: sin tocar — sigue siendo la base confirmada.
      );

      currentState = TrackingState.running;

      // Efectos secundarios best-effort: el resume real ya sucedió arriba.
      try {
        await _saveLocalCheckpoint();

        await AuditService.logEvent(
          sessionId: activeSessionId!,
          sectionId: activeSection!.id,
          eventType: "TRACKING_RESUMED",
          payload: {"miles": _totalSectionMiles},
        );
      } catch (e) {
        _logError('RESUME_SIDE_EFFECT_ERROR', e.toString());
      }

      _logDebug('RESUMED', 'Tracking resumed successfully');
      return true;
    } catch (e) {
      _logError('RESUME_ERROR', e.toString());
      return false;
    }
  }

  // ============================================================
  // SWITCH SECTION
  // ============================================================
  // BUG FIX #2 (switch de gig app no atómico): la versión anterior cerraba
  // la sección vieja (endCurrentSection, que además borraba el checkpoint
  // local) y recién después insertaba la nueva — dos llamadas de red
  // separadas. Eso dejaba una ventana real con activeSection == null
  // mientras currentState seguía 'running': un tick GPS cayendo justo ahí
  // no encontraba checkpoint (recién borrado) ni sección abierta en DB (la
  // vieja ya cerrada, la nueva aún no existía) y mataba el tracking en
  // silencio. Peor: endCurrentSection() atrapa su propia excepción y nunca
  // la relanza, así que si el cierre fallaba por red, el código seguía
  // igual y creaba la sección nueva — dos filas 'active' para la misma
  // sesión, la vieja huérfana para siempre.
  //
  // Ahora ambos pasos (cerrar vieja + crear nueva) van en una sola llamada
  // a la función switch_gig_app_section() en Postgres, ejecutada en una
  // transacción — todo o nada. Un índice único parcial en DB
  // (uq_session_sections_one_open_per_session) blinda esto a nivel de
  // schema sin importar qué código lo llame.
  // BUG FIX (pedido explícito, hallazgo secundario del bug de pausa): antes
  // devolvía Future<void> y tragaba su propia excepción sin avisar al
  // llamador -- dashboard_screen.dart la llamaba fire-and-forget y
  // mostraba "SWITCHED" de inmediato, sin saber si el RPC en verdad tuvo
  // éxito. Ahora devuelve bool para que el llamador pueda esperar la
  // confirmación real antes de tocar cualquier estado optimista en la UI.
  static Future<bool> switchSection(String newGigApp, {String? irsPurpose}) async {
    if (currentState != TrackingState.running || activeSessionId == null) return false;
    if (activeSection?.gigApp == newGigApp) return false;

    final oldSection = activeSection;
    final newSectionId = const Uuid().v4();

    try {
      final elapsedSeconds =
          oldSection != null ? elapsedSectionDuration.inSeconds : null;

      final response = await Supabase.instance.client.rpc(
        'switch_gig_app_section',
        params: {
          'p_session_id': activeSessionId,
          'p_old_section_id': oldSection?.id,
          'p_new_section_id': newSectionId,
          'p_new_gig_app': newGigApp,
          'p_new_irs_purpose': irsPurpose,
          'p_old_total_miles': oldSection != null ? _totalSectionMiles : null,
          'p_old_total_duration_seconds': elapsedSeconds,
          'p_old_end_latitude': AntifraudEngine.lastLat,
          'p_old_end_longitude': AntifraudEngine.lastLng,
        },
      );

      final rows = response as List;
      if (rows.isEmpty) {
        throw Exception('switch_gig_app_section returned no rows');
      }

      // Solo se toca el estado en memoria DESPUÉS de que el RPC confirmó
      // éxito atómico en DB — si algo falla arriba, ni activeSection ni
      // currentGigApp se mueven (ver catch abajo).
      activeSection = SessionSection.fromMap(rows.first as Map<String, dynamic>);
      currentGigApp = newGigApp;
      _totalSectionMiles = 0.0;
      _runSegmentStartedAt = DateTime.now();
      AntifraudEngine.reset();

      await _saveLocalCheckpoint();

      await AuditService.logEvent(
        sessionId: activeSessionId!,
        sectionId: activeSection!.id,
        eventType: "SECTION_SWITCHED",
        payload: {
          "from_gig_app": oldSection?.gigApp,
          "to_gig_app": newGigApp,
          "old_section_id": oldSection?.id,
          "irs_purpose": irsPurpose,
        },
      );

      _logDebug('SWITCH_OK', 'Switched atomically → gig_app: $newGigApp');
      return true;
    } catch (e) {
      // Si el RPC falla (red, RLS, lo que sea) no se toca ningún estado en
      // memoria: activeSection/currentGigApp siguen apuntando a la sección
      // vieja, que en DB sigue intacta (active/paused) porque la
      // transacción no se completó. No queda sección huérfana ni tracking
      // muerto — el usuario sigue en el gig app anterior y puede reintentar.
      _logError('SWITCH_ERROR', e.toString());
      return false;
    }
  }

  // ============================================================
  // STOP TRACKING (Finalizar viaje completo)
  // ============================================================
  // BUG FIX (pedido explícito, alerta de hallazgos relacionados + hallazgo
  // nuevo encontrado al implementar este fix): (1) devolvía Future<void>
  // -- End Trip reseteaba el botón y recargaba Recent Trips sin confirmar
  // que el viaje de verdad terminó; si el update final a `sessions`
  // fallaba, la sesión se quedaba abierta en DB para siempre mientras la
  // UI ya mostraba "viaje terminado". (2) no chequeaba el resultado de
  // endCurrentSection() -- si esa cerradura fallaba, igual seguía de
  // largo y marcaba la SESIÓN completa como cerrada con una sección
  // todavía abierta adentro (inconsistencia que nunca se hubiera notado
  // en la UI). Ahora aborta ahí si falla, y solo devuelve true cuando la
  // sesión de verdad quedó cerrada en DB.
  static Future<bool> stopTracking() async {
    if (currentState == TrackingState.idle || activeSessionId == null) return false;

    try {
      await BackgroundGpsService.stopTracking();

      final sectionClosed = await endCurrentSection();
      if (!sectionClosed) {
        // No cerrar la sesión completa con una sección todavía abierta
        // adentro -- mejor dejar todo como estaba (running/paused) que
        // marcar 'closed' sobre datos a medio cerrar. El usuario puede
        // reintentar End Trip.
        _logError('STOP_ABORTED', 'endCurrentSection falló, sesión no se marca cerrada');
        return false;
      }

      // BUG FIX: total_duration_seconds de la sesión nunca se guardaba (0 en
      // el 100% de las sesiones reales revisadas en la DB). Se suma la
      // duración real de todas las secciones ya cerradas de esta sesión —
      // así el tiempo pausado o entre cambios de gig app no cuenta de más.
      int sessionDurationSeconds = 0;
      try {
        final sections = await Supabase.instance.client
            .from('session_sections')
            .select('total_duration_seconds')
            .eq('session_id', activeSessionId!);

        sessionDurationSeconds = (sections as List).fold<int>(
          0,
          (sum, s) => sum + ((s['total_duration_seconds'] as num?)?.toInt() ?? 0),
        );
      } catch (e) {
        _logError('SESSION_DURATION_SUM_ERROR', e.toString());
      }

      await Supabase.instance.client.from('sessions').update({
        'session_status': 'closed',
        'is_closed': true,
        'end_time': DateTime.now().toUtc().toIso8601String(),
        'total_miles': _totalSessionMiles,
        'total_duration_seconds': sessionDurationSeconds,
      }).eq('id', activeSessionId!);

      _resetState();

      // Efecto secundario best-effort: la sesión ya quedó cerrada arriba.
      try {
        await NotificationService.instance.cancelForgottenTripReminder();
      } catch (e) {
        _logError('STOP_SIDE_EFFECT_ERROR', e.toString());
      }

      _logDebug('TRACKING_STOP_OK', 'Session closed successfully');
      return true;
    } catch (e) {
      _logError('STOP_ERROR', e.toString());
      return false;
    }
  }

  // ============================================================
  // GPS TICK
  // ============================================================
  static Future<void> processGpsTick({
    required double latitude,
    required double longitude,
    required double speed,
    required double accuracy,
    required DateTime timestamp,
    bool isMock = false,
  }) async {
    // BUG FIX: un tick real llegando con activeSection == null casi siempre
    // significa que este isolate no tiene el estado cargado en memoria (ver
    // _recoverActiveState arriba) — no necesariamente que no hay viaje
    // activo. Se intenta recuperar antes de descartarlo. Si en verdad no
    // hay sesión activa, la recuperación deja todo en null/idle y el guard
    // de abajo descarta el tick igual, sin efectos secundarios.
    if (activeSection == null) {
      await _recoverActiveState(startGps: false);
    }

    if (activeSection == null || currentState != TrackingState.running) return;

    final prevLat = AntifraudEngine.lastLat;
    final prevLng = AntifraudEngine.lastLng;

    final result = AntifraudEngine.evaluate(
      latitude: latitude,
      longitude: longitude,
      speed: speed,
      accuracy: accuracy,
      timestamp: timestamp,
      isMock: isMock,
    );

    if (!result.isValid) {
      // Antes un punto rechazado desaparecía sin dejar rastro (ni log de
      // debug). Esto solo ayuda a diagnosticar en desarrollo — no escribe
      // en la DB ni en el audit log, para no llenarlo de ruido.
      _logDebug('GPS_TICK_REJECTED', '${result.reason} (score: ${result.drivingSignatureScore})');
      return;
    }

    // BUG FIX: start_latitude/start_longitude nunca se guardaban en ningún
    // punto del código vivo (quedaban null en el 100% de las secciones
    // reales). prevLat/prevLng nulos identifican el primer punto GPS válido
    // de esta sección — se usa como coordenada de inicio.
    if (prevLat == null &&
        prevLng == null &&
        activeSection!.startLatitude == null) {
      activeSection = activeSection!.copyWith(
        startLatitude: latitude,
        startLongitude: longitude,
      );

      try {
        await Supabase.instance.client
            .from('session_sections')
            .update({
              'start_latitude': latitude,
              'start_longitude': longitude,
            })
            .eq('id', activeSection!.id);
      } catch (e) {
        _logError('START_COORDS_SAVE_ERROR', e.toString());
      }
    }

    if (prevLat != null && prevLng != null) {
      final meters = _calculateHaversine(prevLat, prevLng, latitude, longitude);
      final miles = meters / 1609.34;

      if (miles > 0.0012) {
        _totalSectionMiles += miles;
        _totalSessionMiles += miles;
        _gpTicksProcessed++;

        activeSection = activeSection!.copyWith(totalMiles: _totalSectionMiles);

        await LocalStorageService.updateTotalMiles(_totalSectionMiles, _totalSessionMiles);

        final hasConnection = await _hasGoodConnection();
        if (!hasConnection) {
          await LocalStorageService.saveOfflineBuffer(
            sectionId: activeSection!.id,
            milesToAdd: miles,
            timestamp: timestamp,
          );
        }

        await _smartSync(result.drivingSignatureScore);
      }
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================
  static Future<void> _saveLocalCheckpoint() async {
    if (activeSessionId == null || activeSection == null) return;

    await LocalStorageService.saveTripCheckpoint(
      sessionId: activeSessionId!,
      sectionId: activeSection!.id,
      userId: activeSection!.userId,
      gigApp: currentGigApp ?? 'custom',
      sectionStartTime: activeSection!.startTime,
      // Base de duración confirmada al momento del checkpoint (0 si la
      // sección recién arrancó y aún no se ha pausado nunca).
      sectionDurationSeconds: activeSection!.totalDurationSeconds ?? 0,
      totalSessionMiles: _totalSessionMiles,
      totalSectionMiles: _totalSectionMiles,
      isPaused: currentState == TrackingState.paused,
    );
  }

  /// BUG FIX (toggle de notificaciones inerte): re-arma el recordatorio de
  /// "viaje olvidado" tras cualquier recuperación de estado que resulte en
  /// currentState == running (reinicio de app, headless, lo que sea).
  ///
  /// Limitación conocida y aceptada: como el checkpoint local no guarda el
  /// start_time original de la SESIÓN (solo el de la sección activa, que
  /// puede no ser la primera si hubo switches de gig app), esto reinicia el
  /// conteo de 8 horas desde el momento de la recuperación, no desde el
  /// inicio real del viaje. Para un recordatorio informativo no crítico es
  /// un costo aceptable — documentado para que no sorprenda si se revisa
  /// más adelante.
  static Future<void> _rescheduleForgottenTripReminderIfRunning() async {
    if (currentState == TrackingState.running) {
      await NotificationService.instance.scheduleForgottenTripReminder();
    }
  }

  static Future<bool> _hasGoodConnection() async {
    try {
      return Supabase.instance.client.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> initializeOrRecover() async {
    await _recoverActiveState(startGps: true);
  }

  // ============================================================
  // RECUPERACIÓN DE ESTADO (compartida entre arranque en frío y ticks GPS)
  // ============================================================
  //
  // BUG FIX (millas/tiempo muerto en viajes largos): TrackingController es
  // una clase completamente `static`. Cuando Android mata el proceso de la
  // app durante un viaje largo (pantalla apagada, horas de manejo) y luego
  // despierta un isolate headless nuevo para procesar un evento GPS
  // (enableHeadless: true en background_gps_service.dart), ese isolate
  // arranca con activeSection = null y currentState = idle por defecto —
  // los campos static NO sobreviven entre isolates. processGpsTick()
  // descartaba silenciosamente cada tick real de ese tramo porque su guard
  // de seguridad (no contar millas sin sección activa) no distinguía "no
  // hay viaje" de "el estado simplemente no está cargado en este isolate".
  //
  // Además, el propio initializeOrRecover() tenía el mismo problema en su
  // camino "rápido" por local storage: restauraba sessionId/millas/gigApp
  // pero JAMÁS reconstruía `activeSection` (solo lo hacía el camino de DB).
  // Así que incluso un reinicio normal de la app (sin nada headless de por
  // medio) podía dejar currentState=running con activeSection=null, y la
  // UI mostrando "tracking activo" mientras cada tick se descartaba.
  //
  // _recoverActiveState() unifica ambos caminos y siempre reconstruye
  // activeSection (vía _hydrateSectionFromDb) antes de darse por
  // satisfecho. Se usa tanto desde initializeOrRecover() (arranque normal,
  // startGps: true) como reactivamente desde processGpsTick() cuando un
  // tick llega con activeSection == null (startGps: false, porque un tick
  // real ya es la prueba de que el plugin de GPS está corriendo).
  static Future<void> _recoverActiveState({required bool startGps}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _resetState();
      return;
    }

    // Recuperar desde local storage primero (más rápido).
    final localState = await LocalStorageService.getRecoverableState();
    if (localState != null && localState['sectionId'] != null) {
      // BUG FIX (offline hardening): el checkpoint ahora guarda user_id y
      // section_start_time, así que la sección se puede reconstruir sin
      // red. Antes esto SIEMPRE necesitaba un query a la DB — un teléfono
      // sin señal justo cuando el SO despierta el isolate headless no
      // podía recuperarse y ese tramo del viaje se perdía igual.
      final hydratedLocally = _hydrateSectionFromLocalCheckpoint(localState);

      if (hydratedLocally) {
        _applyRecoveredCheckpointFields(localState);
        if (currentState == TrackingState.running && startGps) {
          await BackgroundGpsService.startTracking();
        }
        await _rescheduleForgottenTripReminderIfRunning();
        _logDebug('RECOVERY_OK', 'Recovered 100% offline from local checkpoint');
        return;
      }

      // Checkpoint viejo (guardado antes de este fix, sin section_start_time
      // ni user_id) o incompleto — intentar hidratar vía DB como respaldo.
      final sectionId = localState['sectionId'] as String;
      final hydratedFromDb = await _hydrateSectionFromDb(sectionId);

      if (hydratedFromDb) {
        _applyRecoveredCheckpointFields(localState);
        if (currentState == TrackingState.running && startGps) {
          await BackgroundGpsService.startTracking();
        }
        await _rescheduleForgottenTripReminderIfRunning();
        _logDebug('RECOVERY_OK', 'Recovered from local storage (section hydrated via DB)');
        return;
      }
      // Ni la reconstrucción local ni la de DB funcionaron (sección cerrada
      // desde otro lado, datos viejos, o sin red y checkpoint incompleto) —
      // seguir al fallback de DB completo de abajo.
    }

    // Recuperar desde base de datos (fuente de verdad completa)
    try {
      final session = await Supabase.instance.client
          .from('sessions')
          .select('*, session_sections(*)')
          .eq('user_id', user.id)
          .eq('is_closed', false)
          .maybeSingle();

      if (session == null) {
        _resetState();
        return;
      }

      activeSessionId = session['id'];
      _totalSessionMiles = (session['total_miles'] as num?)?.toDouble() ?? 0.0;

      final activeSections = (session['session_sections'] as List?)
          ?.where((s) => ['active', 'paused'].contains(s['section_status']))
          .toList() ?? [];

      if (activeSections.isNotEmpty) {
        final sectionData = activeSections.first;
        activeSection = SessionSection.fromMap(sectionData);
        currentGigApp = activeSection?.gigApp;
        _totalSectionMiles = (sectionData['total_miles'] as num?)?.toDouble() ?? 0.0;

        currentState = sectionData['section_status'] == 'paused'
            ? TrackingState.paused
            : TrackingState.running;

        // BUG FIX #3: igual que en _applyRecoveredCheckpointFields — el
        // reloj de manejo activo arranca de "ahora"; la base ya viene
        // correcta desde SessionSection.fromMap (total_duration_seconds).
        _runSegmentStartedAt =
            currentState == TrackingState.running ? DateTime.now() : null;

        if (currentState == TrackingState.running && startGps) {
          await BackgroundGpsService.startTracking();
        }
        await _rescheduleForgottenTripReminderIfRunning();

        await _saveLocalCheckpoint();
        _logDebug('RECOVERY_OK', 'Recovered from database');
      } else {
        // Sesión abierta pero sin ninguna sección activa/pausada — estado
        // inconsistente, mejor resetear que quedar a medias (activeSessionId
        // seteado sin activeSection nunca debe pasar).
        _resetState();
      }
    } catch (e) {
      _logError('RECOVERY_ERROR', e.toString());
      _resetState();
    }
  }

  static Future<bool> _hydrateSectionFromDb(String sectionId) async {
    try {
      final data = await Supabase.instance.client
          .from('session_sections')
          .select()
          .eq('id', sectionId)
          .maybeSingle();

      if (data == null || !['active', 'paused'].contains(data['section_status'])) {
        return false;
      }
      activeSection = SessionSection.fromMap(data);
      return true;
    } catch (e) {
      _logError('SECTION_HYDRATE_ERROR', e.toString());
      return false;
    }
  }

  /// Reconstruye `activeSection` sin ningún query a la DB, usando solo lo
  /// guardado en el checkpoint local. Campos que el checkpoint no guarda
  /// (coordenadas, odómetro, hash, irs_purpose) quedan null — se rellenan
  /// solos según avanza el viaje (ej. start_latitude en el próximo tick
  /// válido) o no son necesarios para seguir contando millas/tiempo, que es
  /// lo único crítico de recuperar en el momento.
  ///
  /// Devuelve false (sin tocar `activeSection`) si el checkpoint es de una
  /// versión anterior a este fix y le faltan campos, o algo no calza — en
  /// ese caso el llamador cae al respaldo por DB.
  static bool _hydrateSectionFromLocalCheckpoint(Map<String, dynamic> localState) {
    try {
      final sectionId = localState['sectionId'] as String?;
      final sessionId = localState['sessionId'] as String?;
      final userId = localState['userId'] as String?;
      final gigApp = localState['gigApp'] as String?;
      final startTimeStr = localState['sectionStartTime'] as String?;

      final hasAllFields = sectionId != null && sectionId.isNotEmpty &&
          sessionId != null && sessionId.isNotEmpty &&
          userId != null && userId.isNotEmpty &&
          gigApp != null && gigApp.isNotEmpty &&
          startTimeStr != null && startTimeStr.isNotEmpty;

      if (!hasAllFields) return false;

      activeSection = SessionSection(
        id: sectionId,
        sessionId: sessionId,
        userId: userId,
        gigApp: gigApp,
        status: (localState['isPaused'] == true) ? 'paused' : 'active',
        startTime: DateTime.parse(startTimeStr),
        totalMiles: (localState['totalSectionMiles'] as double?) ?? 0.0,
        // BUG FIX #3: sin esto, la base de duración confirmada se perdía en
        // cada recuperación 100% offline y el tiempo volvía a arrancar de
        // cero — exactamente el bug de "la pausa no sobrevive un reinicio".
        totalDurationSeconds: localState['sectionDurationSeconds'] as int?,
      );
      return true;
    } catch (e) {
      _logError('LOCAL_SECTION_HYDRATE_ERROR', e.toString());
      return false;
    }
  }

  static void _applyRecoveredCheckpointFields(Map<String, dynamic> localState) {
    activeSessionId = localState['sessionId'];
    _totalSessionMiles = localState['totalSessionMiles'] ?? 0.0;
    _totalSectionMiles = localState['totalSectionMiles'] ?? 0.0;
    currentGigApp = localState['gigApp'];
    currentState = (localState['isPaused'] == true)
        ? TrackingState.paused
        : TrackingState.running;

    // BUG FIX #3: el reloj de manejo activo se resetea a "ahora" al
    // recuperar — no hace falta reconstruir pausas históricas porque la
    // base (activeSection.totalDurationSeconds) ya viene descontada, tanto
    // si se hidrató localmente como desde la DB.
    _runSegmentStartedAt =
        currentState == TrackingState.running ? DateTime.now() : null;
  }

  // BUG FIX (hallazgo nuevo, encontrado al arreglar stopTracking): antes
  // devolvía Future<void> y tragaba su propia excepción -- stopTracking()
  // la llamaba sin chequear el resultado y seguía de largo marcando la
  // SESIÓN como cerrada aunque esta sección jamás se hubiera cerrado en
  // DB. Eso dejaba una sesión "closed" con una sección todavía
  // 'active'/'paused' adentro -- inconsistencia silenciosa que nunca se
  // hubiera notado en la UI. Ahora devuelve bool y stopTracking() aborta
  // si esto falla, en vez de seguir de largo.
  static Future<bool> endCurrentSection() async {
    if (activeSection == null) return true;

    try {
      // BUG FIX: total_duration_seconds nunca se guardaba aquí — solo se
      // guardaba al pausar. Una sección que nunca se pausó quedaba con 0
      // para siempre. Ahora se calcula igual que en pauseTracking.
      final elapsedSeconds = elapsedSectionDuration.inSeconds;

      // BUG FIX: end_latitude/end_longitude nunca se llenaban en el flujo
      // real (SectionTrackingService.finalizeSection sí lo hacía, pero es
      // código muerto que nada invoca). Usamos la última posición válida
      // que tiene el motor antifraude como coordenada de cierre.
      final endLat = AntifraudEngine.lastLat;
      final endLng = AntifraudEngine.lastLng;

      await Supabase.instance.client
          .from("session_sections")
          .update({
            "section_status": "closed",
            "end_time": DateTime.now().toUtc().toIso8601String(),
            "total_miles": _totalSectionMiles,
            "total_duration_seconds": elapsedSeconds,
            "end_latitude": endLat,
            "end_longitude": endLng,
          })
          .eq("id", activeSection!.id);

      activeSection = null;

      try {
        await LocalStorageService.clearAllCheckpoint();
      } catch (e) {
        _logError('SECTION_END_SIDE_EFFECT_ERROR', e.toString());
      }

      return true;
    } catch (e) {
      _logError('SECTION_END_ERROR', e.toString());
      return false;
    }
  }

  static Future<void> _smartSync(double score) async {
    final now = DateTime.now().toUtc();
    if (activeSection == null) return;

    if (now.difference(_lastDbUpdateTime).inSeconds >= 10) {
      _lastDbUpdateTime = now;
      await Supabase.instance.client
          .from("session_sections")
          .update({"total_miles": _totalSectionMiles})
          .eq("id", activeSection!.id);
    }

    if (now.difference(_lastAuditLogTime).inSeconds >= 30) {
      _lastAuditLogTime = now;
      await AuditService.logEvent(
        sessionId: activeSessionId!,
        sectionId: activeSection!.id,
        eventType: "GPS_TICK",
        payload: {"score": score, "miles": _totalSessionMiles},
      );
    }
  }

  static double _calculateHaversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static void _logDebug(String event, String message) =>
      debugPrint('[ControlMiles] $event: $message');

  static void _logError(String event, String message) =>
      debugPrint('[ControlMiles ERROR] $event: $message');
}