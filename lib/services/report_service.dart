// Olympus Mont Systems LLC - ControlMiles
// lib/services/report_service.dart
// Generates the certified PDF matching the design reference.
// Uses only fields that exist in TrackingSession + SessionSection models.
//
// BUG FIX (pedido explícito): se eliminó la generación de PDF por sesión
// individual (generateCertifiedReport) — ahora solo existe el reporte
// global, que cubre el rango de fechas filtrado en Reports. Los widgets
// compartidos (header, regla, columna de perfil, evidencia de odómetro,
// resumen total) se reutilizan tal cual estaban, solo se generalizaron los
// que dependían de UNA sesión (ahora reciben totales ya calculados).
//
// El QR de "validación digital" del reporte por sesión apuntaba a
// verify/{sessionId} — un solo hash-chain de UNA sesión, concepto que no
// aplica a un documento con N sesiones. El plan real de verificación
// (QR -> portal web, usuario + PIN de 4 dígitos que el propio usuario
// gestiona) todavía no existe (ni la página, ni el PIN, ni el endpoint) —
// se deja pendiente a propósito en vez de mostrar un QR que hoy no lleva a
// ningún lado.

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../data/irs_rates.dart';
import '../models/tracking_session.dart';
import '../models/session_section.dart';
import '../models/gig_app.dart';
import '../models/vehicle.dart';

class ReportService {
  ReportService._();

