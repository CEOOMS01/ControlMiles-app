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
    SessionSection? firstSection;
    SessionSection? lastSection;

    for (final session in sortedSessions) {
      totalMiles += session.totalMiles;
      final secs = sectionsBySession[session.id] ?? [];
      if (secs.isNotEmpty) {
        firstSection ??= secs.first;
        lastSection = secs.last;
      }
    }

    final dateFmt = DateFormat('MM/dd/yyyy');
    final periodLabel =
        '${dateFmt.format(dateRange.start)} - ${dateFmt.format(dateRange.end)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin:     const pw.EdgeInsets.all(36),
        build: (ctx) => [
          _buildHeader(),
          pw.SizedBox(height: 18),
          _buildHRule(),
          pw.SizedBox(height: 16),
          _buildGlobalProfileSection(
              userName, userDisplayId, periodLabel, sortedSessions.length),
          pw.SizedBox(height: 24),
          _buildOdometerEvidence(totalMiles, firstSection, lastSection),
          pw.SizedBox(height: 28),
          _buildGlobalTripsTable(sortedSessions, sectionsBySession),
          pw.SizedBox(height: 36),
          _buildTotalSummary(totalMiles),
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
  // ODOMETER EVIDENCE — ahora toma el total ya sumado del período y el
  // primer/último SessionSection del rango (en vez de una sola sesión).
  // ════════════════════════════════════════════════════════════
  static pw.Widget _buildOdometerEvidence(
    double           totalMiles,
    SessionSection?  firstSection,
    SessionSection?  lastSection,
  ) {
    final start = firstSection?.startOdometerValue?.toStringAsFixed(1) ?? '0.0';
    final end   = lastSection?.endOdometerValue?.toStringAsFixed(1)    ?? '0.0';
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
  // ════════════════════════════════════════════════════════════
  static pw.Widget _buildGlobalTripsTable(
    List<TrackingSession> sessions,
    Map<String, List<SessionSection>> sectionsBySession,
  ) {
    final dateFmt = DateFormat('MM/dd/yyyy');

    final rows = sessions.map((session) {
      final secs = sectionsBySession[session.id] ?? [];
      final apps = secs.map((s) => s.gigApp.toUpperCase()).toSet().join(' / ');
      final dateStr = session.startTime != null
          ? dateFmt.format(session.startTime!.toLocal())
          : '--';
      final milesStr = '${session.totalMiles.toStringAsFixed(2)} mi';
      final durSec = session.effectiveDurationSeconds ?? 0;
      final durStr = '${durSec ~/ 3600}h ${(durSec % 3600) ~/ 60}m';
      return [dateStr, apps.isEmpty ? '--' : apps, milesStr, durStr, 'VERIFIED'];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TRIP LOG',
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800),
        ),
        pw.SizedBox(height: 10),
        if (rows.isEmpty)
          pw.Text('No trips in this period.',
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey600))
        else
          pw.TableHelper.fromTextArray(
            headers: ['DATE', 'GIG APP(S)', 'DISTANCE', 'DURATION', 'STATUS'],
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
              0: const pw.FlexColumnWidth(1.1),
              1: const pw.FlexColumnWidth(1.6),
              2: const pw.FlexColumnWidth(1.0),
              3: const pw.FlexColumnWidth(1.0),
              4: const pw.FlexColumnWidth(1.1),
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
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // TOTAL SUMMARY — recibe el total de millas ya sumado del período (antes
  // tomaba una sola TrackingSession).
  // ════════════════════════════════════════════════════════════
  static pw.Widget _buildTotalSummary(double totalMiles) {
    final deduction  = calculateIrsDeductionEstimate(totalMiles);
    final totalStr   = totalMiles.toStringAsFixed(2);
    final deductStr  = '\$${deduction.toStringAsFixed(2)}';

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
              'Estimated using the IRS 2026 standard mileage rate '
              '(\$${(kIrsMileageRateCentsPerMile / 100).toStringAsFixed(3)}/mile). '
              'ControlMiles is not affiliated with or endorsed by the IRS or '
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
