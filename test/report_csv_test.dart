import 'package:controlmiles/data/irs_rates.dart';
import 'package:controlmiles/models/session_section.dart';
import 'package:controlmiles/models/tracking_session.dart';
import 'package:controlmiles/models/vehicle.dart';
import 'package:controlmiles/services/report_service.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';

const _header = 'Date,Start time,End time,Duration,Category,App,Start address,End address,Miles,Rate,Value,'
    'Vehicle,Odometer start,Odometer end,Notes,Trip ID';

final _range = DateTimeRange(start: DateTime(2026, 11, 1), end: DateTime(2026, 11, 30));

TrackingSession _trip(String id, DateTime start, {double miles = 0, String? vehicleId, double? odoStart, double? odoEnd}) =>
    TrackingSession(
      id: id,
      userId: 'u',
      startTime: start,
      endTime: start.add(const Duration(minutes: 14)),
      totalMiles: miles,
      isClosed: true,
      vehicleId: vehicleId,
      startOdometerValue: odoStart,
      endOdometerValue: odoEnd,
    );

SessionSection _segment(
  String sessionId,
  String app,
  DateTime start,
  double miles, {
  String? from,
  String? to,
  String? purpose,
  String? notes,
}) =>
    SessionSection(
      id: '$sessionId-$app',
      sessionId: sessionId,
      userId: 'u',
      gigApp: app,
      status: 'closed',
      startTime: start,
      endTime: start.add(const Duration(minutes: 5)),
      totalMiles: miles,
      totalDurationSeconds: 3725,
      irsPurpose: purpose,
      startAddress: from,
      endAddress: to,
      notes: notes,
    );

String _csv(
  List<TrackingSession> trips,
  Map<String, List<SessionSection>> segments, {
  String method = 'standard',
  List<Vehicle> vehicles = const [],
  double? checkpointStart,
  double? checkpointEnd,
}) =>
    ReportService.buildCsv(
      sessions: trips,
      sectionsBySession: segments,
      dateRange: _range,
      mileageMethod: method,
      vehiclesUsed: vehicles,
      periodCheckpointStart: checkpointStart,
      periodCheckpointEnd: checkpointEnd,
    );

List<String> _lines(String csv) => csv.split('\r\n')..removeLast();

void main() {
  final t = DateTime(2026, 11, 8, 18, 4);

  test('a trip with two gig apps has one line per app, each with its own addresses', () {
    final csv = _csv([
      _trip('abcdef123456', t, miles: 4.226),
    ], {
      'abcdef123456': [
        _segment('abcdef123456', 'uber', t.add(const Duration(minutes: 5)), 3.303, from: 'B Street', to: 'C Street'),
        _segment('abcdef123456', 'roadie', t, 0.923, from: 'A Street', to: 'B Street'),
      ],
    });

    final lines = _lines(csv);
    expect(lines.first, _header);
    expect(lines, hasLength(3));

    final rate = ratePerMileCentsForPurpose('business', t) / 100;
    expect(
      lines[1],
      '2026-11-08,18:04,18:09,1:02:05,Business,Roadie,A Street,B Street,0.92,${rate.toStringAsFixed(3)},'
      '${(0.923 * rate).toStringAsFixed(2)},,,,,ABCDEF12',
    );
    expect(lines[2], startsWith('2026-11-08,18:09,18:14,1:02:05,Business,Uber,B Street,C Street,3.30,'));
  });

  test('a General trip uses the category the driver picked and its rate', () {
    final lines = _lines(_csv([
      _trip('t1', t),
    ], {
      't1': [_segment('t1', 'custom', t, 10, purpose: 'charitable')],
    }));
    final rate = ratePerMileCentsForPurpose('charitable', t) / 100;
    expect(lines[1], contains(',General,'));
    expect(lines[1], contains(',10.00,${rate.toStringAsFixed(3)},${(10 * rate).toStringAsFixed(2)},'));
  });

  test('commas, quotes and line breaks stay inside their cell', () {
    final lines = _lines(_csv([
      _trip('t1', t),
    ], {
      't1': [
        _segment('t1', 'roadie', t, 2, from: '219 Allendale St, Baltimore, MD', to: 'The "old" depot', notes: 'one\ntwo'),
      ],
    }).replaceAll('one\ntwo', 'one|two'));
    expect(lines[1], contains(',"219 Allendale St, Baltimore, MD","The ""old"" depot",'));
    expect(lines[1], contains('one|two'));

    final raw = _csv([
      _trip('t1', t),
    ], {
      't1': [_segment('t1', 'roadie', t, 2, notes: 'one\ntwo')],
    });
    expect(raw, contains('"one\ntwo"'));
  });

  test('text the driver typed cannot run as a spreadsheet formula', () {
    final lines = _lines(_csv([
      _trip('t1', t),
    ], {
      't1': [
        _segment('t1', 'roadie', t, 2, from: '=HYPERLINK("http://x","y")', to: '@SUM(A1)', notes: '-1+1'),
      ],
    }));
    expect(lines[1], contains(',"\'=HYPERLINK(""http://x"",""y"")",\'@SUM(A1),'));
    expect(lines[1], contains(",'-1+1,"));
  });

  test('unknown addresses are empty cells, and actual expenses have no rate or value', () {
    final lines = _lines(_csv([
      _trip('t1', t),
    ], {
      't1': [_segment('t1', 'roadie', t, 2)],
    }, method: 'actual'));
    expect(lines[1], contains(',Roadie,,,2.00,,,'));
  });

  test('a legacy trip with no segments keeps one line, priced as business', () {
    final lines = _lines(_csv([_trip('t1', t, miles: 7.5)], const {}));
    final rate = ratePerMileCentsForPurpose('business', t) / 100;
    expect(lines, hasLength(2));
    expect(lines[1], contains(',7.50,${rate.toStringAsFixed(3)},${(7.5 * rate).toStringAsFixed(2)},'));
  });

  test('a segment with no miles is left out', () {
    final lines = _lines(_csv([
      _trip('t1', t),
    ], {
      't1': [_segment('t1', 'roadie', t, 0.005), _segment('t1', 'uber', t, 3)],
    }));
    expect(lines, hasLength(2));
    expect(lines[1], contains(',Uber,'));
  });

  test('oldest trip first; the odometer goes on the first and last lines only', () {
    final later = t.add(const Duration(days: 1));
    final trips = [
      _trip('later', later, miles: 3, odoStart: 200, odoEnd: 203),
      _trip('first', t, miles: 2, odoStart: 100, odoEnd: 102),
    ];
    final fromTrips = _lines(_csv(trips, const {}));
    expect(fromTrips[1], startsWith('2026-11-08,'));
    expect(fromTrips[1].split(',').sublist(12, 14), ['100', '']);
    expect(fromTrips[2].split(',').sublist(12, 14), ['', '203']);

    final fromCheckpoints = _lines(_csv(trips, const {}, checkpointStart: 90, checkpointEnd: 310));
    expect(fromCheckpoints[1].split(',')[12], '90');
    expect(fromCheckpoints[2].split(',')[13], '310');
  });

  test('the vehicle is named on each line', () {
    final lines = _lines(_csv([
      _trip('t1', t, miles: 2, vehicleId: 'v1'),
    ], const {}, vehicles: const [
      Vehicle(id: 'v1', ownerUserId: 'u', make: 'Toyota', model: 'Sienna', year: 2019),
    ]));
    expect(lines[1], contains(',2019 Toyota Sienna,'));
  });

  test('no trips is just the header', () {
    expect(_csv(const [], const {}), '$_header\r\n');
  });
}
