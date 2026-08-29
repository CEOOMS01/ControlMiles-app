// Olympus Mont Systems LLC - ControlMiles
// lib/screens/reports_screen.dart
// Dark mode · Real DB data (sessions + session_sections) · Clean i18n

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../logic/app_state.dart';
import '../i18n/app_texts.dart';
import '../models/tracking_session.dart';
import '../models/session_section.dart';
import '../models/gig_app.dart';
import '../models/vehicle.dart';
import '../services/report_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool    _isLoading       = false;
  String? _progressMessage;

  // BUG FIX (pedido explícito): el rango por defecto al abrir Reports pasa
  // de "últimos 3 meses" a "últimos 12 meses" -- mismo motivo que el fix
  // de History (365 días en vez de 30): con el nuevo divisor de mes, un
  // rango de solo 3 meses casi nunca mostraba más de 2-3 secciones de mes
  // agrupadas. Se recalcula respecto a DateTime.now() cada vez que se crea
  // la pantalla, igual que el rolling window de History — no es una fecha
  // fija guardada. El selector de fechas manual (icono de calendario en el
  // AppBar, más abajo en build()) NO se ve afectado por este cambio: sigue
  // permitiendo elegir cualquier rango desde 2024 hasta hoy, sin truncar
  // el historial (que se conserva íntegro en la DB, sin borrado, para
  // sustentar 3+ años de reportes ante el IRS).
  DateTimeRange _dateRange = DateTimeRange(
    start: _subtractMonths(DateTime.now(), 12),
    end:   DateTime.now(),
  );

  /// Resta `months` meses de forma calendario-exacta (no una aproximación
  /// de N días), ajustando el día si el mes destino tiene menos días
  /// (ej.: 31 de mayo - 3 meses = 28/29 de febrero, no un desborde a marzo).
  static DateTime _subtractMonths(DateTime date, int months) {
    var year = date.year;
    var month = date.month - months;
    while (month <= 0) {
      month += 12;
      year -= 1;
    }
    final lastDayOfTargetMonth = DateTime(year, month + 1, 0).day;
    final day = date.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : date.day;
    return DateTime(year, month, day, date.hour, date.minute, date.second);
  }

  List<TrackingSession>                     _sessions = [];
  Map<String, List<SessionSection>>         _sections = {};
  // BUG FIX (pedido explícito): el reporte nunca mostraba qué vehículo(s)
  // se usaron -- resuelto acá a partir de los sessions.vehicle_id
  // realmente presentes en el rango cargado (no assume un único vehículo
  // "activo": si el usuario cambió de auto dentro del período, todos
  // aparecen). Incluye vehículos archivados -- el historial de un auto que
  // ya no se usa sigue siendo real evidencia del período reportado.
  List<Vehicle>                             _vehiclesUsed = [];

  // ── NUEVO: card Summary (total del día, pedido explícito) ──
  // BUG FIX (mismo criterio que dashboard_screen.dart): este total es del
  // DÍA CALENDARIO en curso, independiente de _dateRange (el filtro de
  // fechas de esta pantalla) -- no tiene sentido que "el total de hoy"
  // cambie según qué rango histórico esté mirando el usuario. Fetch propio,
  // no reutiliza _sessions. Se refresca solo (DateTime.now() se re-evalúa
  // cada vez que _loadTodaySummary corre -- pull-to-refresh, cambio de
  // rango, o volver a abrir la pantalla), efectivamente "resetea" a las
  // 12am porque la ventana de la query siempre arranca en la medianoche
  // local del momento en que se ejecuta.
  double _todayMiles = 0.0;
  int _todayDurationSec = 0;
  bool _summaryLoading = true;

  // BUG FIX (pedido explícito): el card Summary solo mostraba el total del
  // día -- no había ningún total acumulado visible en Reports (History sí
  // lo tiene, ver su propio card "LAST 12 MONTHS"). Estos NO se resetean a
  // medianoche como _todayMiles/_todayDurationSec -- son la suma de
  // _sessions, que ya está cargada para _dateRange (por defecto los
  // últimos 12 meses, o el rango que el usuario elija con el selector de
  // calendario), sin fetch adicional.
  double _periodTotalMiles = 0.0;
  int _periodTotalDurationSec = 0;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _loadTodaySummary();
  }

  Future<void> _loadTodaySummary() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _summaryLoading = false);
        return;
      }

      final nowLocal = DateTime.now();
      final todayMidnightLocal =
          DateTime(nowLocal.year, nowLocal.month, nowLocal.day, 0, 0, 0);
      final windowStartUtc = todayMidnightLocal.toUtc();

      final rows = await Supabase.instance.client
          .from('sessions')
          .select('total_miles, total_duration_seconds')
          .eq('user_id', user.id)
          .eq('is_closed', true)
          .gte('start_time', windowStartUtc.toIso8601String());

      final list = List<Map<String, dynamic>>.from(rows);
      final miles = list.fold<double>(0.0,
          (acc, r) => acc + ((r['total_miles'] as num?)?.toDouble() ?? 0.0));
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
      debugPrint('[ReportsScreen] Today summary load error: $e');
      if (mounted) setState(() => _summaryLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════════
  // DATA
  // ════════════════════════════════════════════════════════════
  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final sessionsRaw = await Supabase.instance.client
          .from('sessions')
          .select()
          .eq('user_id', user.id)
          .eq('is_closed', true)
          .gte('start_time', _dateRange.start.toIso8601String())
          .lte('start_time',
              _dateRange.end.add(const Duration(days: 1)).toIso8601String())
          .order('start_time', ascending: false);

      final sessions = (sessionsRaw as List)
          .map((s) => TrackingSession.fromMap(s as Map<String, dynamic>))
          .toList();

      final sectionsMap = <String, List<SessionSection>>{};
      for (final session in sessions) {
        final raw = await Supabase.instance.client
            .from('session_sections')
            .select()
            .eq('session_id', session.id)
            .order('start_time', ascending: true);

        // BUG FIX: este filtro pedía section_status='closed' directo a la
        // DB, ignorando el status 'switched' (secciones cerradas por
        // cambio de gig app, no por fin de viaje — ver fix #2, switch
        // atómico). El modelo SessionSection.isClosed ya sabe tratar
        // 'closed' y 'switched' como "sección terminada" (así lo usa
        // History); acá se filtraba aparte con una lista de statuses
        // distinta y desactualizada. Ahora usa la misma fuente de verdad
        // en vez de duplicarla, para no volver a desincronizarse.
        sectionsMap[session.id] = (raw as List)
            .map((s) => SessionSection.fromMap(s as Map<String, dynamic>))
            .where((s) => s.isClosed)
            .toList();
      }

      final vehicleIds = sessions
          .map((s) => s.vehicleId)
          .whereType<String>()
          .toSet()
          .toList();

      List<Vehicle> vehiclesUsed = [];
      if (vehicleIds.isNotEmpty) {
        final vehiclesRaw = await Supabase.instance.client
            .from('vehicles')
            .select()
            .inFilter('id', vehicleIds);
        vehiclesUsed = (vehiclesRaw as List)
            .map((v) => Vehicle.fromMap(v as Map<String, dynamic>))
            .toList();
      }

      final periodMiles = sessions.fold<double>(
          0.0, (acc, s) => acc + s.totalMiles);
      final periodDurationSec = sessions.fold<int>(
          0, (acc, s) => acc + (s.effectiveDurationSeconds ?? 0));

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _sections = sectionsMap;
          _vehiclesUsed = vehiclesUsed;
          _periodTotalMiles = periodMiles;
          _periodTotalDurationSec = periodDurationSec;
        });
      }
    } catch (e) {
      debugPrint('[ReportsScreen] Load error: $e');
      if (mounted) {
        _showSnack(
            context.read<AppState>().tr('something_went_wrong'),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════════
  // PDF EXPORT
  // BUG FIX (pedido explícito): se eliminó la generación de PDF por
  // sesión individual — ahora solo existe un PDF global, que cubre TODAS
  // las sesiones actualmente cargadas en pantalla (es decir, el rango de
  // fechas ya filtrado por _dateRange / el selector de calendario del
  // AppBar). "Parcial" = ese rango filtrado; no se agregó un selector
  // nuevo de sesiones porque el date-range picker que ya existe cumple
  // ese rol.
  // ════════════════════════════════════════════════════════════
  Future<void> _exportGlobalPdf(AppState appState) async {
    if (_sessions.isEmpty) {
      // BUG FIX (2026-08-29, real bug the user actually hit): 'no_reports_found'
      // was never defined in ANY language file, not even English -- the
      // i18n_validator can't catch this class of bug (it only diffs non-English
      // against English; a key missing everywhere is invisible to it). Every
      // user, every language, saw the literal raw key. Reused the existing,
      // semantically-fitting 'no_trips_yet' key instead of inventing a
      // near-duplicate.
      _showSnack(appState.tr('no_trips_yet'), error: true);
      return;
    }

    setState(() {
      _isLoading       = true;
      // BUG FIX (2026-08-29): 'generating_report' was never defined in ANY
      // language file either -- see the 'no_trips_yet' comment above, same
      // root cause. New real key, translated into all 6 fully-covered
      // languages (no existing key fit this specific progress message).
      _progressMessage = appState.tr('generating_report_progress');
    });

    try {
      await ReportService.generateGlobalReport(
        sessions:          _sessions,
        sectionsBySession: _sections,
        dateRange:         _dateRange,
        userName:          _resolveUserName(),
        userDisplayId:     appState.userDisplayId ?? '---',
        mileageMethod:     appState.mileageMethod,
        vehiclesUsed:      _vehiclesUsed,
      );

      // BUG FIX (2026-08-29, exactly what the user saw): 'report_generated_success'
      // was never defined anywhere -- same root cause as above. This is the
      // literal one reported: the success snackbar after generating a PDF
      // showed the raw key instead of a real message. 'report_generated'
      // already exists with the exact right meaning in all languages; no
      // new key needed, just pointing the call site at the real one.
      if (mounted) _showSnack(appState.tr('report_generated'));
    } catch (e) {
      debugPrint('[ReportsScreen] Global PDF error: $e');
      if (mounted) _showSnack('${appState.tr('error')}: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════
  // BUG FIX (pedido explícito): el PDF global mostraba el mismo valor en
  // "PROFILE" y en "USER ID" porque _exportGlobalPdf pasaba
  // appState.userDisplayId a ambos parámetros — AppState no guarda el
  // nombre real del usuario, solo el ID corto. El nombre sí existe: vive
  // en Supabase auth user_metadata (first_name/last_name), el mismo
  // origen que usa ProfileScreen._loadUserProfile(). Se resuelve acá en
  // vez de duplicar la lectura en ReportService, que no debe saber de
  // Supabase.
  String _resolveUserName() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return '---';

    final metadata  = user.userMetadata ?? {};
    final first     = (metadata['first_name'] as String?)?.trim() ?? '';
    final last      = (metadata['last_name']  as String?)?.trim() ?? '';
    final fullName  = '$first $last'.trim();

    if (fullName.isNotEmpty) return fullName;
    if ((user.email ?? '').isNotEmpty) return user.email!;
    return '---';
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            error ? Colors.red.shade700 : const Color(0xFF22C55E),
      ));
  }

  String _formatDate(DateTime? dt) =>
      dt != null ? DateFormat('MM/dd/yyyy').format(dt.toLocal()) : '---';

  String _formatTime(DateTime? dt) =>
      dt != null ? DateFormat('hh:mm a').format(dt.toLocal()) : '---';

  // BUG FIX: was `s.totalDurationSeconds ?? s.durationSeconds`, which only
  // falls back on null — legacy closed sections stuck at a literal 0 (from
  // before pause-aware persistence) showed "0m" instead of the real trip
  // length. effectiveDurationSeconds treats 0 as "not set" too.
  String _formatSectionDuration(SessionSection s) {
    final sec = s.effectiveDurationSeconds;
    final m   = sec ~/ 60;
    final h   = m   ~/ 60;
    if (h > 0) return '${h}h ${m % 60}m';
    return '${m}m';
  }

  // BUG FIX: TrackingSession now maps total_duration_seconds (pause-excluded,
  // persisted by TrackingController.stopTracking()); effectiveDurationSeconds
  // falls back to the raw start/end difference only for legacy sessions
  // closed before that fix, where the column is stuck at 0.
  String _formatSessionDuration(TrackingSession session) {
    final sec = session.effectiveDurationSeconds;
    if (sec == null) return '---';
    final m   = sec ~/ 60;
    final h   = m   ~/ 60;
    if (h > 0) return '${h}h ${m % 60}m';
    return '${m}m';
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    final scaffoldBg = isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    final cardBg     = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border     = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        title: Text(
          appState.tr('reports').toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        iconTheme: IconThemeData(
            color: isDark ? Colors.white : const Color(0xFF0F172A)),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_rounded),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate:        DateTime(2024),
                lastDate:         DateTime.now(),
                initialDateRange: _dateRange,
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: isDark
                        ? const ColorScheme.dark(
                            primary: Color(0xFF3B82F6))
                        : const ColorScheme.light(
                            primary: Color(0xFF3B82F6)),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() => _dateRange = picked);
                _loadSessions();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                      color: Color(0xFF3B82F6), strokeWidth: 2),
                  const SizedBox(height: 20),
                  Text(
                    _progressMessage ?? appState.tr('loading'),
                    style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          : _buildBody(appState, isDark, cardBg, border),
    );
  }

  Widget _buildBody(
      AppState appState, bool isDark, Color cardBg, Color border) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadSessions();
        await _loadTodaySummary();
      },
      color: const Color(0xFF3B82F6),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // BUG FIX (pedido explícito, batch de 4 bugs): reemplaza la card
          // de rango de fechas por una card "Summary" con el total del día
          // calendario -- el selector de rango (ícono de calendario en el
          // AppBar) sigue funcionando igual, solo perdió su card dedicada.
          SliverToBoxAdapter(
            child: _buildSummaryCard(appState, isDark, border),
          ),
          SliverToBoxAdapter(
            child: _buildGlobalPdfButton(appState),
          ),
          if (_sessions.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(appState, isDark),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  _buildGroupedSessionCards(appState, isDark, cardBg, border),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── card Summary ──
  // BUG FIX (pedido explícito): el card solo mostraba el total del día
  // calendario -- no había ningún total acumulado visible (History sí
  // tiene el suyo, ver su card "LAST 12 MONTHS"). Ahora muestra dos filas:
  // TOTAL (la suma de _sessions para _dateRange, el rango seleccionado --
  // NO se resetea a medianoche) y TODAY (el total del día calendario en
  // curso -- ese sí se "resetea" solo porque _loadTodaySummary reconsulta
  // desde la medianoche local cada vez que corre).
  Widget _buildSummaryCard(AppState appState, bool isDark, Color border) {
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final labelColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);

    String fmtMiles(double miles) {
      final display = appState.useMetricSystem
          ? (miles * 1.60934).toStringAsFixed(2)
          : miles.toStringAsFixed(2);
      final unit = appState.useMetricSystem
          ? appState.tr('kilometer_short')
          : appState.tr('mile_short');
      return '$display $unit';
    }

    String fmtDuration(int seconds) {
      final durMin = seconds ~/ 60;
      final durH = durMin ~/ 60;
      final durRemMin = durMin % 60;
      return durH > 0 ? '${durH}h ${durRemMin}m' : '${durRemMin}m';
    }

    Widget subLabel(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: labelColor,
            ),
          ),
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
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
          Divider(height: 1, color: border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                subLabel(appState.tr('total_miles')),
                Row(
                  children: [
                    _infoChip(
                      icon: Icons.speed_rounded,
                      label: fmtMiles(_periodTotalMiles),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _infoChip(
                      icon: Icons.timer_outlined,
                      label: fmtDuration(_periodTotalDurationSec),
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                subLabel(appState.tr('today')),
                // BUG FIX (pedido explícito, mismo criterio que Dashboard):
                // millas y tiempo estaban "flotando" sueltos en un Row --
                // ahora cada uno vive en su propio cuadrito (mismo chip que
                // ya usa _infoChip en esta pantalla).
                _summaryLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Row(
                        children: [
                          _infoChip(
                            icon: Icons.speed_rounded,
                            label: fmtMiles(_todayMiles),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _infoChip(
                            icon: Icons.timer_outlined,
                            label: fmtDuration(_todayDurationSec),
                            isDark: isDark,
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Global PDF button (reemplaza el botón por-sesión) ──────
  Widget _buildGlobalPdfButton(AppState appState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _sessions.isEmpty ? null : () => _exportGlobalPdf(appState),
          icon:  const Icon(Icons.picture_as_pdf_rounded, size: 18),
          label: Text(appState.tr('generate_global_pdf').toUpperCase()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────
  Widget _buildEmptyState(AppState appState, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 48,
              color: isDark
                  ? Colors.white24
                  : const Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          Text(
            appState.tr('no_reports_found'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sesiones agrupadas por mes (pedido explícito: "que se dividan las
  // sesiones por mes, ejemplo agosto y todas sus sesiones") -- mismo
  // criterio que history_screen.dart's month divider, adaptado a la
  // SliverList plana de esta pantalla en vez de un ListView.builder.
  List<Widget> _buildGroupedSessionCards(
      AppState appState, bool isDark, Color cardBg, Color border) {
    final items = <Widget>[];
    String? previousMonth;

    for (var i = 0; i < _sessions.length; i++) {
      final session = _sessions[i];
      // BUG FIX (2026-08-29): without an explicit locale, DateFormat's
      // month name always rendered in English regardless of the app's
      // selected language -- see main.dart's initializeDateFormatting
      // comment for the full explanation.
      final currentMonth = session.startTime != null
          ? DateFormat('MMMM yyyy', appState.currentLanguage.code)
              .format(session.startTime!.toLocal())
          : null;

      if (currentMonth != null && currentMonth != previousMonth) {
        items.add(Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 24, bottom: 10),
          child: Row(
            children: [
              Text(
                currentMonth.toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Divider(color: border, thickness: 1.4)),
            ],
          ),
        ));
        previousMonth = currentMonth;
      }

      items.add(_buildSessionCard(appState, session, isDark, cardBg, border));
    }

    return items;
  }

  // ── Session card ───────────────────────────────────────────
  Widget _buildSessionCard(AppState appState, TrackingSession session,
      bool isDark, Color cardBg, Color border) {
    final sections  = _sections[session.id] ?? [];
    final unitLabel = appState.useMetricSystem
        ? appState.tr('kilometer_short')
        : appState.tr('mile_short');
    final totalDisp = appState.useMetricSystem
        ? (session.totalMiles * 1.60934).toStringAsFixed(2)
        : session.totalMiles.toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
      ),
      child: Column(
        children: [
          // ── Header row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded,
                      size: 18, color: Color(0xFF3B82F6)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(session.startTime),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${appState.tr('id_label')}: ${session.id.substring(0, 8).toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                // Miles chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$totalDisp $unitLabel',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Time + duration row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                _infoChip(
                  icon:  Icons.schedule_rounded,
                  label: '${_formatTime(session.startTime)} → ${_formatTime(session.endTime)}',
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                if (session.startTime != null && session.endTime != null)
                  _infoChip(
                    icon:   Icons.timer_outlined,
                    label:  _formatSessionDuration(session),
                    isDark: isDark,
                  ),
              ],
            ),
          ),

          // ── Sections breakdown ──
          if (sections.isNotEmpty) ...[
            Divider(height: 1, color: border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      appState.tr('trip_details').toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark
                            ? Colors.white38
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: sections
                        .map((s) => _buildSectionChip(s, appState, isDark))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Section chip ───────────────────────────────────────────
  Widget _buildSectionChip(
      SessionSection section, AppState appState, bool isDark) {
    final meta     = _appMeta(section.gigApp);
    final appColor = meta.color;
    final secDisp  = appState.useMetricSystem
        ? (section.totalMiles * 1.60934).toStringAsFixed(1)
        : section.totalMiles.toStringAsFixed(1);
    final secUnit  = appState.useMetricSystem
        ? appState.tr('kilometer_short')
        : appState.tr('mile_short');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: appColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: appColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 13, color: appColor),
          const SizedBox(width: 5),
          // BUG FIX (pedido explícito): mismo gap que history_screen.dart --
          // irs_purpose se guardaba pero nunca aparecía en el reporte.
          Text(
            IrsPurposeCatalog.labelKeyFor(section.irsPurpose) != null
                ? '${meta.name} · ${appState.tr(IrsPurposeCatalog.labelKeyFor(section.irsPurpose)!)}'
                : meta.name,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: appColor),
          ),
          const SizedBox(width: 6),
          Text(
            '$secDisp $secUnit · ${_formatSectionDuration(section)}',
            style: TextStyle(
                fontSize: 10,
                color: appColor.withValues(alpha: 0.75),
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ── Info chip ──────────────────────────────────────────────
  Widget _infoChip(
      {required IconData icon,
      required String label,
      required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  // BUG FIX (consolidación pedida explícitamente): este catálogo vivía
  // duplicado a mano en 4 archivos — ver lib/models/gig_app.dart, ahora
  // fuente única de verdad.
  GigApp _appMeta(String appId) => GigAppCatalog.byId(appId);
}