  // ════════════════════════════════════════════════════════════
  // PUBLIC API — reporte global (único que existe)
  // TrackingSession fields available: id, userId, startTime, endTime,
  //   totalMiles, sessionHash, isClosed, dateKey, effectiveDurationSeconds
  // SessionSection fields available: id, sessionId, gigApp, status,
  //   startTime, endTime, totalMiles, totalDurationSeconds (int?),
  //   startOdometerValue, endOdometerValue, durationSeconds (getter)
  // ════════════════════════════════════════════════════════════
  static Future<void> generateGlobalReport({
    required List<TrackingSession> sessions,
    required Map<String, List<SessionSection>> sectionsBySession,
    required DateTimeRange dateRange,
    required String userName,
    required String userDisplayId,
    // IRS Fase 3 (2026-08-28): 'standard' or 'actual' -- doesn't change
    // any calculation (ControlMiles only ever computes standard-mileage
    // figures), just what the report's own disclaimer honestly states.
    String mileageMethod = 'standard',
    // BUG FIX (pedido explícito, 2026-08-28): el reporte nunca mostró qué
    // vehículo(s) se usaron ni con qué odómetro inicial arrancaron en
    // ControlMiles -- dato pedido explícitamente. Los vehículos vienen
    // resueltos por ReportsScreen a partir de los sessions.vehicle_id
    // realmente referenciados en el rango (ReportService no debe saber de
    // Supabase, mismo criterio que userName/userDisplayId más abajo).
    List<Vehicle> vehiclesUsed = const [],
  }) async {
    final pdf = pw.Document();

    // Orden cronológico (más antiguo primero) para que START/END del
    // odómetro tengan sentido narrativo (arranca en el primer viaje del
    // período, termina en el último).
    final sortedSessions = [...sessions]..sort((a, b) {
        final at = a.startTime ?? DateTime(0);
        final bt = b.startTime ?? DateTime(0);
        return at.compareTo(bt);
      });

    double totalMiles = 0;
    double totalDeduction = 0;
    // REAL BUG FOUND AND FIXED (2026-08-28, while adding IRS Fase 3):
    // this used to track SessionSection.startOdometerValue/
    // endOdometerValue -- fields that read from
    // map['start_odometer_value']/map['end_odometer_value'], columns
    // that DO NOT EXIST on session_sections (confirmed live against the
    // schema -- that table only has *_odometer_image_url). Every report
    // ever generated has shown "0.0" for both START and END in the
    // ODOMETER EVIDENCE block, always, silently -- the real numeric
    // values live on `sessions` (one capture per trip, not per gig-app
    // switch), which TrackingSession now maps correctly (see that
    // model's own comment). Tracks the first/last SESSION with a real
    // odometer value instead.
    TrackingSession? firstOdoSession;
    TrackingSession? lastOdoSession;

    // IRS Fase 3 (2026-08-28): real business-use classification, not
    // assumed. irs_purpose is a real category enum (IrsPurposeCatalog,
    // gig_app.dart) -- 'business' (now auto-tagged for every named gig
    // app, see tracking_controller.dart) or null (legacy sections from
    // before that fix -- always a named-gig-app trip historically, since
    // 'custom' mode has always required an explicit category choice, so
    // treated as business too) count as business miles; any of the other
    // real categories (personal/work/medical/moving/charitable/education)
    // are the non-deductible categories the IRS text itself lists.
    double businessMiles = 0;
    double nonBusinessMiles = 0;
    const nonBusinessPurposes = {
      'personal', 'work', 'medical', 'moving', 'charitable', 'education',
    };

    for (final session in sortedSessions) {
      totalMiles += session.totalMiles;
      // BUG FIX (2026-08-28): the IRS mileage rate changed mid-year (see
      // irs_rates.dart) -- pricing the whole period's miles at one flat
      // rate silently understated any report spanning Jul 1, 2026.
      // Falls back to the report's own end date only if a session
      // somehow has no startTime.
      totalDeduction += calculateIrsDeductionEstimate(
        session.totalMiles,
        session.startTime ?? dateRange.end,
      );
      if (session.startOdometerValue != null) {
        firstOdoSession ??= session;
      }
      if (session.endOdometerValue != null) {
        lastOdoSession = session;
      }
      // REAL BUG FOUND AND FIXED (2026-08-28, while verifying the report
      // on-device): a session with NO session_sections rows at all --
      // shown as "--" in the trip table, real and not rare, e.g. legacy
      // sessions from before per-section IRS-purpose tagging existed --
      // contributed nothing to businessMiles/nonBusinessMiles, so
      // ANNUAL BUSINESS-USE SUMMARY's own "TOTAL MILES" silently didn't
      // match the report's real Total Miles above it. Tracks how much of
      // this session's miles the sections actually accounted for, and
      // folds any leftover into business miles -- same "no purpose
      // recorded -> treated as business" precedent this file's header
      // comment already documents for legacy sections.
      final secs = sectionsBySession[session.id] ?? [];
      var sectionedMiles = 0.0;
      for (final sec in secs) {
        sectionedMiles += sec.totalMiles;
        if (nonBusinessPurposes.contains(sec.irsPurpose)) {
          nonBusinessMiles += sec.totalMiles;
        } else {
          businessMiles += sec.totalMiles;
        }
      }
      final unaccountedMiles = session.totalMiles - sectionedMiles;
      if (unaccountedMiles > 0) {
        businessMiles += unaccountedMiles;
      }
    }

    final businessUsePercent = totalMiles > 0 ? (businessMiles / totalMiles) * 100 : 0.0;

    final dateFmt = DateFormat('MM/dd/yyyy');
    final periodLabel =
        '${dateFmt.format(dateRange.start)} - ${dateFmt.format(dateRange.end)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin:     const pw.EdgeInsets.all(36),
        // REAL BUG FOUND AND FIXED (2026-08-28): TooManyPagesException was
        // never about report size -- reproduced and confirmed directly
        // against the installed pdf 3.12.0 package (see the standalone
        // repro used to diagnose this): pw.Flex (the base of pw.Column)
        // and pw.Table both hardcode `hasMoreWidgets => true` instead of
        // reporting real completion state. When a pw.Column wraps a title
        // + a pw.Table together as ONE top-level MultiPage child, and that
        // Column needs more than a single page to render (trivially true
        // once a trip log has more rows than fit on one page -- confirmed
        // with as few as 53 real trips from a blank page, not just a
        // near-boundary edge case), MultiPage's page-break loop can never
        // detect that the Column finished spanning and creates pages
        // forever. This only threw a catchable exception here because
        // Flutter debug builds run with asserts enabled (the pdf package's
        // own safety counter is assert-guarded) -- a release build would
        // have hung / grown memory unbounded instead, with no error at
        // all. Fix: the trip log's title and its pw.Table are now two
        // SEPARATE top-level list items below (see _buildTripLogTitle /
        // _buildGlobalTripsTableOnly) instead of one pw.Column wrapping
        // both -- confirmed via the same repro that this exact
        // "flat, unwrapped" shape renders correctly at any row count.
        // maxPages is deliberately left at its default (20): with the
        // structural fix, this report never needs anywhere near that many
        // pages, and a low ceiling is a better trip-wire for a future
        // regression than a raised one that only delays the same failure.
        build: (ctx) => [
          _buildHeader(),
          pw.SizedBox(height: 18),
          _buildHRule(),
          pw.SizedBox(height: 16),
          _buildGlobalProfileSection(
              userName, userDisplayId, periodLabel, sortedSessions.length),
          pw.SizedBox(height: 24),
          _buildVehicleInfo(vehiclesUsed),
          pw.SizedBox(height: 24),
          _buildOdometerEvidence(totalMiles, firstOdoSession, lastOdoSession),
          pw.SizedBox(height: 28),
          _buildTripLogTitle(),
          pw.SizedBox(height: 10),
          _buildGlobalTripsTableOnly(sortedSessions, sectionsBySession),
          pw.SizedBox(height: 36),
          _buildTotalSummary(totalMiles, totalDeduction, mileageMethod),
          pw.SizedBox(height: 20),
          _buildBusinessUseSummary(businessMiles, nonBusinessMiles, businessUsePercent),
          pw.SizedBox(height: 24),
          _buildHRule(),
          pw.SizedBox(height: 16),
          _buildGlobalValidationNote(),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'ControlMiles_Report_'
          '${DateFormat('yyyyMMdd').format(dateRange.start)}_'
          '${DateFormat('yyyyMMdd').format(dateRange.end)}.pdf',
    );
  }

