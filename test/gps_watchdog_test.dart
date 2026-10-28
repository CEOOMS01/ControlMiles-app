import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:controlmiles/tracking/gps_watchdog.dart';

void main() {
  group('verdict', () {
    test('GPS switched off wins over permission', () {
      expect(
        GpsWatchdog.verdict(serviceEnabled: false, permission: geo.LocationPermission.always),
        GpsVerdict.gpsOff,
      );
      expect(
        GpsWatchdog.verdict(serviceEnabled: false, permission: geo.LocationPermission.denied),
        GpsVerdict.gpsOff,
      );
    });

    test('permission taken away', () {
      for (final p in [geo.LocationPermission.denied, geo.LocationPermission.deniedForever]) {
        expect(GpsWatchdog.verdict(serviceEnabled: true, permission: p), GpsVerdict.permissionOff);
      }
    });

    test('GPS on with permission is ok', () {
      for (final p in [geo.LocationPermission.whileInUse, geo.LocationPermission.always]) {
        expect(GpsWatchdog.verdict(serviceEnabled: true, permission: p), GpsVerdict.ok);
      }
    });
  });

  group('shouldProbe (no signal)', () {
    final now = DateTime(2026, 10, 28, 8, 0);

    test('recent point: no probe', () {
      expect(
        GpsWatchdog.shouldProbe(now: now, lastAlive: now.subtract(const Duration(minutes: 2)), lastProbe: null),
        isFalse,
      );
    });

    test('3+ minutes of silence: probe', () {
      expect(
        GpsWatchdog.shouldProbe(now: now, lastAlive: now.subtract(const Duration(minutes: 4)), lastProbe: null),
        isTrue,
      );
    });

    test('does not probe again inside the same window', () {
      expect(
        GpsWatchdog.shouldProbe(
          now: now,
          lastAlive: now.subtract(const Duration(minutes: 10)),
          lastProbe: now.subtract(const Duration(minutes: 1)),
        ),
        isFalse,
      );
    });

    test('nothing known yet: no probe', () {
      expect(GpsWatchdog.shouldProbe(now: now, lastAlive: null, lastProbe: null), isFalse);
    });
  });
}
