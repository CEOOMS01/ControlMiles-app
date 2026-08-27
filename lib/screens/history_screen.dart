// Olympus Mont Systems LLC - ControlMiles
// lib/screens/history_screen.dart - PRODUCTION READY + DAILY DIVIDERS + 30 DAYS

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../logic/app_state.dart';
import '../models/tracking_session.dart';
import '../models/session_section.dart';
import '../models/gig_app.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;

  List<TrackingSession> _sessions = [];
  Map<String, List<SessionSection>> _sections = {};

  double _totalMiles = 0;
  int _totalDurationSeconds = 0;

  DateTime? _firstStart;
  DateTime? _lastEnd;

  final Map<String, bool> _expandedSessions = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final now = DateTime.now().toUtc();
      // BUG FIX (pedido explícito): la ventana era de 30 días, lo que
      // dejaba el nuevo divisor de mes mostrando prácticamente un solo
      // mes casi siempre -- ahora cubre el año completo (365 días) para
      // que History realmente pueda mostrar varios meses agrupados.
      final last12Months = now.subtract(const Duration(days: 365));

      final data = await Supabase.instance.client
          .from('sessions')
          .select('*, session_sections(*)')
          .eq('user_id', userId)
          .gte('start_time', last12Months.toIso8601String())
          .order('start_time', ascending: false);

      final sessions = <TrackingSession>[];
      final sectionsMap = <String, List<SessionSection>>{};

      double milesAccumulator = 0;
      int durationAccumulator = 0;

      DateTime? firstStart;
      DateTime? lastEnd;

      for (var row in data) {
        final session = TrackingSession.fromMap(row);
        sessions.add(session);

        final rawSections = row['session_sections'] as List? ?? [];
        final sectionList = rawSections
            .map((s) => SessionSection.fromMap(s))
            .where((s) => s.isClosed)
            .toList();

        sectionsMap[session.id] = sectionList;

        for (var s in sectionList) {
          milesAccumulator += s.totalMiles;
          // BUG FIX: was always using raw endTime-startTime, ignoring the
          // pause-excluded total_duration_seconds now persisted per section.
          durationAccumulator += s.effectiveDurationSeconds;
        }

        if (firstStart == null || (session.startTime != null && session.startTime!.isBefore(firstStart))) {
          firstStart = session.startTime;
        }
        if (session.endTime != null) {
          if (lastEnd == null || session.endTime!.isAfter(lastEnd)) {
            lastEnd = session.endTime;
          }
        }
      }

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _sections = sectionsMap;
          _totalMiles = milesAccumulator;
          _totalDurationSeconds = durationAccumulator;
          _firstStart = firstStart;
          _lastEnd = lastEnd;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("History error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // BUG FIX (consolidación pedida explícitamente): este catálogo vivía
  // duplicado a mano en 4 archivos — ver lib/models/gig_app.dart, ahora
  // fuente única de verdad.
  GigApp _getAppInfo(String appId) => GigAppCatalog.byId(appId);

  // ════════════════════════════════════════════════════════════
  // NOTA DE SECCIÓN (pedido explícito: las millas trackeadas jamás se
  // editan directamente — máxima seguridad del dato GPS. Si algo salió
  // mal, ej. "faltaron 5 millas", el usuario deja constancia en texto
  // libre, nunca tocando total_miles/total_duration_seconds).
  // ════════════════════════════════════════════════════════════
  Future<void> _editNote(SessionSection section) async {
    final appState = context.read<AppState>();
    final controller = TextEditingController(text: section.notes ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appState.tr(
            (section.notes ?? '').isEmpty ? 'add_note' : 'edit_note')),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: appState.tr('trip_note_hint'),
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(appState.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(appState.tr('save')),
          ),
        ],
      ),
    );

    if (result == null) return; // cancelado

    try {
      await Supabase.instance.client
          .from('session_sections')
          .update({'notes': result.isEmpty ? null : result})
          .eq('id', section.id);

      if (!mounted) return;
      setState(() {
        final list = _sections[section.sessionId];
        if (list == null) return;
        final idx = list.indexWhere((s) => s.id == section.id);
        if (idx == -1) return;
        list[idx] = result.isEmpty
            ? list[idx].copyWith(clearNotes: true)
            : list[idx].copyWith(notes: result);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.tr('note_saved_success'))),
      );
    } catch (e) {
      debugPrint('[HistoryScreen] Note save error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${appState.tr('error')}: $e'),
            backgroundColor: Colors.red.shade700),
      );
    }
  }

  // ════════════════════════════════════════════════════════════
  // BORRAR VIAJE (pedido explícito): elimina el viaje COMPLETO de la DB,
  // incluyendo las millas trackeadas — no es un archivo/soft-delete como
  // Vehicle. El usuario aceptó explícitamente perder el registro
  // (incluye el session_hash, que hoy no está verificado en ningún lado
  // del código, así que no rompe ninguna cadena de auditoría activa).
  // `sessions` ya tenía policy RLS de DELETE (user_id = auth.uid()) y
  // session_sections.session_id / audit_events son ON DELETE CASCADE —
  // verificado en DB antes de escribir esto, no hizo falta migración.
  // ════════════════════════════════════════════════════════════
  Future<void> _confirmDeleteTrip(TrackingSession session, int index) async {
    final appState = context.read<AppState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appState.tr('delete_trip_confirm_title')),
        content: Text(appState.tr('delete_trip_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(appState.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(appState.tr('delete_trip')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('sessions')
          .delete()
          .eq('id', session.id);

      if (!mounted) return;

      final removedSections = _sections[session.id] ?? [];
      final removedMiles = removedSections.fold<double>(
          0.0, (acc, s) => acc + s.totalMiles);
      final removedDuration = removedSections.fold<int>(
          0, (acc, s) => acc + s.effectiveDurationSeconds);

      setState(() {
        _sessions.removeAt(index);
        _sections.remove(session.id);
        _totalMiles -= removedMiles;
        _totalDurationSeconds -= removedDuration;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.tr('delete_trip_success'))),
      );
    } catch (e) {
      debugPrint('[HistoryScreen] Delete trip error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${appState.tr('error')}: $e'),
            backgroundColor: Colors.red.shade700),
      );
    }
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    return "${d.inHours}h ${d.inMinutes.remainder(60)}m";
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final labelCol = isDark ? Colors.white38 : const Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(appState.tr('history').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadHistory();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded, size: 48, color: labelCol),
                      const SizedBox(height: 12),
                      Text(appState.tr('no_data'), style: TextStyle(color: labelCol, fontSize: 15)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // BUG FIX: _totalMiles/_totalDurationSeconds/_firstStart/
                    // _lastEnd (30-day accumulators, kept in sync even on
                    // delete -- see _loadHistory/the delete handler) were
                    // computed and maintained but never actually rendered
                    // anywhere (flutter analyze: unused_field on all 4).
                    // This is real, already-correct data that just never
                    // got a UI -- adding the summary rather than deleting
                    // the state that was carefully kept accurate.
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderCol),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 18, color: labelCol),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  appState.tr('last_12_months'),
                                  style: TextStyle(fontSize: 12, color: labelCol, fontWeight: FontWeight.w600),
                                ),
                                if (_firstStart != null && _lastEnd != null)
                                  Text(
                                    '${DateFormat('MMM d').format(_firstStart!.toLocal())} - ${DateFormat('MMM d').format(_lastEnd!.toLocal())}',
                                    style: TextStyle(fontSize: 10.5, color: labelCol),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${_totalMiles.toStringAsFixed(1)} mi',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatDuration(_totalDurationSeconds),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: _sessions.length,
                        itemBuilder: (context, index) {
                    final session = _sessions[index];
                    final sections = _sections[session.id] ?? [];
                    final isExpanded = _expandedSessions[session.id] ?? false;

                    // ── DIVISOR DE MES (pedido explícito: agrupar por mes,
                    // ej. "August", con todas sus sesiones debajo) ──
                    final currentMonth = session.startTime != null
                        ? DateFormat('MMMM yyyy').format(session.startTime!.toLocal())
                        : '';
                    final previousMonth = index > 0 && _sessions[index - 1].startTime != null
                        ? DateFormat('MMMM yyyy').format(_sessions[index - 1].startTime!.toLocal())
                        : '';
                    final showMonthDivider = index == 0 || currentMonth != previousMonth;

                    // ── DIVISOR DIARIO ──
                    final currentDate = session.startTime != null
                        ? DateFormat('EEEE, MMMM d, yyyy').format(session.startTime!)
                        : '';

                    final previousDate = index > 0 && _sessions[index - 1].startTime != null
                        ? DateFormat('EEEE, MMMM d, yyyy').format(_sessions[index - 1].startTime!)
                        : '';

                    final showDateDivider = index == 0 || currentDate != previousDate;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showMonthDivider)
                          Padding(
                            padding: EdgeInsets.only(top: index == 0 ? 4 : 28, bottom: 10),
                            child: Row(
                              children: [
                                Text(
                                  currentMonth.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Divider(color: borderCol, thickness: 1.4)),
                              ],
                            ),
                          ),
                        if (showDateDivider)
                          Padding(
                            padding: const EdgeInsets.only(top: 24, bottom: 8, left: 4),
                            child: Text(
                              currentDate.toUpperCase(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              ),
                            ),
                          ),

                        // Sesión
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderCol),
                            boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            children: [
                              // Header de sesión (sin cambios)
                              InkWell(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                onTap: () => setState(() => _expandedSessions[session.id] = !isExpanded),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(color: const Color(0xFF475569).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                            child: const Icon(Icons.route_rounded, color: Color(0xFF475569), size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Trip ${index + 1}  ·  ${session.startTime != null ? DateFormat('MM/dd hh:mm a').format(session.startTime!) : '--'}',
                                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                                                const SizedBox(height: 2),
                                                Text('End: ${session.endTime != null ? DateFormat('hh:mm a').format(session.endTime!) : '--'}',
                                                    style: TextStyle(fontSize: 11, color: labelCol)),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline_rounded,
                                                size: 20, color: Colors.red.shade400),
                                            tooltip: appState.tr('delete_trip'),
                                            onPressed: () => _confirmDeleteTrip(session, index),
                                          ),
                                          Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: labelCol),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          _buildInfoChip(icon: Icons.speed_rounded, label: '${appState.useMetricSystem ? (session.totalMiles * 1.60934).toStringAsFixed(2) : session.totalMiles.toStringAsFixed(2)} ${appState.useMetricSystem ? appState.tr('kilometer_short') : appState.tr('mile_short')}', isDark: isDark),
                                          const SizedBox(width: 8),
                                          _buildInfoChip(icon: Icons.timer_outlined, label: _formatDuration(session.effectiveDurationSeconds ?? 0), isDark: isDark),
                                          const SizedBox(width: 8),
                                          _buildInfoChip(icon: Icons.apps_rounded, label: '${sections.length} section${sections.length != 1 ? 's' : ''}', isDark: isDark),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              if (isExpanded && sections.isNotEmpty) ...[
                                Divider(height: 1, color: borderCol),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                                        child: Text('SECTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: labelCol)),
                                      ),
                                      ...sections.map((section) => _buildSectionRow(section, appState, isDark)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }

  // Métodos auxiliares (sin cambios)
  Widget _buildInfoChip({required IconData icon, required String label, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF475569)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
        ],
      ),
    );
  }

  Widget _buildSectionRow(SessionSection section, AppState appState, bool isDark) {
    final app = _getAppInfo(section.gigApp);
    final appColor = app.color;
    double secMiles = section.totalMiles;
    String unit = appState.useMetricSystem ? "km" : "mi";
    if (appState.useMetricSystem) secMiles *= 1.60934;

    final secDur = section.effectiveDurationSeconds;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: appColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: appColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(app.icon, color: appColor, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BUG FIX (pedido explícito): irs_purpose se guardaba
                    // pero nunca se mostraba acá -- un viaje "Custom/Truck"
                    // sin su propósito visible no sirve para validar la
                    // deducción ante una autoridad, que es justo para lo que
                    // existe este campo.
                    Text(
                      IrsPurposeCatalog.labelKeyFor(section.irsPurpose) != null
                          ? '${app.name} · ${appState.tr(IrsPurposeCatalog.labelKeyFor(section.irsPurpose)!)}'
                          : app.name,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: appColor),
                    ),
                    Text(DateFormat('hh:mm a').format(section.startTime), style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : const Color(0xFF64748B))),
                  ],
                ),
              ),
              _buildSectionStat('${secMiles.toStringAsFixed(2)} $unit', Icons.speed_rounded, appColor),
              const SizedBox(width: 8),
              _buildSectionStat(_formatDuration(secDur), Icons.timer_outlined, appColor),
            ],
          ),
          // ── Nota (pedido explícito): jamás edita millas, solo texto
          // libre de contexto — ver _editNote() y migración
          // session_sections_add_notes.
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _editNote(section),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    (section.notes ?? '').isEmpty
                        ? Icons.note_add_rounded
                        : Icons.sticky_note_2_rounded,
                    size: 13,
                    color: appColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      (section.notes ?? '').isEmpty
                          ? appState.tr('add_note')
                          : section.notes!,
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: (section.notes ?? '').isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                        color: appColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionStat(String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}