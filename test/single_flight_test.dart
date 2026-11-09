import 'dart:async';

import 'package:controlmiles/tracking/single_flight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a call made during a run shares it', () async {
    final flight = SingleFlight();
    final gate = Completer<void>();
    var runs = 0;
    Future<void> task() async {
      runs++;
      await gate.future;
    }

    final first = flight.run(task);
    final second = flight.run(task);
    gate.complete();
    await Future.wait([first, second]);
    expect(runs, 1);
  });

  test('a call after the run finished runs again', () async {
    final flight = SingleFlight();
    var runs = 0;
    await flight.run(() async => runs++);
    await flight.run(() async => runs++);
    expect(runs, 2);
  });

  test('a failed run does not block the next one', () async {
    final flight = SingleFlight();
    await expectLater(flight.run(() async => throw StateError('x')), throwsStateError);
    var ran = false;
    await flight.run(() async => ran = true);
    expect(ran, isTrue);
  });
}
