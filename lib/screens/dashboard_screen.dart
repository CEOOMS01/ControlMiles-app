// Olympus Mont Systems LLC - ControlMiles
// lib/screens/dashboard_screen.dart
// PRODUCTION READY - UPDATED COLORS, SWITCH BANNER, AND CLOUD STATUS

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../tracking/tracking_controller.dart';
import '../tracking/auto_trip_detection_service.dart';
import '../models/gig_app.dart';
import '../models/vehicle.dart';
import '../models/vehicle_inspection.dart';
import '../routes/app_routes.dart';
import '../services/vehicle_service.dart';
import '../screens/vehicle_inspection_screen.dart';
import '../screens/trip_route_map_screen.dart';
import '../data/irs_rates.dart';
import '../widgets/full_bleed.dart';
import '../widgets/cm_card_header.dart';
import '../widgets/driver_live_map_view.dart';
import '../widgets/main_drawer.dart';
import '../widgets/tracking_action_button.dart';
import '../widgets/gig_app_selector.dart';
import '../widgets/auto_detect_apps_button.dart';
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

  // ── NUEVO: total del MES calendario en curso, reemplaza MileageDeductionBadge
  // (que era total del año) -- pedido explícito: "total miles de cada mes,
  // no global". Mismo patrón que _todayMiles pero con el piso en el día 1
  // del mes local en vez de la medianoche de hoy -- se resetea solo el
  // día 1 de cada mes. Trae start_time (no solo total_miles/duration) igual
  // que MileageDeductionBadge lo hacía para el año, porque el estimado IRS
  // se calcula viaje por viaje (la tarifa cambia a mitad de año, ver
  // irs_rates.dart) -- sumar millas primero y aplicar una tarifa única al
  // total daría un estimado incorrecto para meses que cruzan el cambio de
  // tarifa.
  double _monthMiles = 0.0;
  // Header (2026-10-09): miles closed this week / month / year (Profile).
  double _headerMiles = 0.0;
  String? _headerMilesLoadedFor;
  int _monthDurationSec = 0;
  double _monthDeduction = 0.0;
  bool _monthLoading = true;

  // Auto-detect start/stop flash (explicit user request, 2026-09-08):
  // consumes TrackingController.autoFlashEvent ('start'/'end'), plays a
  // brief colored fade over the tracking button/status card area, then
  // resets both this local state and the notifier's value -- same
  // one-shot "consume and clear" shape as _showSwitchBanner just above.
  Color? _autoFlashColor;
  Timer? _autoFlashTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDashboard();
    _setupRealTimeListeners();
    _loadActiveVehicle();
    TrackingController.autoFlashEvent.addListener(_onAutoFlashEvent);
    TrackingController.segmentDiscarded.addListener(_onSegmentDiscarded);
  }

  // A segment with no miles was removed from the trip (at a switch, manual
  // or auto-detect, or as the last segment at End Trip): same notice as a
  // discarded trip, naming the gig app (2026-10-01).
  void _onSegmentDiscarded() {
    final app = TrackingController.segmentDiscarded.value;
    if (app == null || !mounted) return;
    TrackingController.segmentDiscarded.value = null;
    final appState = context.read<AppState>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${app.toUpperCase()}: ${appState.tr('trip_discarded_no_miles')}')),
    );
    _loadRecentSessions();
  }

  void _onAutoFlashEvent() {
    final event = TrackingController.autoFlashEvent.value;
    if (event == null || !mounted) return;
    TrackingController.autoFlashEvent.value = null;

    _autoFlashTimer?.cancel();
    setState(() {
      _autoFlashColor = event == 'start'
          ? Theme.of(context).colorScheme.primary
          : Colors.red.shade700;
    });
    _autoFlashTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _autoFlashColor = null);
    });
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
  final newGigApp = TrackingController.currentGigApp;

  // Real gap found (pedido explícito: confirmación visible en tiempo
  // real del switch detectado): AutoTripDetectionService's mid-trip
  // auto-switch (_pollForMidTripSwitch, always silent) calls
  // TrackingController.switchSection() directly, bypassing
  // _handleAppSelection entirely -- the only place that already shows
  // the "X ⇄ Y SWITCHED" banner for a MANUAL carousel tap. A driver
  // looking at the app when an auto-switch happens only ever saw the
  // Android system notification (easy to miss/dismiss) or the status
  // card silently updating with no flash. This catches any
  // currentGigApp change this screen didn't cause itself -- a manual
  // tap already updates _selectedGigApp synchronously in
  // _handleAppSelection, so by the next 1s tick they already match;
  // only an EXTERNAL change (an auto-switch) differs here -- and shows
  // the exact same banner, reused as-is rather than inventing new UI.
  final autoSwitchDetected = newGigApp != null &&
      _selectedGigApp != null &&
      newGigApp != _selectedGigApp;

  setState(() {
    trackingActive = state == TrackingState.running;
    liveMiles = TrackingController.activeDistance;

    if (autoSwitchDetected) {
      _switchingFrom    = _selectedGigApp;
      _switchingTo      = newGigApp;
      _showSwitchBanner = true;
    }

    if (newGigApp != null) {
      _selectedGigApp = newGigApp;
    }

    if (active != null) {
      _displayTime = _formatDuration(TrackingController.elapsedSectionDuration);
    } else {
      _displayTime = '00:00:00';
      liveMiles = 0.0;
    }
  });

  if (autoSwitchDetected) _armSwitchBannerTimer();
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
            appState.tr('switch_activity_failed'),
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
    final appState = Provider.of<AppState>(context, listen: false);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: _showSwitchBanner ? 1.0 : 0.0,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2E281F),
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
            Text(appState.tr('switched_label'),
                style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 10, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  // Replaces the GigAppSelector carousel while idle + auto-detect is
  // armed (see the call site's own comment). Reads
  // AutoTripDetectionService's lastDetectedGigAppId directly -- no
  // ValueListenableBuilder needed, this screen already rebuilds every
  // second via _uiTimer/_syncTrackingUiState, the same existing cadence
  // TrackingController.currentGigApp/isPaused are already read through
  // a few lines above this call site.
  Widget _buildAutoDetectStatusCard(AppState appState, bool isDark) {
    final trackingState = TrackingController.currentState;
    if (trackingState == TrackingState.idle) {
      return _buildAutoDetectIdleCard(appState, isDark);
    }
    return _buildAutoDetectTrackingCard(appState, isDark, isPaused: trackingState == TrackingState.paused);
  }

  Widget _buildAutoDetectIdleCard(AppState appState, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1C1812) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E281F) : const Color(0xFFE3D9C4);
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final subTextColor = isDark ? Colors.white54 : const Color(0xFF6B6250);
    final primary = Theme.of(context).colorScheme.primary;

    final detectedId = AutoTripDetectionService.instance.lastDetectedGigAppId;
    final detectedApp = detectedId != null ? GigAppCatalog.byId(detectedId) : null;
    final accent = detectedApp?.color ?? primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: kPageGutter, vertical: 18),
      decoration: fullBleedCard(
        color: cardBg,
        border: borderColor,
        accentBorder: detectedApp != null ? accent : null,
        accentWidth: 2,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(detectedApp?.icon ?? Icons.auto_awesome_rounded, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detectedApp != null
                      ? '${appState.tr('auto_detect_status_found_label')} ${detectedApp.name}'
                      : appState.tr('auto_detect_status_listening'),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  detectedApp != null
                      ? appState.tr('auto_detect_status_found_subtitle')
                      : appState.tr('auto_detect_status_listening_subtitle'),
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Explicit user follow-up request: the carousel's OTHER job -- mid-trip
  // app switching -- is now also auto-detect's responsibility while
  // armed, so this replaces it here too instead of handing back to
  // GigAppSelector. REVISED 2026-08-28: mid-trip switching is always
  // silent now (no more "ask" mode/tappable suggestion, see
  // AutoTripDetectionService._pollForMidTripSwitch) -- this card only
  // ever quietly shows what's currently being tracked.
  Widget _buildAutoDetectTrackingCard(AppState appState, bool isDark, {required bool isPaused}) {
    final cardBg = isDark ? const Color(0xFF1C1812) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E281F) : const Color(0xFFE3D9C4);
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final subTextColor = isDark ? Colors.white54 : const Color(0xFF6B6250);
    final primary = Theme.of(context).colorScheme.primary;

    final currentApp = TrackingController.currentGigApp != null
        ? GigAppCatalog.byId(TrackingController.currentGigApp!)
        : null;
    final accent = currentApp?.color ?? primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: kPageGutter, vertical: 18),
      decoration: fullBleedCard(color: cardBg, border: borderColor),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(currentApp?.icon ?? Icons.auto_awesome_rounded, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${appState.tr('auto_detect_tracking_with_label')} ${currentApp?.name ?? ''}',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  appState.tr(isPaused ? 'auto_detect_tracking_paused_subtitle' : 'auto_detect_tracking_subtitle'),
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
              ],
            ),
          ),
        ],
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
  bool get _isDaytime {
    final hour = DateTime.now().hour;
    return hour >= 6 && hour < 19;
  }

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
        ? '$greeting, $firstName'
        : greeting;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiTimer?.cancel();
    _switchBannerTimer?.cancel();
    _autoFlashTimer?.cancel();
    TrackingController.autoFlashEvent.removeListener(_onAutoFlashEvent);
    TrackingController.segmentDiscarded.removeListener(_onSegmentDiscarded);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed) return;
    try {
      final permissionsOk = await PermissionRecoveryService.hasCriticalPermissions();
      if (!permissionsOk && mounted) {
        // Limitado a propósito: esto salta en CADA vuelta a la app, no
        // porque el usuario haya pedido nada. Ver
        // showRecoveryDialogThrottled. Las comprobaciones al iniciar viaje
        // o al armar auto-detect siguen siendo inmediatas y sin límite.
        await PermissionRecoveryService.showRecoveryDialogThrottled(context);
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
    await _loadMonthSummary(); // ── NUEVO
    await _loadHeaderMiles();
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
          // Personal trips only: fleet trips live in ControlMiles Fleet.
          .isFilter('organization_id', null)
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

  // Header (2026-10-09): miles so far this week (Monday 00:00), month or year,
  // local time -- the period is chosen in Profile.
  Future<void> _loadHeaderMiles() async {
    final period = context.read<AppState>().headerMilesPeriod;
    _headerMilesLoadedFor = period;
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final from = switch (period) {
        'month' => DateTime(now.year, now.month, 1),
        'year' => DateTime(now.year, 1, 1),
        _ => today.subtract(Duration(days: now.weekday - 1)),
      };
      final rows = await _supabase
          .from('sessions')
          .select('total_miles')
          .eq('user_id', user.id)
          // Personal trips only: fleet trips live in ControlMiles Fleet.
          .isFilter('organization_id', null)
          .eq('is_closed', true)
          .gte('start_time', from.toUtc().toIso8601String());
      final miles = List<Map<String, dynamic>>.from(rows)
          .fold<double>(0.0, (acc, r) => acc + ((r['total_miles'] as num?)?.toDouble() ?? 0.0));
      if (mounted) setState(() => _headerMiles = miles);
    } catch (e) {
      debugPrint("[ControlMiles Header Miles Load Error] $e");
    }
  }

  // ── NUEVO: total del mes calendario en curso para la card Summary ──
  Future<void> _loadMonthSummary() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _monthLoading = false);
        return;
      }

      final nowLocal = DateTime.now();
      final monthStartLocal = DateTime(nowLocal.year, nowLocal.month, 1);
      final windowStartUtc = monthStartLocal.toUtc();

      final rows = await _supabase
          .from('sessions')
          .select('total_miles, total_duration_seconds, start_time')
          .eq('user_id', user.id)
          // Personal trips only: fleet trips live in ControlMiles Fleet.
          .isFilter('organization_id', null)
          .eq('is_closed', true)
          .gte('start_time', windowStartUtc.toIso8601String());

      final list = List<Map<String, dynamic>>.from(rows);
      double milesSum = 0.0;
      int durationSum = 0;
      double deductionSum = 0.0;
      for (final r in list) {
        final miles = (r['total_miles'] as num?)?.toDouble() ?? 0.0;
        final startTime = DateTime.tryParse(r['start_time'] as String? ?? '');
        milesSum += miles;
        durationSum += (r['total_duration_seconds'] as int?) ?? 0;
        deductionSum += calculateIrsDeductionEstimate(miles, startTime ?? nowLocal);
      }

      if (mounted) {
        setState(() {
          _monthMiles = milesSum;
          _monthDurationSec = durationSum;
          _monthDeduction = deductionSum;
          _monthLoading = false;
        });
      }
    } catch (e) {
      debugPrint("[ControlMiles Month Summary Load Error] $e");
      if (mounted) setState(() => _monthLoading = false);
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
          // Personal trips only: fleet trips live in ControlMiles Fleet.
          .isFilter('organization_id', null)
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
    final cardBg     = isDark ? const Color(0xFF1C1812) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E281F) : const Color(0xFFE3D9C4);
    final labelColor  = isDark ? Colors.white38 : const Color(0xFFA39A86);
    final textColor   = isDark ? Colors.white : const Color(0xFF2E281F);
    final dateFormat  = DateFormat('MM/dd · hh:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            padding: const EdgeInsets.all(kPageGutter),
            decoration: fullBleedCard(color: cardBg, border: borderColor),
            child: Column(
              children: [
                Icon(Icons.history_rounded, size: 32, color: labelColor),
                const SizedBox(height: 8),
                Text(
                  appState.tr('no_trips_yet'),
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
              margin: const EdgeInsets.only(bottom: 12),
              decoration: fullBleedCard(color: cardBg, border: borderColor),
              child: Column(
                children: [

                  // ── Fila superior: fecha / duración / millas ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(kPageGutter, 14, kPageGutter, 10),
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
                      padding: const EdgeInsets.fromLTRB(kPageGutter, 10, kPageGutter, 12),
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
                              color: appColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: appColor.withValues(alpha: 0.3)),
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
                                    color: appColor.withValues(alpha: 0.75),
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
        if (_recentSessions.isNotEmpty)
          Center(
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/history'),
              child: Text('${appState.tr('see_all_label')} →'),
            ),
          ),
      ],
    );
  }

  // ── NUEVO: card Summary (pedido explícito, batch de 4 bugs) ──
  // BUG FIX (pedido explícito): reemplaza tanto el MileageDeductionBadge
  // (millas del año + estimado IRS, ver git history) como la versión previa
  // de esta card (solo hoy) -- ahora clona el layout de dos columnas de
  // Reports (_buildSummaryCard en reports_screen.dart): TOTAL MILES a la
  // izquierda y TODAY a la derecha, separados por un VerticalDivider. La
  // diferencia con Reports es la columna izquierda: ahí es _periodTotalMiles
  // (el rango de fechas que el usuario elija, por defecto ~12 meses); acá es
  // el MES CALENDARIO en curso (_monthMiles, ver _loadMonthSummary), fijo,
  // sin selector -- pedido explícito ("total miles de cada mes, no
  // global"). TODAY sigue igual (_todayMiles/_todayDurationSec, se resetea
  // a las 12am). Se agrega una 3ra fila con el estimado de deducción IRS
  // del mes (_monthDeduction), con el mismo disclaimer-detrás-de-un-tap que
  // tenía MileageDeductionBadge.
  Widget _buildSummaryCard(AppState appState, Color cardBg, Color borderColor,
      Color labelColor, Color textColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String fmtMiles(double miles) {
      final display = appState.useMetricSystem
          ? (miles * 1.60934).toStringAsFixed(2)
          : miles.toStringAsFixed(2);
      final unit = appState.useMetricSystem
          ? appState.tr('kilometer_short')
          : appState.tr('mile_short');
      return '$display $unit';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: fullBleedCard(color: cardBg, border: borderColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // RECENT TRIPS lives on the left of this card's header now
          // (owner's request, 2026-10-09), with SUMMARY on the right; "See
          // all" moved under the trip list.
          CmCardHeader(
            title: appState.tr('recent_trips_title'),
            trailing: Text(appState.tr('summary').toUpperCase(), style: cmHeaderLinkStyle),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(kPageGutter, 12, 8, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // This column is the current month (_monthMiles); it said
                        // "TOTAL MILES" and read like the header's total (2026-10-09).
                        Text(appState.tr('this_month').toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: labelColor)),
                        const SizedBox(height: 8),
                        _monthLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildSessionInfoChip(
                                    icon: Icons.speed_rounded,
                                    value: fmtMiles(_monthMiles),
                                    isDark: isDark,
                                  ),
                                  _buildSessionInfoChip(
                                    icon: Icons.timer_outlined,
                                    value: _formatDurationFromSeconds(_monthDurationSec),
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: borderColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, kPageGutter, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(appState.tr('today').toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: labelColor)),
                        const SizedBox(height: 8),
                        _summaryLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildSessionInfoChip(
                                    icon: Icons.speed_rounded,
                                    value: fmtMiles(_todayMiles),
                                    isDark: isDark,
                                  ),
                                  _buildSessionInfoChip(
                                    icon: Icons.timer_outlined,
                                    value: _formatDurationFromSeconds(_todayDurationSec),
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!_monthLoading) ...[
            Divider(height: 1, color: borderColor),
            InkWell(
              onTap: () => _showIrsEstimateDisclaimer(appState),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(kPageGutter, 10, kPageGutter, 12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      '≈\$${_monthDeduction.toStringAsFixed(0)} '
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
          ],
        ],
      ),
    );
  }

  // Mismo disclaimer que tenía MileageDeductionBadge (ahora eliminado del
  // Dashboard) -- el estimado en dólares nunca debe leerse como la
  // deducción oficial del IRS, así que el detalle completo (qué tarifa se
  // usa, que ControlMiles no es el IRS ni está afiliado) vive detrás de
  // este tap, nunca impreso en la card en sí.
  void _showIrsEstimateDisclaimer(AppState appState) {
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

  Widget _buildSessionInfoChip({
    required IconData icon,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E281F) : const Color(0xFFF3ECDF),
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
    return isDark ? const Color(0xFF2E281F) : const Color(0xFFE3D9C4);
  }

  @override
  Widget build(BuildContext context) {
    final appState  = Provider.of<AppState>(context);
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF12100C) : const Color(0xFFFAF6EE);

    final displayValue = appState.useMetricSystem
        ? (liveMiles * 1.60934).toStringAsFixed(2)
        : liveMiles.toStringAsFixed(2);
    final unitLabel = appState.useMetricSystem
        ? appState.tr('kilometer_short')
        : appState.tr('mile_short');

    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_headerMilesLoadedFor != null && _headerMilesLoadedFor != appState.headerMilesPeriod) {
      _headerMilesLoadedFor = appState.headerMilesPeriod;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadHeaderMiles());
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      drawer: const MainDrawer(),
      bottomNavigationBar: _buildBottomButtons(isDark, appState),
      // Brand-blue header with a rounded bottom (warm palette, 2026-10-09).
      // Header, option B (owner's pick, 2026-10-09): the app's warm brown
      // with a rounded bottom; the time-of-day greeting with a sun or moon,
      // and this week's miles big, in a serif like the website.
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF3D352A) : const Color(0xFF2E281F),
        foregroundColor: const Color(0xFFFAF6EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(22))),
        titleSpacing: 0,
        title: Row(
          children: [
            Icon(_isDaytime ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                size: 20, color: _isDaytime ? const Color(0xFFF2B48C) : const Color(0xFFC9BFA9)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _buildGreeting(appState),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFFFAF6EE)),
              ),
            ),
          ],
        ),
        // Miles on the right, level with the greeting (owner's request,
        // 2026-10-09): value in a serif, the period underneath.
        actions: [
          // Soft divider between the greeting and the miles: a hairline in
          // faint cream that fades out at both ends (2026-10-09).
          Container(
            width: 1,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFAF6EE).withValues(alpha: 0),
                  const Color(0xFFFAF6EE).withValues(alpha: 0.35),
                  const Color(0xFFFAF6EE).withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: kPageGutter),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${appState.useMetricSystem ? (_headerMiles * 1.60934).toStringAsFixed(1) : _headerMiles.toStringAsFixed(1)} '
                  '${appState.useMetricSystem ? appState.tr('kilometer_short') : appState.tr('mile_short')}',
                  style: const TextStyle(
                      fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFFFAF6EE)),
                ),
                Text(
                    appState
                        .tr(switch (appState.headerMilesPeriod) {
                          'month' => 'this_month',
                          'year' => 'this_year',
                          _ => 'this_week',
                        })
                        .toLowerCase(),
                    style: const TextStyle(fontSize: 11, color: Color(0xFFC9BFA9))),
              ],
            ),
          ),
        ],
        toolbarHeight: 72,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _initDashboard();
          await _loadActiveVehicle();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          // Full-width rows (2026-10-01): no side margin here -- cards span
          // edge to edge; non-card elements get Gutter() instead.
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              const SizedBox(height: 10),

              Gutter(child: _buildSwitchAppBanner()),

              const SizedBox(height: 20),

              // BUG FIX (pedido explícito, "una misma card"): Vehicle y las
              // estadísticas del viaje actual (millas + duración en vivo)
              // vivían en dos cards separadas (esta + _buildStatsBox, ver
              // git history) -- ahora son UNA sola card, mismo patrón visual
              // que el resto del Dashboard (header + Divider + contenido).
              // El total mensual que antes vivía en MileageDeductionBadge
              // (año completo, ya eliminado) ahora vive en la card Summary
              // más abajo, no acá -- ver _buildSummaryCard.
              // Tracking card (2026-10-01, explicit user request): vehicle,
              // map, miles/duration and START live together in ONE card --
              // START used to be the big round button under the gig-app
              // carousel. The auto-detect start/stop flash now plays over
              // this card, where the trip state is shown.
              _vehicleLoading
                  ? const CircularProgressIndicator()
                  : Stack(
                      children: [
                        // Light blue (2026-10-09, trial): the tracking card
                        // stands out from the white cards.
                        _buildVehicleCard(
                          appState: appState,
                          isDark: isDark,
                          cardBg: isDark ? const Color(0xFF15222C) : const Color(0xFFE6F0F8),
                          borderColor: isDark ? const Color(0xFF22384A) : const Color(0xFFBDD6EA),
                          tripMilesValue: displayValue,
                          tripMilesUnit: unitLabel,
                          trackingRow: TrackingActionButton(
                compact: true,
                selectedGigApp: _selectedGigApp,
                selectedIrsPurpose: _selectedIrsPurpose,
                // BUG FIX (dashboard no se refrescaba tras terminar un
                // viaje): antes solo se recargaba en initState() o
                // pull-to-refresh manual. También recarga el total del día
                // (card Summary) -- terminar un viaje lo cambia.
                onTripEnded: () {
                  _loadRecentSessions();
                  _loadTodaySummary();
                  _loadMonthSummary();
                },
                // Subscription-tier enforcement (explicit user requirement,
                // 2026-09-04): reuses the exact canStart/cannotStartMessage
                // hook Fleet's DVIR gate already established -- Dashboard
                // (Gig) never passed it before now. Only blocks STARTING a
                // new trip; existing data/reports stay fully visible. Shows
                // the same upgrade dialog auto_detect_apps_button.dart's
                // premium gate already uses, not just a plain snackbar --
                // canStart's own closure captures this build method's
                // `context`, so a real dialog with a deep link to
                // AppRoutes.subscription works fine here despite canStart's
                // signature not passing one through.
                canStart: appState.isFreeTrialExpired
                    ? () async {
                        await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(appState.tr('free_trial_expired_title')),
                            content: Text(appState.tr('free_trial_expired_body')),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(appState.tr('cancel')),
                              ),
                              FilledButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.pushNamed(context, AppRoutes.subscription);
                                },
                                child: Text(appState.tr('upgrade_plan')),
                              ),
                            ],
                          ),
                        );
                        return false;
                      }
                    : null,
                // No cannotStartMessage here on purpose -- the dialog above
                // already tells the full story with a real upgrade CTA;
                // TrackingActionButton would otherwise ALSO show a plain
                // red snackbar right after the dialog closes (canStart
                // resolving false triggers that path regardless), which
                // would just be a redundant second message stacked on top.
              ),
                        ),
                  // Auto-detect start/stop flash (2026-09-08): a full-bleed,
                  // non-interactive colored fade over the tracking card --
                  // independent of the button's own running/idle color.
                  // IgnorePointer so it never blocks taps beneath it; AnimatedOpacity (not AnimatedContainer) since only
                  // opacity changes here, color is set once per flash.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: _autoFlashColor == null ? 0.0 : 0.25,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _autoFlashColor ?? Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  ),
                      ],
                    ),

              const SizedBox(height: 30),

              // Explicit user request (2026-08-27): a more discoverable
              // entry point for auto-detect, right where the carousel/
              // status card already lives -- replaces the small circular
              // toggle that used to live in TrackingActionButton. Only
              // shown at idle (Gig-only, same scope the drawer's removed
              // version had) -- once running, the mode is already
              // committed for that trip.
              //
              // BUG FIX (explicit user requirement, 2026-09-04): this
              // button was visible to EVERY gig user regardless of tier --
              // Basic/Free could see and tap it, only to hit
              // AutoDetectAppsButton._activate()'s premium-locked dialog.
              // "Basic solo debe ver el carrusel, Premium añade Auto
              // Detection" -- the entry point itself is now Premium-only,
              // not just what happens after tapping it. Basic/Free always
              // fall through to the plain GigAppSelector carousel below,
              // same as if auto-detect were simply off.
              if (appState.isGig &&
                  appState.premiumEntitled &&
                  TrackingController.currentState == TrackingState.idle) ...[
                const Gutter(child: AutoDetectAppsButton()),
                const SizedBox(height: 20),
              ],

              // Explicit user request: the carousel must NEVER reappear
              // while auto-detect is armed, in ANY trip state -- it was
              // flagged as inconsistent that it came back once a
              // detected trip started tracking. Auto-detect now owns
              // gig-app selection for the whole trip lifecycle (start AND
              // mid-trip switching, see AutoTripDetectionService's own
              // _pollForMidTripSwitch), so the status card stays up
              // throughout instead of handing back to the manual
              // carousel.
              appState.autoDetectEnabled
                          ? _buildAutoDetectStatusCard(appState, isDark)
                          : GigAppSelector(
                              selectedGigApp: _selectedGigApp,
                              activeGigApp: TrackingController.currentGigApp,
                              isPaused: TrackingController.isPaused,
                              onAppSelected: (appId) => _handleAppSelection(appId),
                              onCustomSelected: (appId, irsPurpose) =>
                                  _handleAppSelection(appId, irsPurpose: irsPurpose),
                            ),

              // (The "TRACKING ACTIVE: APP" chip lived here -- the tracking
              // card's status line shows the same thing now.)

              // More room between the carousel and Recent trips (2026-10-09).
              const SizedBox(height: 46),

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
  void _openTripRouteMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TripRouteMapScreen()),
    );
  }

  Future<void> _goToVehicleProfile() async {
    await Navigator.pushNamed(context, AppRoutes.vehicle);
    if (mounted) _loadActiveVehicle();
  }

  Widget _buildVehicleCard({
    required AppState appState,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required String tripMilesValue,
    required String tripMilesUnit,
    required Widget trackingRow,
  }) {
    // BUG FIX (pedido explícito, "Full-width Divider"): la card de vehículo
    // no tenía separación entre título y contenido -- ahora sigue el mismo
    // patrón que las demás cards del Dashboard: header (ícono + label) +
    // Divider de borde a borde + contenido.
    // BUG FIX (build error, olvido al escribir el header): 'labelColor' no
    // es un campo de la clase -- cada método que lo usa lo calcula local a
    // partir de isDark (mismo criterio que _buildRecentSessionsHistory).
    final labelColor = isDark ? Colors.white38 : const Color(0xFFA39A86);
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);

    // BUG FIX (pedido explícito, "una misma card"): millas + duración del
    // viaje EN VIVO (antes su propia card gradiente, _buildStatsBox) ahora
    // viven como sección final de esta misma card, con los colores propios
    // del tema (no el blanco fijo que tenía sentido sobre el gradiente
    // azul) -- reusa _buildStatHalf con textColor/labelColor explícitos.
    final tripStatsSection = Column(
      children: [
        Divider(height: 1, color: borderColor),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatHalf(tripMilesValue, tripMilesUnit,
                    Icons.speed, textColor, labelColor),
              ),
              Container(width: 1, height: 40, color: borderColor),
              Expanded(
                child: _buildStatHalf(_displayTime, appState.tr('duration'),
                    Icons.timer, textColor, labelColor),
              ),
            ],
          ),
        ),
      ],
    );

    final trackingSection = Column(
      children: [
        Divider(height: 1, color: borderColor),
        Padding(
          padding: const EdgeInsets.fromLTRB(kPageGutter, 14, kPageGutter, 14),
          child: trackingRow,
        ),
      ],
    );

    final headerRow = CmCardHeader(title: appState.tr('vehicle'));

    // Fleet Phase 3: a fleet_driver's vehicle comes from their admin
    // (assigned_driver_id), not from AppRoutes.vehicle (VehicleScreen is
    // owner_user_id CRUD -- a driver can't add/edit/delete an org vehicle
    // there, so sending them to it on tap would be a dead end). No new
    // "fleet vehicle detail" screen is built this pass -- the card is
    // simply non-interactive for a fleet driver, and its empty state
    // explains WHY there's nothing to tap instead of inviting an action
    // that doesn't apply to them.
    final isFleetDriver = appState.isFleetDriver;

    // BUG FIX (silencioso, reportado por el usuario): antes TODA la card
    // estaba envuelta en un InkWell que navegaba a VehicleScreen, así que
    // tocar el timer, las millas o el mapa también abría el menú de vehículo.
    // Ahora la navegación vive SOLO en la zona de vehículo (aquí, la fila
    // "agregar vehículo"); las estadísticas del viaje y el mapa no reaccionan.
    if (_activeVehicle == null) {
      return Container(
        width: double.infinity,
        decoration: fullBleedCard(color: cardBg, border: borderColor),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            headerRow,
            InkWell(
              onTap: isFleetDriver ? null : _goToVehicleProfile,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(kPageGutter, 12, kPageGutter, 14),
                child: isFleetDriver
                    ? Text(appState.tr('fleet_no_vehicle_assigned'))
                    : Row(
                        children: [
                          Expanded(
                            child: Text(appState.tr('add_vehicle_prompt')),
                          ),
                          TextButton(
                            onPressed: _goToVehicleProfile,
                            child: Text(appState.tr('add_vehicle').toUpperCase()),
                          ),
                        ],
                      ),
              ),
            ),
            tripStatsSection,
            trackingSection,
          ],
        ),
      );
    }

    // Sin InkWell exterior: solo el bloque de vehículo (más abajo) navega.
    // Tracking card (2026-10-01, explicit user request): no "VEHICLE"
    // header row, and the vehicle block is a narrow column (icon over name)
    // so the map gets most of the width and more height. Tapping the map or
    // its expand button opens TripRouteMapScreen (active trip's route).
    return Container(
      width: double.infinity,
      decoration: fullBleedCard(color: cardBg, border: borderColor),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kPageGutter, 14, kPageGutter, 14),
              child: SizedBox(
                height: 132,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 92,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: isFleetDriver ? null : _goToVehicleProfile,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.directions_car_filled_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 10),
                            // Marca del vehículo activo (ej. Toyota, Nissan) + modelo.
                            Text(
                              _activeVehicle!.displayName,
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w900, color: textColor),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    appState.tr('vehicle'),
                                    style: TextStyle(fontSize: 11, color: labelColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!isFleetDriver)
                                  Icon(Icons.keyboard_arrow_down_rounded,
                                      size: 18, color: labelColor),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // El thumbnail arranca su PROPIO stream de Geolocator
                    // (ver driver_live_map_view.dart), visible sin viaje.
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(border: Border.all(color: borderColor)),
                                child: const DriverLiveMapView(compact: true),
                              ),
                            ),
                            // Only the expand button opens the big map
                            // (explicit user request, 2026-10-01: an
                            // accidental tap on the map must do nothing).
                            // This layer just swallows taps on the map.
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {},
                              ),
                            ),
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Material(
                                color: isDark ? const Color(0xE60F172A) : const Color(0xE6FFFFFF),
                                shape: const CircleBorder(),
                                elevation: 2,
                                child: IconButton(
                                  tooltip: appState.tr('trip_route'),
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(Icons.open_in_full_rounded,
                                      size: 18, color: Theme.of(context).colorScheme.primary),
                                  onPressed: _openTripRouteMap,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Fleet Phase 4: DVIR-style pre/post-trip inspection, only
            // relevant for a fleet driver's assigned vehicle -- a Gig
            // owner's personal vehicle has no fleet admin to report to, so
            // there's no one for a checklist submission to be visible to.
            if (isFleetDriver) ...[
              Divider(height: 1, color: borderColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(kPageGutter, 10, kPageGutter, 10),
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
            tripStatsSection,
            trackingSection,
          ],
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

  // Fixed History / Reports bar. Android 15+ draws apps edge to edge, so on
  // phones with the 3-button navigation bar the system bar covered these
  // buttons (owner's report, 2026-10-09). SafeArea(top: false) adds exactly
  // the system bar's height below them (0 on gesture-navigation phones); the
  // bar's background still runs behind the system bar.
  Widget _buildBottomButtons(bool isDark, AppState appState) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1812) : Colors.white,
        border: Border(
          top: BorderSide(
              color: isDark ? const Color(0xFF2E281F) : const Color(0xFFE3D9C4)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/history'),
              icon: const Icon(Icons.history),
              label: Text(appState.tr('history').toUpperCase()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E281F),
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
        ),
      ),
    );
  }

  // BUG FIX (pedido explícito, "una misma card"): ya no es una card propia
  // con gradiente -- ahora es la sección final de _buildVehicleCard (ver
  // tripStatsSection ahí), así que toma textColor/labelColor del tema en
  // vez del blanco fijo que tenía sentido sobre el gradiente azul anterior.
  Widget _buildStatHalf(
      String value, String label, IconData icon, Color textColor, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kPageGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: labelColor),
              const SizedBox(width: 6),
              Text(label.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10, color: labelColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: textColor)),
        ],
      ),
    );
  }
}