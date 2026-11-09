// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/single_flight.dart
//
// Runs one task at a time: a call made while the task is running shares that run
// instead of starting another. Opening the app recovers the open trip from up to
// three places at once; two overlapping recoveries turned the GPS back on while
// the other one was closing the trip (2026-11-09).

class SingleFlight {
  Future<void>? _running;

  Future<void> run(Future<void> Function() task) =>
      _running ??= task().whenComplete(() => _running = null);
}
