import 'dart:io';

import 'package:controlmiles/models/session_section.dart';
import 'package:controlmiles/models/tracking_session.dart';
import 'package:controlmiles/models/vehicle.dart';
import 'package:controlmiles/services/report_service.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the report builds in landscape, for few and for many trips', () async {
    final vehicles = [
      const Vehicle(id: 'v1', ownerUserId: 'u', make: 'Toyota', model: 'Sienna', year: 2019, odometer: 209354),
      const Vehicle(id: 'v2', ownerUserId: 'u', make: 'Honda', model: 'Civic', odometer: 80100),
    ];
    final sessions = <TrackingSession>[];
    final sections = <String, List<SessionSection>>{};
    const purposes = ['business', 'medical', 'personal', 'charitable', 'moving', null];
    for (var i = 0; i < 45; i++) {
      final start = DateTime(2026, 9, 1 + i % 28, 8 + i % 10, 15);
      final id = 's$i';
      sessions.add(TrackingSession(
        id: id,
        userId: 'u',
        startTime: start,
        endTime: start.add(const Duration(minutes: 40)),
        totalMiles: 5.0 + i,
        isClosed: true,
        vehicleId: i % 7 == 0 ? null : (i.isEven ? 'v1' : 'v2'),
        startOdometerValue: 206637.0 + i * 10,
        endOdometerValue: 206645.0 + i * 10,
      ));
      sections[id] = [
        SessionSection(
          id: 'c$i',
          sessionId: id,
          userId: 'u',
          gigApp: i % 3 == 0 ? 'roadie' : 'custom',
          startTime: start,
          endTime: start.add(const Duration(minutes: 40)),
          totalMiles: 5.0 + i,
          irsPurpose: purposes[i % purposes.length],
          startAddress: '219 Allendale St, Baltimore, MD 21229, United States',
          endAddress: '2420 W Lexington St, Baltimore, MD 21223, United States',
        ),
        // Every fifth trip switched gig app twice: three segments, each with its own addresses.
        if (i % 5 == 1)
          for (final (k, app, from, to) in [
            (1, 'roadie', '2420 W Lexington St, Baltimore, MD 21223', '1200 Light St, Baltimore, MD 21230'),
            (2, 'doordash', '1200 Light St, Baltimore, MD 21230', '4607 Coleherne Rd, Baltimore, MD 21229'),
          ])
            SessionSection(
              id: 'c${i}_$k',
              sessionId: id,
              userId: 'u',
              gigApp: app,
              startTime: start.add(Duration(minutes: 40 * k)),
              endTime: start.add(Duration(minutes: 40 * k + 30)),
              totalMiles: 3.0 + k,
              startAddress: from,
              endAddress: to,
            ),
      ];
    }
    final range = DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 11, 6));
    for (final n in [1, 45]) {
      final bytes = await ReportService.buildGlobalReport(
        sessions: sessions.take(n).toList(),
        sectionsBySession: sections,
        dateRange: range,
        userName: 'Angel Soler',
        userDisplayId: 'cm-u1234',
        vehiclesUsed: vehicles,
        firstOdometerByVehicle: {'v1': (value: 206637, at: DateTime(2026, 9, 1))},
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      final dir = Platform.environment['REPORT_SHOT_DIR'];
      if (dir != null) File('$dir/report_$n.pdf').writeAsBytesSync(bytes);
    }
    final actual = await ReportService.buildGlobalReport(
      sessions: sessions.take(3).toList(),
      sectionsBySession: sections,
      dateRange: range,
      userName: 'A',
      userDisplayId: 'x',
      mileageMethod: 'actual',
    );
    expect(actual.isNotEmpty, isTrue);
    final empty = await ReportService.buildGlobalReport(
      sessions: const [],
      sectionsBySession: const {},
      dateRange: range,
      userName: 'A',
      userDisplayId: 'x',
    );
    expect(empty.isNotEmpty, isTrue);
  });
}
