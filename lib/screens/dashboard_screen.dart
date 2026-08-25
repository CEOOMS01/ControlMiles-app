// Olympus Mont Systems LLC - ControlMiles
// lib/screens/dashboard_screen.dart
// PRODUCTION READY - UPDATED COLORS, SWITCH BANNER, AND CLOUD STATUS

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../tracking/tracking_controller.dart';
import '../models/gig_app.dart';
import '../models/vehicle.dart';
import '../models/vehicle_inspection.dart';
import '../routes/app_routes.dart';
import '../services/vehicle_service.dart';
import '../screens/vehicle_inspection_screen.dart';
import '../widgets/main_drawer.dart';
import '../widgets/mileage_deduction_badge.dart';
import '../widgets/tracking_action_button.dart';
import '../widgets/gig_app_selector.dart';
import '../logic/app_state.dart';
import '../utils/permission_recovery_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  bool loading = true;
  bool trackingActive = false;

  final SupabaseClient _supabase = Supabase.instance.client;

  Timer? _uiTimer;
  Timer? _switchBannerTimer;

  double liveMiles = 0.0;
  String _displayTime = "00:00:00";
  DateTime? _startTime;

  String? _selectedGigApp;
  // BUG FIX (irs_purpose nunca se guardaba): GigAppSelector ya soportaba un
  // callback dedicado (onCustomSelected) para Custom/Truck que entrega la
  // categoría IRS elegida en el bottom sheet, pero Dashboard nunca lo
  // conectaba — solo wireaba onAppSelected (que no recibe purpose). Cuando
  // el widget no encuentra onCustomSelected, cae a su fallback silencioso
  // (llama onAppSelected('custom') sin la categoría). Resultado confirmado
  // en DB: la única fila con gig_app='custom' tiene irs_purpose=null.
  String? _selectedIrsPurpose;
  String? _switchingFrom;
  String? _switchingTo;
  bool _showSwitchBanner = false;

  // BUG FIX (pedido explícito): el formulario de alta/baja de vehículo ya
  // no vive en ProfileScreen — se movió a su propia pantalla (VehicleScreen,
  // ver AppRoutes.vehicle). Dashboard solo muestra el vehículo activo en
  // modo lectura y navega ahí para cualquier cambio.
  Vehicle? _activeVehicle;
  bool _vehicleLoading = true;
  final VehicleService _vehicleService = VehicleService();

  // ── NUEVO: historial reciente ──
  List<Map<String, dynamic>> _recentSessions = [];
  Map<String, List<Map<String, dynamic>>> _recentSections = {};
  bool _historyLoading = true;
  Duration _pausedSectionDuration = Duration.zero;

  // ── NUEVO: card Summary (total del día) ──
  // BUG FIX (pedido explícito, batch de 4 bugs): NO reusa _recentSessions
  // para este total -- esa lista trae `.limit(5)` (es solo la vista previa
  // "Recent Trips"), así que sumarla subcontaría el total real de un día
  // con más de 5 viajes. Este es un fetch propio, sin límite, mismo patrón
  // que MileageDeductionBadge (trae solo total_miles/total_duration_seconds
  // del período y suma en cliente).
  double _todayMiles = 0.0;
  int _todayDurationSec = 0;
  bool _summaryLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDashboard();
    _setupRealTimeListeners();
    _loadActiveVehicle();
  }

  void _setupRealTimeListeners() {
    _syncTrackingUiState();

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _syncTrackingUiState();
    });
  }

  void _syncTrackingUiState() {
  final state = TrackingController.currentState;
  final active = TrackingController.activeSection;

  setState(() {
    trackingActive = state == TrackingState.running;
    liveMiles = TrackingController.activeDistance;

    if (TrackingController.currentGigApp != null) {
      _selectedGigApp = TrackingController.currentGigApp;
    }

    if (active != null) {
      _startTime = active.startTime;
      _displayTime = _formatDuration(TrackingController.elapsedSectionDuration);
    } else {
      _displayTime = '00:00:00';
      liveMiles = 0.0;
    }
  });
}

  // BUG FIX (irs_purpose): único punto que maneja selección de gig app,
  // tanto para apps normales (GigAppSelector.onAppSelected, sin purpose)
  // como para Custom/Truck (GigAppSelector.onCustomSelected, con purpose)
  // — evita tener dos copias de la lógica de switch-banner/switchSection.
  // irsPurpose solo aplica cuando appId == 'custom'; TrackingController ya
  // lo descarta server-side para cualquier otro gig_app (ver
  // startNewSection y el RPC switch_gig_app_section), así que no hace
  // falta filtrarlo acá también.
  // BUG FIX (pedido explícito, hallazgo secundario): antes esto actualizaba
  // _selectedGigApp y mostraba el banner "SWITCHED" de inmediato, ANTES de
  // saber si TrackingController.switchSection() (el RPC real) tuvo éxito
  // -- era fire-and-forget. Si el RPC fallaba (red, RLS), el banner ya
  // había mentido "SWITCHED" durante los 3 segundos completos, y el
  // estado real solo se autocorregía en el siguiente tick del timer de 1s
  // (_syncTrackingUiState). Ahora, para el caso con tracking corriendo
  // (el único donde de verdad hay un RPC de por medio), se espera la
  // confirmación real antes de tocar cualquier estado optimista.
  Future<void> _handleAppSelection(String appId, {String? irsPurpose}) async {
    if (_selectedGigApp == appId) return;

    final isLiveSwitch = TrackingController.currentState == TrackingState.running &&
        TrackingController.activeSessionId != null &&
        TrackingController.activeSection != null;

    if (!isLiveSwitch) {
      // Idle (o pausado, aunque un tap en pausa ya se bloquea antes de
      // llegar acá -- ver GigAppSelector.isPaused): pura selección local,
      // no hay ningún RPC que confirmar.
      final previousGigApp = _selectedGigApp;
      setState(() {
        _switchingFrom      = previousGigApp;
        _switchingTo        = appId;
        _showSwitchBanner   = true;
        _selectedGigApp     = appId;
        _selectedIrsPurpose = irsPurpose;
      });
      _armSwitchBannerTimer();
      return;
    }

    final previousGigApp = _selectedGigApp;
    final success = await TrackingController.switchSection(appId, irsPurpose: irsPurpose);
    if (!mounted) return;

    if (success) {
      setState(() {
        _switchingFrom      = previousGigApp;
        _switchingTo        = appId;
        _showSwitchBanner   = true;
        _selectedGigApp     = appId;
        _selectedIrsPurpose = irsPurpose;
      });
      _armSwitchBannerTimer();
    } else {
      // _selectedGigApp NUNCA se toca acá -- sigue reflejando la app que
      // TrackingController de verdad sigue trackeando.
      final appState = Provider.of<AppState>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appState.tr('switch_activity_failed') ??
                'Could not switch activity, still tracking the previous one',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _armSwitchBannerTimer() {
    _switchBannerTimer?.cancel();
    _switchBannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showSwitchBanner = false);
    });
  }

  Widget _buildSwitchAppBanner() {
    if (!_showSwitchBanner) return const SizedBox.shrink();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: _showSwitchBanner ? 1.0 : 0.0,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_switchingFrom?.toUpperCase() ?? "IDLE",
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.swap_horiz, color: Colors.blueAccent),
            ),
            Text(_switchingTo?.toUpperCase() ?? "",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            const Text("SWITCHED",
                style: TextStyle(color: Color(0xFF4ADE80), fontSize: 10, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}";
  }

  String _formatDurationFromSeconds(int seconds) {
    return _formatDuration(Duration(seconds: seconds));
  }

  // BUG FIX (pedido explícito): saludo del AppBar, hora local del
  // dispositivo (misma fuente que ya usa RECENT TRIPS para el corte de
  // medianoche, no UTC). firstName puede ser null (perfil sin nombre
  // cargado) -- en ese caso el saludo se muestra solo, sin nombre vacío.
  String _buildGreeting(AppState appState) {
    final hour = DateTime.now().hour;
    final String greetingKey;
    if (hour >= 5 && hour < 12) {
      greetingKey = 'greeting_morning';
    } else if (hour >= 12 && hour < 19) {
      greetingKey = 'greeting_afternoon';
    } else {
      greetingKey = 'greeting_evening';
    }
    final greeting = appState.tr(greetingKey);
    final firstName = appState.firstName;
    return (firstName != null && firstName.trim().isNotEmpty)
        ? '$greeting! $firstName'
        : '$greeting!';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiTimer?.cancel();
    _switchBannerTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed) return;
    try {
      final permissionsOk = await PermissionRecoveryService.hasCriticalPermissions();
      if (!permissionsOk && mounted) {
        await PermissionRecoveryService.showRecoveryDialog(context);
      }
      await _loadActiveVehicle();
      _syncTrackingUiState();
    } catch (e) {
      debugPrint("[ControlMiles Permission Check Error] $e");
    }
  }

  Future<void> _initDashboard() async {
    setState(() => loading = true);
    await TrackingController.initializeOrRecover();
    await _loadRecentSessions(); // ── NUEVO
    await _loadTodaySummary(); // ── NUEVO
    if (mounted) {
      _syncTrackingUiState();
      setState(() => loading = false);
    }
  }

  // ── NUEVO: total del día para la card Summary ──
  Future<void> _loadTodaySummary() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _summaryLoading = false);
        return;
      }

      final nowLocal = DateTime.now();
      final todayMidnightLocal =
          DateTime(nowLocal.year, nowLocal.month, nowLocal.day, 0, 0, 0);
      final windowStartUtc = todayMidnightLocal.toUtc();

      final rows = await _supabase
          .from('sessions')
          .select('total_miles, total_duration_seconds')
          .eq('user_id', user.id)
          .eq('is_closed', true)
          .gte('start_time', windowStartUtc.toIso8601String());

      final list = List<Map<String, dynamic>>.from(rows);
      final miles = list.fold<double>(
          0.0, (acc, r) => acc + ((r['total_miles'] as num?)?.toDouble() ?? 0.0));
      final durationSec = list.fold<int>(
          0, (acc, r) => acc + ((r['total_duration_seconds'] as int?) ?? 0));

      if (mounted) {
        setState(() {
          _todayMiles = miles;
          _todayDurationSec = durationSec;
          _summaryLoading = false;
        });
      }
    } catch (e) {
      debugPrint("[ControlMiles Today Summary Load Error] $e");
      if (mounted) setState(() => _summaryLoading = false);
    }
  }

  Future<void> _loadActiveVehicle() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() { _activeVehicle = null; _vehicleLoading = false; });
        return;
      }
      // BUG FIX: antes tomaba "el más reciente creado" como proxy de
      // "activo" (vehicles.is_active/is_primary existían en la DB pero
      // nadie los leía ni escribía). Ahora usa el flag real, gestionado
      // desde Profile vía VehicleService.
      //
      // Fleet Phase 3: para un fleet_driver, "el vehículo activo" es el que
      // su admin le asignó, no uno propio -- getActiveOrAssignedVehicle()
      // es el único punto de esta rama (ver su comentario en
      // VehicleService), el mismo que usa tracking_controller.dart al
      // arrancar un viaje.
      final appState = context.read<AppState>();
      final vehicle = await _vehicleService.getActiveOrAssignedVehicle(
        user.id,
        organizationId: appState.isFleetDriver ? appState.defaultOrgId : null,
      );
      if (!mounted) return;
      setState(() {
        _activeVehicle = vehicle;
        _vehicleLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _vehicleLoading = false);
    }
  }

  // ── NUEVO: carga las últimas 5 sesiones cerradas con sus secciones ──
  // BUG FIX (pedido explícito, corregido): RECENT TRIPS muestra los viajes
  // de las últimas 24h, reiniciando en la medianoche (12am) local — no
  // desde las 12pm. El corte anterior (mediodía) excluía por diseño
  // cualquier viaje hecho en la mañana (12am-11:59am), que es exactamente
  // lo que se reportó como "el historial no se actualiza". Se recalcula en
  // cada carga/pull-to-refresh con la hora local del dispositivo — no hace
  // falta timer/motor.
  Future<void> _loadRecentSessions() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final nowLocal = DateTime.now();
      final todayMidnightLocal =
          DateTime(nowLocal.year, nowLocal.month, nowLocal.day, 0, 0, 0);
      final windowStartUtc = todayMidnightLocal.toUtc();

      final sessionsData = await _supabase
          .from('sessions')
          .select()
          .eq('user_id', user.id)
          .eq('is_closed', true)
          .gte('start_time', windowStartUtc.toIso8601String())
          .order('start_time', ascending: false)
          .limit(5);

      final sessions = List<Map<String, dynamic>>.from(sessionsData);
      final sectionsMap = <String, List<Map<String, dynamic>>>{};

      for (final session in sessions) {
        final sectionsData = await _supabase
            .from('session_sections')
            .select()
            .eq('session_id', session['id'])
            .order('start_time', ascending: true);

        sectionsMap[session['id']] =
            List<Map<String, dynamic>>.from(sectionsData);
      }

      if (mounted) {
        setState(() {
          _recentSessions = sessions;
          _recentSections = sectionsMap;
          _historyLoading = false;
        });
      }
    } catch (e) {
      debugPrint("[ControlMiles History Load Error] $e");
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  // BUG FIX (pedido explícito): _addVehicle/_showAddVehicleSheet/
  // _buildVehicleField eliminados — el alta/edición/borrado de vehículo
  // vive únicamente en ProfileScreen (VehicleService como única fuente de
  // verdad). Dashboard solo muestra el vehículo activo y navega a Profile
  // para cualquier cambio (ver _buildVehicleCard).

  // BUG FIX (consolidación pedida explícitamente): este catálogo vivía
  // duplicado a mano en 4 archivos — ver lib/models/gig_app.dart, ahora
  // fuente única de verdad.
  GigApp _getAppMeta(String appId) => GigAppCatalog.byId(appId);

  // ── NUEVO: widget de historial reciente ──
  Widget _buildRecentSessionsHistory(AppState appState, bool isDark) {
    final cardBg     = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final labelColor  = isDark ? Colors.white38 : const Color(0xFF94A3B8);
    final textColor   = isDark ? Colors.white : const Color(0xFF1E293B);
    final dateFormat  = DateFormat('MM/dd · hh:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Encabezado de sección ──
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT TRIPS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: labelColor,
                ),
              ),
              if (_recentSessions.isNotEmpty)
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/history'),
                  child: Text(
                    'SEE ALL →',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── NUEVO: card Summary (total del día, pedido explícito) ──
        _buildSummaryCard(appState, cardBg, borderColor, labelColor, textColor),
        const SizedBox(height: 14),

        if (_historyLoading)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: CircularProgressIndicator(strokeWidth: 2),
          ))
        else if (_recentSessions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Icon(Icons.history_rounded, size: 32, color: labelColor),
                const SizedBox(height: 8),
                Text(
                  'No trips yet',
                  style: TextStyle(fontSize: 13, color: labelColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else
          ...(_recentSessions.map((session) {
            final sessionId   = session['id'] as String;
            final sections    = _recentSections[sessionId] ?? [];
            final startTime   = session['start_time'] != null
                ? DateTime.parse(session['start_time']).toLocal()
                : null;
            final endTime     = session['end_time'] != null
                ? DateTime.parse(session['end_time']).toLocal()
                : null;
            final totalMiles  = (session['total_miles'] ?? 0.0) as num;
            // BUG FIX: total_duration_seconds is now persisted correctly
            // (pause-excluded) by TrackingController.stopTracking(), but
            // sessions closed before that fix are stuck at 0 despite having
            // a real trip length. Treat 0 as "not set" and fall back to the
            // raw start→end difference for those legacy rows.
            final storedDurationSec = (session['total_duration_seconds'] as int?) ?? 0;
            final durationSec = storedDurationSec > 0
                ? storedDurationSec
                : (endTime != null && startTime != null
                    ? endTime.difference(startTime).inSeconds
                    : 0);

            final displayMiles = appState.useMetricSystem
                ? (totalMiles * 1.60934).toStringAsFixed(2)
                : totalMiles.toStringAsFixed(2);
            final unitLabel = appState.useMetricSystem
                ? appState.tr('kilometer_short')
                : appState.tr('mile_short');

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: isDark ? [] : [
                  BoxShadow(color: Colors.black.withOpacity(0.04),
                      blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [

                  // ── Fila superior: fecha / duración / millas ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [

                        // Fecha y hora de inicio
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                startTime != null
                                    ? dateFormat.format(startTime)
                                    : '---',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              if (endTime != null)
                                Text(
                                  'End: ${DateFormat('hh:mm a').format(endTime)}',
                                  style: TextStyle(fontSize: 11, color: labelColor),
                                ),
                            ],
                          ),
                        ),

                        // Duración
                        _buildSessionInfoChip(
                          icon: Icons.timer_outlined,
                          value: _formatDurationFromSeconds(durationSec),
                          isDark: isDark,
                        ),

                        const SizedBox(width: 8),

                        // Millas
                        _buildSessionInfoChip(
                          icon: Icons.speed_rounded,
                          value: '$displayMiles $unitLabel',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  // ── Divisor ──
                  if (sections.isNotEmpty)
                    Divider(height: 1, color: borderColor),

                  // ── Secciones (chips de gig apps) ──
                  if (sections.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: sections.map((section) {
                          final gigApp  = section['gig_app'] as String? ?? 'custom';
                          final meta    = _getAppMeta(gigApp);
                          final appColor = meta.color;
                          final secMiles = (section['total_miles'] ?? 0.0) as num;
                          final secStart = section['start_time'] != null
                              ? DateTime.parse(section['start_time']).toLocal()
                              : null;
                          final secEnd = section['end_time'] != null
                              ? DateTime.parse(section['end_time']).toLocal()
                              : null;
                          final secDur = secEnd != null && secStart != null
                              ? secEnd.difference(secStart).inMinutes
                              : 0;

                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: appColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: appColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(meta.icon,
                                    size: 13, color: appColor),
                                const SizedBox(width: 5),
                                Text(
                                  meta.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: appColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${secMiles.toStringAsFixed(1)} mi · ${secDur}m',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: appColor.withOpacity(0.75),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            );
          }).toList()),
      ],
    );
  }

  // ── NUEVO: card Summary (pedido explícito, batch de 4 bugs) ──
  // Reemplaza el pedido original de "desglose en vivo por app" -- el
  // usuario redirigió el pedido a esto: un total del DÍA CALENDARIO (no
  // del rango seleccionado en ningún filtro), mismo dato/misma card en
  // Dashboard y Reports. Ver _loadTodaySummary().
  Widget _buildSummaryCard(AppState appState, Color cardBg, Color borderColor,
      Color labelColor, Color textColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayMiles = appState.useMetricSystem
        ? (_todayMiles * 1.60934).toStringAsFixed(2)
        : _todayMiles.toStringAsFixed(2);
    final unitLabel = appState.useMetricSystem
        ? appState.tr('kilometer_short')
        : appState.tr('mile_short');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Text(
              appState.tr('summary').toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: labelColor,
              ),
            ),
          ),
          Divider(height: 1, color: borderColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            // BUG FIX (pedido explícito): las millas y el tiempo del día
            // estaban "flotando" -- ícono y texto sueltos en un Row, sin
            // caja propia. Ahora cada contador vive en su propio cuadrito
            // (mismo chip que ya usa _buildSessionInfoChip en esta pantalla).
            child: _summaryLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Row(
                    children: [
                      _buildSessionInfoChip(
                        icon: Icons.speed_rounded,
                        value: '$displayMiles $unitLabel',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildSessionInfoChip(
                        icon: Icons.timer_outlined,
                        value: _formatDurationFromSeconds(_todayDurationSec),
                        isDark: isDark,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfoChip({
    required IconData icon,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Color get borderColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  }

  @override
  Widget build(BuildContext context) {
    final appState  = Provider.of<AppState>(context);
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    final cardBg    = isDark ? const Color(0xFF0F172A) : Colors.white;
    final bColor    = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    final displayValue = appState.useMetricSystem
        ? (liveMiles * 1.60934).toStringAsFixed(2)
        : liveMiles.toStringAsFixed(2);
    final unitLabel = appState.useMetricSystem
        ? appState.tr('kilometer_short')
        : appState.tr('mile_short');

    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: scaffoldBg,
      drawer: const MainDrawer(),
      bottomNavigationBar: _buildBottomButtons(isDark, appState),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        title: Text(
          appState.tr('app_name'),
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 15),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.primary),
              ),
              // BUG FIX (pedido explícito): reemplaza el badge "IRS 2026 ·
              // X¢/mi" (número ya vive en MileageDeductionBadge más abajo,
              // detrás del disclaimer completo) por un saludo dinámico
              // según la hora del dispositivo + nombre real del usuario.
              // firstName sale de AppState (ver fetchUserProfile), NO de
              // un fetch propio de esta pantalla, para no reabrir el bug
              // de caché cruzado entre cuentas ya resuelto ahí.
              child: Text(
                _buildGreeting(appState),
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _initDashboard();
          await _loadActiveVehicle();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // BUG FIX (pedido explícito): reemplaza el badge "StandardCM"
              // (Cloud Sync) — estaba roto, pegaba a una tabla/columna que
              // no existen en la DB real, así que siempre mostraba
              // "offline" sin importar la conexión real (ver
              // CloudStatusService, ya no se usa acá). Ahora muestra millas
              // del año + estimado de deducción IRS, con el disclaimer
              // completo detrás de un tap (ver MileageDeductionBadge).
              const MileageDeductionBadge(),

              _buildSwitchAppBanner(),

              const SizedBox(height: 20),

              _vehicleLoading
                  ? const CircularProgressIndicator()
                  : _buildVehicleCard(
                      appState: appState,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: bColor,
                    ),

              const SizedBox(height: 20),

              // BUG FIX (pedido explícito): antes eran dos cajas separadas
              // (Expanded + SizedBox(width:12) + Expanded) -- ahora es UNA
              // sola caja/cuadro con las dos estadísticas separadas
              // adentro por un divisor vertical, no dos contenedores.
              _buildStatsBox(
                appState: appState,
                value1: displayValue,
                label1: unitLabel,
                icon1: Icons.speed,
                value2: _displayTime,
                label2: appState.tr('duration'),
                icon2: Icons.timer,
              ),

              const SizedBox(height: 30),

              GigAppSelector(
                selectedGigApp: _selectedGigApp,
                activeGigApp: TrackingController.currentGigApp,
                isPaused: TrackingController.isPaused,
                onAppSelected: (appId) => _handleAppSelection(appId),
                onCustomSelected: (appId, irsPurpose) =>
                    _handleAppSelection(appId, irsPurpose: irsPurpose),
              ),

              const SizedBox(height: 30),

              TrackingActionButton(
                selectedGigApp: _selectedGigApp,
                selectedIrsPurpose: _selectedIrsPurpose,
                // BUG FIX (dashboard no se refrescaba tras terminar un
                // viaje): antes solo se recargaba en initState() o
                // pull-to-refresh manual. También recarga el total del día
                // (card Summary) -- terminar un viaje lo cambia.
                onTripEnded: () {
                  _loadRecentSessions();
                  _loadTodaySummary();
                },
              ),

              const SizedBox(height: 40),

              if (TrackingController.activeSection != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${appState.tr('tracking_active').toUpperCase()}: ${TrackingController.activeSection?.gigApp.toUpperCase()}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ),

              const SizedBox(height: 30),

              // ── NUEVO: historial reciente debajo del botón ──
              _buildRecentSessionsHistory(appState, isDark),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // BUG FIX (pedido explícito): antes el ícono de lápiz no tenía onTap (era
  // decorativo, no hacía nada) y "add_vehicle" abría un formulario propio
  // de Dashboard duplicado del de Profile. La gestión de vehículo se movió
  // de Profile a su propia pantalla (VehicleScreen) — toda la tarjeta
  // navega ahí, y al volver se refresca el vehículo activo en tiempo real
  // (por si se agregó, archivó o cambió cuál está activo).
  Future<void> _goToVehicleProfile() async {
    await Navigator.pushNamed(context, AppRoutes.vehicle);
    if (mounted) _loadActiveVehicle();
  }

  Widget _buildVehicleCard({
    required AppState appState,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    // BUG FIX (pedido explícito, "Full-width Divider"): la card de vehículo
    // no tenía separación entre título y contenido -- ahora sigue el mismo
    // patrón que las demás cards del Dashboard: header (ícono + label) +
    // Divider de borde a borde + contenido.
    // BUG FIX (build error, olvido al escribir el header): 'labelColor' no
    // es un campo de la clase -- cada método que lo usa lo calcula local a
    // partir de isDark (mismo criterio que _buildRecentSessionsHistory).
    final labelColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);
    final headerRow = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          Icon(Icons.directions_car_outlined,
              size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            appState.tr('vehicle').toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: labelColor,
            ),
          ),
        ],
      ),
    );

    // Fleet Phase 3: a fleet_driver's vehicle comes from their admin
    // (assigned_driver_id), not from AppRoutes.vehicle (VehicleScreen is
    // owner_user_id CRUD -- a driver can't add/edit/delete an org vehicle
    // there, so sending them to it on tap would be a dead end). No new
    // "fleet vehicle detail" screen is built this pass -- the card is
    // simply non-interactive for a fleet driver, and its empty state
    // explains WHY there's nothing to tap instead of inviting an action
    // that doesn't apply to them.
    final isFleetDriver = appState.isFleetDriver;

    if (_activeVehicle == null) {
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: isFleetDriver ? null : _goToVehicleProfile,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerRow,
              Divider(height: 1, color: borderColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: isFleetDriver
                    ? Text(appState.tr('fleet_no_vehicle_assigned'))
                    : Row(
                        children: [
                          Expanded(
                            child: Text(appState.tr('add_vehicle_prompt') ??
                                appState.tr('add_vehicle')),
                          ),
                          TextButton(
                            onPressed: _goToVehicleProfile,
                            child: Text(appState.tr('add_vehicle').toUpperCase()),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: isFleetDriver ? null : _goToVehicleProfile,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            headerRow,
            Divider(height: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle),
                    child: const Icon(Icons.directions_car_filled_rounded,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    // Marca del vehículo activo (ej. Toyota, Nissan) + modelo.
                    child: Text(
                      _activeVehicle!.displayName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (!isFleetDriver)
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8)),
                ],
              ),
            ),
            // Fleet Phase 4: DVIR-style pre/post-trip inspection, only
            // relevant for a fleet driver's assigned vehicle -- a Gig
            // owner's personal vehicle has no fleet admin to report to, so
            // there's no one for a checklist submission to be visible to.
            if (isFleetDriver) ...[
              Divider(height: 1, color: borderColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _startInspection(_activeVehicle!),
                    icon: const Icon(Icons.checklist_rounded, size: 18),
                    label: Text(appState.tr('inspection_start').toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startInspection(Vehicle vehicle) async {
    final result = await Navigator.push<VehicleInspection>(
      context,
      MaterialPageRoute(builder: (_) => VehicleInspectionScreen(vehicle: vehicle)),
    );
    if (result == null || !mounted) return;

    final appState = context.read<AppState>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.isPass
            ? appState.tr('inspection_result_pass')
            : appState.tr('inspection_result_fail')),
        backgroundColor: result.isPass ? Colors.green.shade600 : Colors.orange.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildBottomButtons(bool isDark, AppState appState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/history'),
              icon: const Icon(Icons.history),
              label: Text(appState.tr('history').toUpperCase()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/reports'),
              icon: const Icon(Icons.fact_check),
              label: Text(appState.tr('reports').toUpperCase()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // BUG FIX (pedido explícito): MI y DURATION vivían en dos Container
  // (Expanded) separados por un SizedBox -- ahora es una sola caja con
  // gradiente (mismo azul de marca migrado en la tarea anterior) y un
  // divisor vertical adentro que separa visualmente las dos estadísticas
  // sin partir la caja en dos.
  Widget _buildStatsBox({
    required AppState appState,
    required String value1,
    required String label1,
    required IconData icon1,
    required String value2,
    required String label2,
    required IconData icon2,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, Color.lerp(primary, Colors.black, 0.25)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          // BUG FIX (pedido explícito, "Full-width Divider"): esta card no
          // tenía título, solo dos mitades separadas por una línea vertical
          // corta -- se le agregó un header + un divisor horizontal de
          // borde a borde arriba, mismo patrón que Vehicle/Summary/carrusel.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.timeline_rounded, size: 14, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  appState.tr('current_trip').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(child: _buildStatHalf(value1, label1, icon1)),
                Container(width: 1, height: 40, color: Colors.white24),
                Expanded(child: _buildStatHalf(value2, label2, icon2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatHalf(String value, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }
}