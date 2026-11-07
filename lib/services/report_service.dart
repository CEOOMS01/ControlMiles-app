// Olympus Mont Systems LLC - ControlMiles
// lib/services/report_service.dart
// The mileage report PDF.
//
// 2026-11-06: rebuilt in the style of the report drivers already know from
// other mileage apps -- A4 landscape, a header with the date range and rate on
// every page, a row of totals, a per-vehicle table (miles by category and the
// estimated deduction) and the trip log, one row per trip with full addresses.
// No maps and no photos: those live in the app and on controlmiles.com, so the
// PDF is quick to make and light to send. The odometer readings and the
// validation note stay, because they are what backs the report in an audit.
//
// The deduction follows each trip's category (see ratePerMileCentsForPurpose):
// business-group trips use the business rate, medical/moving and charity their
// own rates, personal ones nothing.
//
// Only the global report exists (one PDF for the date range chosen in Reports).

import 'dart:typed_data';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../data/irs_rates.dart';
import '../models/tracking_session.dart';
import '../models/session_section.dart';
import '../models/gig_app.dart';
import '../models/vehicle.dart';

/// Miles and money of one slice of a trip (a gig-app segment, or the miles no
/// segment accounts for).
class _Slice {
  _Slice(this.purpose, this.miles, this.cents);
  final String purpose; // effective purpose: 'business', 'medical', ...
  final double miles;
  final double cents; // value in cents
  double get dollars => cents / 100.0;
}

class ReportService {
  ReportService._();

  static const _businessGroup = {'business', 'delivery', 'errand', 'client', 'travel'};
  static const _personalGroup = {'personal', 'work', 'education'};

  static const _ink = PdfColor.fromInt(0xFF1C1812);
  static const _dim = PdfColor.fromInt(0xFF6B6455);
  static const _line = PdfColor.fromInt(0xFFC9DCEB);
  static const _headFill = PdfColor.fromInt(0xFFE6F1FB);
  static const _blue = PdfColor.fromInt(0xFF2C6C99);

  // ════════════════════════════════════════════════════════════
  // PUBLIC API
  // ════════════════════════════════════════════════════════════
  static Future<void> generateGlobalReport({
    required List<TrackingSession> sessions,
    required Map<String, List<SessionSection>> sectionsBySession,
    required DateTimeRange dateRange,
    required String userName,
    required String userDisplayId,
    // 'standard' or 'actual'. Doesn't change the miles; under 'actual' no dollar
    // estimate is shown, because miles alone can't price actual expenses.
    String mileageMethod = 'standard',
    List<Vehicle> vehiclesUsed = const [],
    // Weekly odometer checkpoint readings for the range (null = none).
    double? periodCheckpointStart,
    double? periodCheckpointEnd,
    // First odometer reading ever captured per vehicle (id -> value/date).
    Map<String, ({double value, DateTime? at})> firstOdometerByVehicle = const {},
    // Kept so callers don't change; route maps are no longer in the PDF.
    Map<String, String> mapTokens = const {},
  }) async {
    final bytes = await buildGlobalReport(
      sessions: sessions,
      sectionsBySession: sectionsBySession,
      dateRange: dateRange,
      userName: userName,
      userDisplayId: userDisplayId,
      mileageMethod: mileageMethod,
      vehiclesUsed: vehiclesUsed,
      periodCheckpointStart: periodCheckpointStart,
      periodCheckpointEnd: periodCheckpointEnd,
      firstOdometerByVehicle: firstOdometerByVehicle,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      format: PdfPageFormat.a4.landscape,
      name: 'ControlMiles_Report_'
          '${DateFormat('yyyyMMdd').format(dateRange.start)}_'
          '${DateFormat('yyyyMMdd').format(dateRange.end)}.pdf',
    );
  }