  // ════════════════════════════════════════════════════════════
  // HEADER
  // ════════════════════════════════════════════════════════════
  static pw.Widget _buildHeader() {
    return pw.Row(
      mainAxisAlignment:  pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'ControlMiles CERTIFIED REPORT',
              style: pw.TextStyle(
                fontSize:   22,
                fontWeight: pw.FontWeight.bold,
                color:      PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Olympus Mont Systems LLC - Verify',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.Container(
          width:  54,
          height: 54,
          decoration: const pw.BoxDecoration(
            color: PdfColors.blue800,
            shape: pw.BoxShape.circle,
          ),
          child: pw.Center(
            child: pw.Text(
              'CM',
              style: pw.TextStyle(
                color:      PdfColors.white,
                fontSize:   20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildHRule() =>
      pw.Container(height: 0.5, color: PdfColors.grey400);

  // ════════════════════════════════════════════════════════════
  // PROFILE ROW (global — periodo + cantidad de viajes en vez de un
  // sessionId único)
  // ════════════════════════════════════════════════════════════
  static pw.Widget _buildGlobalProfileSection(
      String userName, String userDisplayId, String periodLabel, int tripCount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _profileCol('PROFILE',  userName.isEmpty ? '---' : userName),
        _profileCol('USER ID',  userDisplayId.toUpperCase()),
        _profileCol('PERIOD',   periodLabel),
        _profileCol('TRIPS',    '$tripCount'),
      ],
    );
  }

  static pw.Widget _profileCol(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 3),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // VEHICLE(S) USED — pedido explícito: qué vehículo(s) se usaron en el
  // período y con qué odómetro arrancaron en ControlMiles (Vehicle.odometer
  // -- la lectura capturada al dar de alta el vehículo, no la de un viaje
  // puntual, que ya se muestra en ODOMETER EVIDENCE más abajo). Normalmente
  // es un solo vehículo; si el usuario cambió de vehículo activo dentro del
  // rango del reporte, se listan todos con su propio odómetro inicial.
  // ════════════════════════════════════════════════════════════
  static pw.Widget _buildVehicleInfo(List<Vehicle> vehicles) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'VEHICLE(S) USED',
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800),
        ),
        pw.SizedBox(height: 10),
        if (vehicles.isEmpty)
          pw.Text('No vehicle associated with these trips.',
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey600))
        else
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              children: [
                for (var i = 0; i < vehicles.length; i++) ...[
                  if (i > 0) pw.Container(height: 0.5, color: PdfColors.grey300),
                  _vehicleRow(vehicles[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _vehicleRow(Vehicle vehicle) {
    final year = vehicle.year != null ? '${vehicle.year} ' : '';
    final name = vehicle.displayName.isEmpty ? '--' : vehicle.displayName;
    final startOdo = vehicle.odometer != null
        ? '${vehicle.odometer!.toStringAsFixed(1)} mi'
        : '--';

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$year$name',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.Text('Starting odometer (ControlMiles): $startOdo',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // ODOMETER EVIDENCE — toma el total ya sumado del período y la primera/
  // última SESIÓN del rango con un valor real de odómetro (no
  // SessionSection -- ver comentario en generateGlobalReport sobre el
  // bug real que esto corrige).
  // ════════════════════════════════════════════════════════════
  static pw.Widget _buildOdometerEvidence(
    double            totalMiles,
    TrackingSession?  firstOdoSession,
    TrackingSession?  lastOdoSession,
  ) {
    final start = firstOdoSession?.startOdometerValue?.toStringAsFixed(1) ?? '--';
    final end   = lastOdoSession?.endOdometerValue?.toStringAsFixed(1)    ?? '--';
    final total = totalMiles.toStringAsFixed(2);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ODOMETER EVIDENCE',
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(
            children: [
              _odoCell('START', start, isFirst: true),
              _odoCell('END',   end),
              _odoCell('TOTAL', total),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _odoCell(String header, String value,
      {bool isFirst = false}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: pw.BoxDecoration(
          border: isFirst
              ? null
              : const pw.Border(
                  left: pw.BorderSide(
                      color: PdfColors.grey300, width: 0.5)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(header,
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey500)),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text('units',
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // TRIP LOG — una fila condensada por sesión (no por sección) para no
  // producir un PDF de decenas de páginas en un rango de 3 meses. El
  // detalle de secciones por gig-app se resume como lista de apps usadas.
  //
  // BUG FIX (2026-08-28, TooManyPagesException): el título y la tabla
  // vivían juntos dentro de un solo pw.Column -- ver el comentario en
  // generateGlobalReport sobre por qué eso rompe MultiPage en cuanto el
  // log de viajes necesita más de una página. Separados en dos widgets de
  // nivel superior (título + tabla sola) para que MultiPage pagine la
  // tabla directamente, sin un Column intermedio.
  // ════════════════════════════════════════════════════════════
  static pw.Widget _buildTripLogTitle() {
    return pw.Text(
      'TRIP LOG',
      style: pw.TextStyle(
          fontSize: 12, fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue800),
    );
  }

  static pw.Widget _buildGlobalTripsTableOnly(
    List<TrackingSession> sessions,
    Map<String, List<SessionSection>> sectionsBySession,
  ) {
    final dateFmt = DateFormat('MM/dd/yyyy');

    final rows = sessions.map((session) {
      final secs = sectionsBySession[session.id] ?? [];
      // BUG FIX (pedido explícito): irs_purpose se guardaba correctamente
      // pero nunca aparecía en el PDF -- un tramo "Custom" mostraba solo
      // "CUSTOM" sin decir para qué (negocio/mudanza/personal/etc.), justo
      // el dato que una autoridad necesitaría para validar la deducción.
      // Dos tramos "custom" del mismo viaje con propósitos distintos
      // (ej. un switch de negocio a personal) se listan por separado, no
      // se colapsan en un solo "CUSTOM".
      final apps = secs.map((s) {
        final purposeLabel = IrsPurposeCatalog.plainLabelFor(s.irsPurpose);
        return purposeLabel.isEmpty
            ? s.gigApp.toUpperCase()
            : '${s.gigApp.toUpperCase()} ($purposeLabel)';
      }).toSet().join(' / ');
      final dateStr = session.startTime != null
          ? dateFmt.format(session.startTime!.toLocal())
          : '--';
      final milesStr = '${session.totalMiles.toStringAsFixed(2)} mi';
      final durSec = session.effectiveDurationSeconds ?? 0;
      final durStr = '${durSec ~/ 3600}h ${(durSec % 3600) ~/ 60}m';
      // IRS Fase 3 (2026-08-28): the odometer readings existed in the DB
      // and were already shown in the top-level evidence block, but never
      // per-trip in the actual table an auditor would read row by row.
      final startOdoStr = session.startOdometerValue?.toStringAsFixed(0) ?? '--';
      final endOdoStr = session.endOdometerValue?.toStringAsFixed(0) ?? '--';
      return [dateStr, apps.isEmpty ? '--' : apps, milesStr, durStr, startOdoStr, endOdoStr, 'VERIFIED'];
    }).toList();

    if (rows.isEmpty) {
      return pw.Text('No trips in this period.',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600));
    }

    return pw.TableHelper.fromTextArray(
      headers: ['DATE', 'GIG APP(S)', 'DISTANCE', 'DURATION', 'ODO START', 'ODO END', 'STATUS'],
      data:    rows,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color:      PdfColors.white,
        fontSize:   9,
      ),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColors.blue800),
      cellStyle:     const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(1.0),
        1: const pw.FlexColumnWidth(1.4),
        2: const pw.FlexColumnWidth(0.9),
        3: const pw.FlexColumnWidth(0.9),
        4: const pw.FlexColumnWidth(0.9),
        5: const pw.FlexColumnWidth(0.9),
        6: const pw.FlexColumnWidth(1.0),
      },
      oddRowDecoration:
          const pw.BoxDecoration(color: PdfColors.grey50),
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(
            color: PdfColors.grey200, width: 0.5),
        verticalInside: pw.BorderSide(
            color: PdfColors.grey200, width: 0.5),
      ),
      cellPadding: const pw.EdgeInsets.symmetric(
          horizontal: 6, vertical: 6),
    );
  }

  // ════════════════════════════════════════════════════════════
  // TOTAL SUMMARY — recibe el total de millas ya sumado del período (antes
  // tomaba una sola TrackingSession).
  // ════════════════════════════════════════════════════════════
  static pw.Widget _buildTotalSummary(double totalMiles, double totalDeduction, String mileageMethod) {
    final totalStr   = totalMiles.toStringAsFixed(2);
    final deductStr  = '\$${totalDeduction.toStringAsFixed(2)}';
    final methodStr  = mileageMethod == 'actual' ? 'Actual Expenses' : 'Standard Mileage Rate';

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text('Total Miles:',
                          style: const pw.TextStyle(fontSize: 12)),
                      pw.SizedBox(width: 24),
                      pw.Text(totalStr,
                          style: pw.TextStyle(
                              fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(height: 0.5, width: 160, color: PdfColors.grey400),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text('ESTIMATED DEDUCTION:',
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(width: 16),
                      pw.Text(deductStr,
                          style: pw.TextStyle(
                              fontSize:   14,
                              fontWeight: pw.FontWeight.bold,
                              color:      PdfColors.green800)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // BUG FIX (pedido explícito): esta cifra se mostraba como
          // "DEDUCTION:" en verde, sin ninguna aclaración — un documento
          // "certified report" que el usuario puede entregarle directo a su
          // contador o usar para declarar. Se renombró a "ESTIMATED
          // DEDUCTION:" y se agrega esta nota: la cifra usa la tarifa
          // pública del IRS, pero ControlMiles no es el IRS ni garantiza
          // que sea la deducción real que el usuario reciba.
          pw.SizedBox(height: 10),
          pw.SizedBox(
            width: 260,
            child: pw.Text(
              'Method: $methodStr. Estimated using the IRS 2026 standard mileage rates '
              '(\$${(kIrsMileageRateCentsPerMile2026H1 / 100).toStringAsFixed(3)}/mile '
              'Jan 1-Jun 30, \$${(kIrsMileageRateCentsPerMile2026H2 / 100).toStringAsFixed(2)}/mile '
              'Jul 1-Dec 31 — each trip priced at the rate in effect on its own '
              'date). ControlMiles is not affiliated with or endorsed by the IRS or '
              'any official agency. This is an informational estimate only, '
              'not a guaranteed deduction — consult a tax professional.',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // BUSINESS-USE SUMMARY (IRS Fase 3, 2026-08-28) — the annual-summary
  // fields the IRS recommends beyond the raw trip log: total miles split
  // by real classification (irs_purpose), and the business-use
  // percentage that split makes possible. See generateGlobalReport's own
  // comment for exactly how business vs. non-business is derived.
  // ════════════════════════════════════════════════════════════
  static pw.Widget _buildBusinessUseSummary(
    double businessMiles,
    double nonBusinessMiles,
    double businessUsePercent,
  ) {
    final totalMiles = businessMiles + nonBusinessMiles;
    if (totalMiles <= 0) return pw.SizedBox.shrink();

    pw.Widget stat(String label, String value) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 2),
            pw.Text(value,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ],
        );

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('ANNUAL BUSINESS-USE SUMMARY',
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800)),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              stat('TOTAL MILES', '${totalMiles.toStringAsFixed(2)} mi'),
              stat('BUSINESS MILES', '${businessMiles.toStringAsFixed(2)} mi'),
              stat('NON-BUSINESS MILES', '${nonBusinessMiles.toStringAsFixed(2)} mi'),
              stat('BUSINESS-USE %', '${businessUsePercent.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // NOTA DE CIERRE — reemplaza el QR de "validación digital" por sesión
  // (ver comentario de cabecera: ese concepto no aplica a un documento con
  // N sesiones, y el flujo real de verificación con QR + PIN de 4 dígitos
  // todavía no existe).
  // ════════════════════════════════════════════════════════════
  static pw.Widget _buildGlobalValidationNote() {
    return pw.Text(
      'Each trip listed above is individually timestamped and GPS-logged '
      'within the ControlMiles system.',
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
    );
  }
}
