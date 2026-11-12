import 'package:controlmiles/tracking/antifraud_engine.dart';
import 'package:flutter_test/flutter_test.dart';

// Real case, 2026-11-11 12:03-12:08: I-95 through the Fort McHenry tunnel at about
// 45 mph. GPS was lost for 85 s; every point after it was rejected as a jump and the
// trip closed as if parked.
void main() {
  setUp(AntifraudEngine.reset);

  AntifraudResult at(double lat, double lng, DateTime t, {double speed = 20, double acc = 4}) =>
      AntifraudEngine.evaluate(latitude: lat, longitude: lng, speed: speed, accuracy: acc, timestamp: t);

  test('driving out of a tunnel is accepted after the GPS gap', () {
    final t0 = DateTime(2026, 11, 11, 12, 3, 37);
    expect(at(39.2622, -76.5860, t0).isValid, isTrue);
    expect(at(39.2622, -76.5855, t0.add(const Duration(seconds: 2))).isValid, isTrue);
    // Inside the tunnel: two bad fixes, then nothing for 85 s.
    expect(at(39.2620, -76.5850, t0.add(const Duration(seconds: 4)), acc: 86).isValid, isFalse);
    // Out of the tunnel, 1.9 km further on: about 22 m/s, a normal highway speed.
    final out = t0.add(const Duration(seconds: 90));
    final first = at(39.2650, -76.5640, out, speed: 22);
    expect(first.isValid, isTrue, reason: first.reason);
    // And the next points keep counting.
    expect(at(39.2653, -76.5638, out.add(const Duration(seconds: 2)), speed: 22).isValid, isTrue);
  });

  test('a point 2 km away two seconds later is still a jump', () {
    final t0 = DateTime(2026, 11, 11, 12);
    expect(at(39.2622, -76.5860, t0).isValid, isTrue);
    final r = at(39.2650, -76.5640, t0.add(const Duration(seconds: 2)));
    expect(r.isValid, isFalse);
    expect(r.reason, 'Impossible movement jump');
  });
}