  /// The PDF as bytes (separate from printing so it can be tested).
  static Future<Uint8List> buildGlobalReport({
    required List<TrackingSession> sessions,
    required Map<String, List<SessionSection>> sectionsBySession,
    required DateTimeRange dateRange,
    required String userName,
    required String userDisplayId,
    String mileageMethod = 'standard',
    List<Vehicle> vehiclesUsed = const [],
    double? periodCheckpointStart,
    double? periodCheckpointEnd,
    Map<String, ({double value, DateTime? at})> firstOdometerByVehicle = const {},
  }) async {
    final isActual = mileageMethod == 'actual';

    // Oldest first, so the odometer starts at the first trip and ends at the last.
    final sorted = [...sessions]..sort((a, b) => (a.startTime ?? DateTime(0)).compareTo(b.startTime ?? DateTime(0)));

    // ── per trip: slices by category ─────────────────────────
    final slicesBySession = <String, List<_Slice>>{};
    TrackingSession? firstOdoSession;
    TrackingSession? lastOdoSession;
    var totalMiles = 0.0;
    var totalCents = 0.0;
    // Same split the report has always used for the business-use share.
    var businessUseMiles = 0.0;
    var nonBusinessUseMiles = 0.0;
    const nonBusinessUse = {'personal', 'work', 'medical', 'moving', 'charitable', 'education'};

    for (final s in sorted) {
      final tripMiles = _tripMiles(s, sectionsBySession);
      final secs = sectionsBySession[s.id] ?? const <SessionSection>[];
      final slices = <_Slice>[];
      var sectioned = 0.0;
      for (final sec in secs) {
        sectioned += sec.totalMiles;
        // Gig-app trips are business; a General trip uses the category picked.
        // A General trip not categorized yet is priced as business (as in My Trips).
        final purpose = (sec.gigApp == 'custom' ? sec.irsPurpose : 'business') ?? 'business';
        final rate = ratePerMileCentsForPurpose(purpose, sec.startTime);
        slices.add(_Slice(purpose, sec.totalMiles, sec.totalMiles * rate));
        if (nonBusinessUse.contains(sec.irsPurpose)) {
          nonBusinessUseMiles += sec.totalMiles;
        } else {
          businessUseMiles += sec.totalMiles;
        }
      }
      final left = tripMiles - sectioned;
      if (left > 0) {
        final at = s.startTime ?? dateRange.end;
        slices.add(_Slice('business', left, left * ratePerMileCentsForPurpose('business', at)));
        businessUseMiles += left;
      }
      slicesBySession[s.id] = slices;
      totalMiles += tripMiles;
      totalCents += slices.fold<double>(0, (a, x) => a + x.cents);
      if (s.startOdometerValue != null) firstOdoSession ??= s;
      if (s.endOdometerValue != null) lastOdoSession = s;
    }
    final totalDollars = totalCents / 100.0;
    final businessUsePercent =
        totalMiles > 0 ? ((businessUseMiles / totalMiles) * 100).clamp(0.0, 100.0).toDouble() : 0.0;

    // ── per vehicle ──────────────────────────────────────────
    final byVehicle = <String?, List<TrackingSession>>{};
    final known = {for (final v in vehiclesUsed) v.id};
    for (final s in sorted) {
      final id = (s.vehicleId != null && known.contains(s.vehicleId)) ? s.vehicleId : null;
      (byVehicle[id] ??= []).add(s);
    }

    final dateFmt = DateFormat('MMM d, yyyy');
    final rangeLabel = dateRange.start.year == dateRange.end.year &&
            dateRange.start.month == dateRange.end.month &&
            dateRange.start.day == dateRange.end.day
        ? dateFmt.format(dateRange.start)
        : '${dateFmt.format(dateRange.start)} - ${dateFmt.format(dateRange.end)}';

    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load('assets/images/logo_controlmiles.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      logo = null;
    }

    final businessRateLabel = _businessRateLabel(dateRange);
    final pdf = pw.Document(title: 'ControlMiles mileage report', author: 'ControlMiles');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        // The trip log's table is a flat top-level child (not wrapped in a
        // Column) so MultiPage can break it across pages: pw.Table/pw.Flex always
        // report "more to come" and would loop forever inside a wrapper.
        header: (ctx) => _pageHeader(logo, rangeLabel, businessRateLabel, isActual),
        footer: (ctx) => _pageFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 10),
          _profileRow(userName, userDisplayId, sorted.length, isActual),
          pw.SizedBox(height: 12),
          _sectionTitle('Report summary'),
          pw.SizedBox(height: 6),
          _summaryTiles(
            isActual: isActual,
            deduction: totalDollars,
            businessMiles: businessUseMiles,
            nonBusinessMiles: nonBusinessUseMiles,
            percent: businessUsePercent,
            totalMiles: totalMiles,
            drives: sorted.length,
          ),
          pw.SizedBox(height: 14),
          _sectionTitle('Vehicle summary'),
          pw.SizedBox(height: 6),
          _vehicleTable(
            byVehicle: byVehicle,
            vehicles: vehiclesUsed,
            slices: slicesBySession,
            sectionsBySession: sectionsBySession,
            firstOdometer: firstOdometerByVehicle,
            isActual: isActual,
          ),
          pw.SizedBox(height: 8),
          _odometerLine(totalMiles, firstOdoSession, lastOdoSession, periodCheckpointStart, periodCheckpointEnd),
          pw.SizedBox(height: 14),
          _sectionTitle('Trip log'),
          pw.SizedBox(height: 6),
          _tripTable(sorted, sectionsBySession, slicesBySession, isActual,
              startOdometer: periodCheckpointStart ?? firstOdoSession?.startOdometerValue,
              endOdometer: periodCheckpointEnd ?? lastOdoSession?.endOdometerValue),
          pw.SizedBox(height: 6),
          _reportTotals(totalMiles, totalDollars, isActual),
          pw.SizedBox(height: 14),
          _notes(isActual),
        ],
      ),
    );

    return pdf.save();
  }

  // ════════════════════════════════════════════════════════════
  // helpers
  // ════════════════════════════════════════════════════════════

  /// A trip's miles = the sum of its gig-app segments; the trip's own total only
  /// when it has no segments (some legacy trips stored only the last segment).
  static double _tripMiles(TrackingSession session, Map<String, List<SessionSection>> sectionsBySession) {
    final secs = sectionsBySession[session.id] ?? const <SessionSection>[];
    final sum = secs.fold<double>(0, (acc, x) => acc + x.totalMiles);
    return sum > 0 ? sum : session.totalMiles;
  }

  /// "$0.760/mi", or both rates when the range crosses the mid-year change.
  static String _businessRateLabel(DateTimeRange r) {
    final a = ratePerMileCentsForPurpose('business', r.start) / 100;
    final b = ratePerMileCentsForPurpose('business', r.end) / 100;
    String f(double v) => '\$${v.toStringAsFixed(3)}/mi';
    return (a - b).abs() < 1e-9 ? f(a) : '${f(a)} then ${f(b)}';
  }

  static String _money(double v) => NumberFormat.currency(symbol: '\$').format(v);
  static String _mi(double v) => '${v.toStringAsFixed(2)} mi';

  static pw.Widget _pageHeader(pw.MemoryImage? logo, String range, String rate, bool isActual) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: _pageHeaderBox(logo, range, rate, isActual),
    );
  }

  static pw.Widget _pageHeaderBox(pw.MemoryImage? logo, String range, String rate, bool isActual) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Mileage Report', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: _ink)),
              pw.SizedBox(height: 5),
              pw.Row(children: [
                _labelValue('Report date range', range),
                pw.SizedBox(width: 28),
                _labelValue('Business rate', isActual ? 'n/a (actual expenses)' : rate),
              ]),
            ],
          ),
          pw.Row(
            children: [
              pw.Text('ControlMiles', style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: _blue)),
              pw.SizedBox(width: 8),
              if (logo != null) pw.Image(logo, width: 30, height: 30),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _labelValue(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _dim)),
          pw.SizedBox(height: 1),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10, color: _ink)),
        ],
      );

  static pw.Widget _pageFooter(pw.Context ctx) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by ControlMiles - every mile, on the record. Each trip is individually timestamped and GPS-logged. '
            'Maps and photos for each trip are in the app and at controlmiles.com.',
            style: const pw.TextStyle(fontSize: 7, color: _dim),
          ),
          pw.Text('page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: _dim)),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String t) =>
      pw.Text(t, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink));

  static pw.Widget _profileRow(String name, String id, int trips, bool isActual) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _labelValue('Profile', name.isEmpty ? '---' : name),
          _labelValue('User ID', id.toUpperCase()),
          _labelValue('Trips', '$trips'),
          _labelValue('Method', isActual ? 'Actual expenses' : 'Standard mileage rate'),
        ],
      );

  static pw.Widget _summaryTiles({
    required bool isActual,
    required double deduction,
    required double businessMiles,
    required double nonBusinessMiles,
    required double percent,
    required double totalMiles,
    required int drives,
  }) {
    final tiles = <(String, String)>[
      ('Estimated deduction', isActual ? 'n/a' : _money(deduction)),
      ('Business miles', _mi(businessMiles)),
      ('Non-business miles', _mi(nonBusinessMiles)),
      ('Business use', '${percent.toStringAsFixed(1)}%'),
      ('Total distance', _mi(totalMiles)),
      ('Total drives', '$drives'),
    ];
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Row(
        children: [
          for (var i = 0; i < tiles.length; i++)
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.fromLTRB(12, 9, 8, 9),
                decoration: pw.BoxDecoration(
                  border: i == 0 ? null : const pw.Border(left: pw.BorderSide(color: _line, width: 0.8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(tiles[i].$1, style: const pw.TextStyle(fontSize: 8, color: _dim)),
                    pw.SizedBox(height: 3),
                    pw.Text(tiles[i].$2,
                        style: pw.TextStyle(
                            fontSize: 13, fontWeight: pw.FontWeight.bold, color: i == 0 && !isActual ? _blue : _ink)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Miles per category group for a set of trips.
  static Map<String, double> _groupMiles(List<TrackingSession> trips, Map<String, List<_Slice>> slices) {
    final m = <String, double>{'business': 0, 'personal': 0, 'medical': 0, 'moving': 0, 'charity': 0};
    for (final s in trips) {
      for (final x in slices[s.id] ?? const <_Slice>[]) {
        final key = _businessGroup.contains(x.purpose)
            ? 'business'
            : _personalGroup.contains(x.purpose)
                ? 'personal'
                : x.purpose == 'charitable'
                    ? 'charity'
                    : x.purpose; // medical, moving
        m[key] = (m[key] ?? 0) + x.miles;
      }
    }
    return m;
  }

  static pw.Widget _vehicleTable({
    required Map<String?, List<TrackingSession>> byVehicle,
    required List<Vehicle> vehicles,
    required Map<String, List<_Slice>> slices,
    required Map<String, List<SessionSection>> sectionsBySession,
    required Map<String, ({double value, DateTime? at})> firstOdometer,
    required bool isActual,
  }) {
    final odo = NumberFormat('#,##0');
    final headers = [
      'Vehicle', 'First odometer', 'Current odometer', 'Business', 'Personal', 'Medical', 'Moving', 'Charity',
      'Total distance', 'Est. deduction',
    ];
    final rows = <List<String>>[];
    var tBusiness = 0.0, tPersonal = 0.0, tMedical = 0.0, tMoving = 0.0, tCharity = 0.0, tTotal = 0.0, tMoney = 0.0;

    void addRow(String name, String first, String current, List<TrackingSession> trips) {
      final g = _groupMiles(trips, slices);
      final total = trips.fold<double>(0, (a, s) => a + _tripMiles(s, sectionsBySession));
      final money = trips.fold<double>(
          0, (a, s) => a + (slices[s.id] ?? const <_Slice>[]).fold<double>(0, (b, x) => b + x.dollars));
      tBusiness += g['business']!;
      tPersonal += g['personal']!;
      tMedical += g['medical']!;
      tMoving += g['moving']!;
      tCharity += g['charity']!;
      tTotal += total;
      tMoney += money;
      rows.add([
        name, first, current, _mi(g['business']!), _mi(g['personal']!), _mi(g['medical']!), _mi(g['moving']!),
        _mi(g['charity']!), _mi(total), isActual ? 'n/a' : _money(money),
      ]);
    }

    for (final v in vehicles) {
      final trips = byVehicle[v.id];
      if (trips == null) continue;
      final f = firstOdometer[v.id];
      final year = v.year != null ? '${v.year} ' : '';
      addRow(
        '$year${v.displayName.isEmpty ? '--' : v.displayName}',
        f != null ? odo.format(f.value) : '-',
        v.odometer != null ? odo.format(v.odometer!) : '-',
        trips,
      );
    }
    final none = byVehicle[null];
    if (none != null) addRow('No vehicle', '-', '-', none);

    rows.add([
      'Totals', '', '', _mi(tBusiness), _mi(tPersonal), _mi(tMedical), _mi(tMoving), _mi(tCharity), _mi(tTotal),
      isActual ? 'n/a' : _money(tMoney),
    ]);

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: _line, width: 0.6),
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _ink),
      headerDecoration: const pw.BoxDecoration(color: _headFill),
      cellStyle: const pw.TextStyle(fontSize: 8.5, color: _ink),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      cellAlignments: {
        for (var i = 1; i < headers.length; i++) i: pw.Alignment.centerRight,
      },
      headerAlignments: {
        for (var i = 1; i < headers.length; i++) i: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(2.4),
        for (var i = 1; i < headers.length; i++) i: const pw.FlexColumnWidth(1.25),
      },
    );
  }

  /// One compact line of odometer evidence (start / end / difference).
  static pw.Widget _odometerLine(
    double totalMiles,
    TrackingSession? firstOdoSession,
    TrackingSession? lastOdoSession,
    double? checkpointStart,
    double? checkpointEnd,
  ) {
    final startVal = checkpointStart ?? firstOdoSession?.startOdometerValue;
    final endVal = checkpointEnd ?? lastOdoSession?.endOdometerValue;
    final f = NumberFormat('#,##0.0');
    final diff = (startVal != null && endVal != null && endVal >= startVal) ? f.format(endVal - startVal) : '--';
    return pw.Text(
      'Odometer evidence:  start ${startVal != null ? f.format(startVal) : '--'} mi   ·   '
      'end ${endVal != null ? f.format(endVal) : '--'} mi   ·   odometer miles $diff',
      style: const pw.TextStyle(fontSize: 8.5, color: _dim),
    );
  }

  /// "Business", "Medical", ... for a trip; "Mixed" when its segments differ.
  static String _tripCategory(List<SessionSection> secs) {
    final labels = <String>{};
    for (final sec in secs) {
      final purpose = sec.gigApp == 'custom' ? sec.irsPurpose : 'business';
      final l = IrsPurposeCatalog.plainLabelFor(purpose);
      labels.add(l.isEmpty ? 'Not categorized' : l);
    }
    if (labels.isEmpty) return 'Business';
    return labels.length == 1 ? labels.first : 'Mixed';
  }

  static String _tripApps(List<SessionSection> secs) {
    final apps = <String>{for (final s in secs) s.gigApp == 'custom' ? 'General' : GigAppCatalog.byId(s.gigApp).name};
    return apps.isEmpty ? '--' : apps.join(' / ');
  }

  static pw.Widget _tripTable(
    List<TrackingSession> sorted,
    Map<String, List<SessionSection>> sectionsBySession,
    Map<String, List<_Slice>> slices,
    bool isActual, {
    double? startOdometer,
    double? endOdometer,
  }) {
    if (sorted.isEmpty) {
      return pw.Text('No trips in this period.', style: const pw.TextStyle(fontSize: 9, color: _dim));
    }
    final when = DateFormat('EEE, MMM d\nh:mm a');
    final odo = NumberFormat('#,##0');
    String addr(String? a) => (a == null || a.trim().isEmpty) ? '--' : a.trim();

    // One row per segment (a trip that switched gig app or category has one row for
    // each, with its own addresses, miles and value). A trip with no usable
    // segment keeps a single row.
    final rows = <List<String>>[];
    List<String> row({
      required DateTime? at,
      required String why,
      required String app,
      required String start,
      required String end,
      required double miles,
      required double money,
    }) =>
        [
          at != null ? when.format(at.toLocal()) : '--',
          why,
          app,
          start,
          end,
          isActual ? 'n/a' : '\$${(miles > 0 ? money / miles : 0.0).toStringAsFixed(3)}',
          _mi(miles),
          isActual ? 'n/a' : _money(money),
          '',
          '',
        ];

    for (final s in sorted) {
      final all = [...(sectionsBySession[s.id] ?? const <SessionSection>[])]
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      final tracked = all.where((x) => x.totalMiles >= 0.01).toList();
      if (tracked.isEmpty) {
        final miles = _tripMiles(s, sectionsBySession);
        final money = (slices[s.id] ?? const <_Slice>[]).fold<double>(0, (a, x) => a + x.dollars);
        rows.add(row(
          at: s.startTime,
          why: _tripCategory(all),
          app: _tripApps(all),
          start: all.isEmpty ? '--' : addr(all.first.startAddress),
          end: all.isEmpty ? '--' : addr(all.last.endAddress),
          miles: miles,
          money: money,
        ));
        continue;
      }
      for (final sec in tracked) {
        final purpose = (sec.gigApp == 'custom' ? sec.irsPurpose : 'business') ?? 'business';
        final money = sec.totalMiles * ratePerMileCentsForPurpose(purpose, sec.startTime) / 100.0;
        rows.add(row(
          at: sec.startTime,
          why: _tripCategory([sec]),
          app: _tripApps([sec]),
          start: addr(sec.startAddress),
          end: addr(sec.endAddress),
          miles: sec.totalMiles,
          money: money,
        ));
      }
    }

    // The odometer is read weekly or yearly, not per trip: the first row carries the
    // reading the period starts with, the last row the one it ends with.
    if (rows.isNotEmpty) {
      rows.first[8] = startOdometer != null ? odo.format(startOdometer) : '--';
      rows.last[9] = endOdometer != null ? odo.format(endOdometer) : '--';
    }

    const headers = ['When', 'Why', 'App', 'Start', 'End', 'Rate', 'Distance', 'Value', 'Odo start', 'Odo end'];
    const right = {5, 6, 7, 8, 9};
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.symmetric(
        inside: const pw.BorderSide(color: _line, width: 0.5),
        outside: const pw.BorderSide(color: _line, width: 0.8),
      ),
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _ink),
      headerDecoration: const pw.BoxDecoration(color: _headFill),
      cellStyle: const pw.TextStyle(fontSize: 8, color: _ink),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      cellAlignment: pw.Alignment.topLeft,
      cellAlignments: {for (final i in right) i: pw.Alignment.topRight},
      headerAlignments: {for (final i in right) i: pw.Alignment.centerRight},
      columnWidths: {
        0: const pw.FlexColumnWidth(1.25),
        1: const pw.FlexColumnWidth(1.0),
        2: const pw.FlexColumnWidth(1.0),
        3: const pw.FlexColumnWidth(3.0),
        4: const pw.FlexColumnWidth(3.0),
        5: const pw.FlexColumnWidth(0.9),
        6: const pw.FlexColumnWidth(1.0),
        7: const pw.FlexColumnWidth(1.0),
        8: const pw.FlexColumnWidth(0.95),
        9: const pw.FlexColumnWidth(0.95),
      },
    );
  }

  static pw.Widget _reportTotals(double miles, double dollars, bool isActual) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: const pw.BoxDecoration(color: _headFill, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text('Report totals', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _ink)),
          pw.SizedBox(width: 24),
          pw.Text(_mi(miles), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _ink)),
          pw.SizedBox(width: 24),
          pw.Text(isActual ? 'n/a' : _money(dollars),
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: isActual ? _ink : _blue)),
        ],
      ),
    );
  }

  static pw.Widget _notes(bool isActual) {
    final text = isActual
        ? 'Method: Actual Expenses. Under the actual-expense method the deduction is your vehicle costs '
            '(gas, repairs, insurance, depreciation...) times the business-use share of your miles; the business '
            'miles above are the evidence for that share. No dollar estimate is shown for this method. '
        : 'Method: Standard Mileage Rate. Values are estimated with the IRS 2026 standard mileage rates '
            '(\$${(kIrsMileageRateCentsPerMile2026H1 / 100).toStringAsFixed(3)}/mile Jan 1-Jun 30, '
            '\$${(kIrsMileageRateCentsPerMile2026H2 / 100).toStringAsFixed(2)}/mile Jul 1-Dec 31; medical and moving '
            '20.5/23.5 cents, charity 14 cents; personal, work and education trips add nothing), each trip priced at '
            'the rate in effect on its own date. ';
    // A Container (not a bare Column) cannot be split across pages: the notes stay together.
    return pw.Container(
      child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(height: 0.5, color: _line),
        pw.SizedBox(height: 6),
        pw.Text(
          '$text'
          'ControlMiles is not affiliated with or endorsed by the IRS or any official agency. This is an '
          'informational estimate only, not a guaranteed deduction - consult a tax professional.',
          style: pw.TextStyle(fontSize: 7, color: _dim, fontStyle: pw.FontStyle.italic),
        ),
      ],
      ),
    );
  }
}
