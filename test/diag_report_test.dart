import 'package:flutter_test/flutter_test.dart';

import 'package:controlmiles/services/diag_report.dart';

// A trip over I-95 through the Fort McHenry Tunnel, written the way DiagLog writes it
// (shape taken from the 2026-11-24 diagnostic; the start is a made-up place).
const _tunnelTrip = '''
2026-11-24T13:51:34.968908 [ui:f450] auto-start app=custom
2026-11-24T13:51:34.968908 [ui:f450] trip started session=afbeb903 app=custom auto=true
2026-11-24T13:51:37.000000 [ui:f450] engine start enabled=true trip=true
2026-11-24T13:51:38.000000 [ui:f450] trip start point from=parking meters=211
2026-11-24T14:07:13.000000 [ui:f450] fix lat=39.267 lng=-76.600 v=7.8 acc=4 mock=false state=running
2026-11-24T14:07:34.000000 [ui:f450] fix lat=39.266 lng=-76.598 v=11.4 acc=4 mock=false state=running
2026-11-24T14:08:04.000000 [ui:f450] miles add=0.012 section=5.414
2026-11-24T14:08:36.000000 [ui:f450] fix lat=39.264 lng=-76.590 v=4.7 acc=4 mock=false state=running
2026-11-24T14:12:39.000000 [ui:f450] fix lat=39.264 lng=-76.566 v=16.9 acc=5 mock=false state=running
2026-11-24T14:12:39.000000 [ui:f450] miles add=1.240 section=6.909
2026-11-24T14:13:00.000000 [ui:f450] tick rejected why=Impossible acceleration
2026-11-24T14:13:00.500000 [ui:f450] fix lat=39.266 lng=-76.562 v=21.2 acc=4 mock=false state=running
2026-11-24T14:24:37.000000 [ui:f450] trip still for 5 minutes: closing it
2026-11-24T14:24:40.000000 [ui:f450] trip stopped discarded=false miles=10.367
2026-11-24T14:25:41.000000 [ui:f450] engine released
2026-11-24T14:31:49.000000 [ui:a8ce] startup steps=before_runApp=4,dates_ready=6 unit=ms
2026-11-24T14:32:00.000000 [ui:a8ce] fix lat=39.300 lng=-76.600 v=0.0 acc=4 mock=false state=idle
2026-11-24T14:33:00.000000 [ui:a8ce] billing server answered product=premium http=500 quiet=false
''';

const _zone = GpsZone(
  name: 'Fort McHenry Tunnel (I-95)',
  kind: 'tunnel',
  lat: 39.2624,
  lng: -76.5781,
  radiusM: 1200,
);

void main() {
  test('the report is far shorter than the raw log and keeps what matters', () {
    final report = DiagReport.build(
      _tunnelTrip,
      appVersion: '1.3.38+78',
      device: 'test',
      zones: const [_zone],
    );

    expect(report.length, lessThan(_tunnelTrip.length));
    expect(report, contains('CONTROLMILES DIAGNOSTIC  app 1.3.38+78'));
    expect(
      report,
      contains('Trips: 1 (1 saved, 0 discarded or unfinished), 10.4 mi saved'),
    );
    expect(
      report,
      contains(
        '13:51-14:24 (33 min)  10.4 mi  custom auto, start from parking, session afbeb903',
      ),
    );
    // No per-fix lines, no engine noise.
    expect(report, isNot(contains('fix lat=')));
    expect(report, isNot(contains('engine ')));
  });

  test(
    'a GPS gap while moving is named when it falls in a known zone, with the miles the app counted',
    () {
      final report = DiagReport.build(
        _tunnelTrip,
        appVersion: 'v',
        device: 'd',
        zones: const [_zone],
      );
      expect(report, contains('GPS GAP 14:08-14:12 (4 min 3 s)'));
      expect(report, contains('1.24 mi counted'));
      expect(report, contains('Fort McHenry Tunnel (I-95)'));
      expect(report, isNot(contains('UNNAMED GPS GAPS')));
    },
  );

  test(
    'without a zone the same gap is listed as unnamed with its coordinates, so it can be named later',
    () {
      final report = DiagReport.build(
        _tunnelTrip,
        appVersion: 'v',
        device: 'd',
      );
      expect(report, contains('unnamed place'));
      expect(report, contains('UNNAMED GPS GAPS'));
      expect(report, contains('39.264,-76.590 > 39.264,-76.566'));
    },
  );

  test('a stop at a red light is not a gap (silent but it did not move)', () {
    const light = '''
2026-11-24T10:00:00.000000 [ui:aaaa] trip started session=s1 app=custom auto=true
2026-11-24T10:01:00.000000 [ui:aaaa] fix lat=39.300 lng=-76.600 v=3.0 acc=4 mock=false state=running
2026-11-24T10:04:00.000000 [ui:aaaa] fix lat=39.300 lng=-76.600 v=0.1 acc=4 mock=false state=running
2026-11-24T10:10:00.000000 [ui:aaaa] trip stopped discarded=false miles=1.0
''';
    final report = DiagReport.build(light, appVersion: 'v', device: 'd');
    expect(report, contains('GPS gaps while moving: 0'));
    expect(report, isNot(contains('GPS GAP ')));
  });

  test(
    'rejected ticks are counted and lines the report does not know are kept',
    () {
      final report = DiagReport.build(
        _tunnelTrip,
        appVersion: 'v',
        device: 'd',
      );
      expect(report, contains('Rejected ticks: 1 Impossible acceleration'));
      expect(report, contains('OTHER EVENTS'));
      expect(
        report,
        contains('billing server answered product=premium http=500'),
      );
    },
  );

  test('discarded trips are marked and an empty log does not crash', () {
    const discarded = '''
2026-11-24T14:33:29.000000 [ui:a8ce] trip started session=fc570519 app=custom auto=true
2026-11-24T14:39:35.000000 [ui:a8ce] trip stopped discarded=true miles=0.306
''';
    expect(
      DiagReport.build(discarded, appVersion: 'v', device: 'd'),
      contains('DISCARDED'),
    );
    expect(
      DiagReport.build('', appVersion: 'v', device: 'd'),
      contains('Trips: 0'),
    );
  });
}
