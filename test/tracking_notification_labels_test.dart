// With auto-detect armed the background service (and its notification) runs all
// day, long before any gig app is detected. The notification must say so
// honestly: no timer, no distance, nothing that looks like a recorded trip.

import 'package:flutter_test/flutter_test.dart';
import 'package:controlmiles/tracking/tracking_notification.dart';

TrackingNotificationLabels labels({
  bool trip = false,
  double miles = 12.44,
  bool metric = false,
  String? app = 'Uber',
}) =>
    trackingNotificationLabels(
      hasActiveTrip: trip,
      miles: miles,
      metric: metric,
      gigAppName: app,
      idleTitle: 'Automatic Detection',
      idleBody: 'Listening for a gig app to open...',
    );

void main() {
  test('armed with no trip says it is listening: no timer, no distance', () {
    final l = labels(trip: false);
    expect(l.title, 'Automatic Detection');
    expect(l.body, 'Listening for a gig app to open...');
    expect(l.showTimer, isFalse);
    // Nothing that looks like a running trip, whatever stale values exist.
    expect(l.title, isNot(contains('mi')));
    expect(l.body, isNot(contains('Uber')));
  });

  test('a real trip is fixed and minimal: no distance, no gig app, no timer', () {
    for (final metric in [false, true]) {
      final l = labels(trip: true, metric: metric);
      expect(l.title, 'ControlMiles');
      expect(l.body, kTripNotificationBody);
      expect(l.showTimer, isFalse);
      expect(l.title, isNot(contains('mi')));
      expect(l.body, isNot(contains('Uber')));
    }
  });

  test('the trip text does not change with the miles, so it is never re-posted', () {
    expect(labels(trip: true, miles: 1).title, labels(trip: true, miles: 99).title);
    expect(labels(trip: true, miles: 1).body, labels(trip: true, miles: 99).body);
  });

  test('a translated trip text is used, a blank one falls back', () {
    final t = trackingNotificationLabels(
      hasActiveTrip: true, miles: 3, metric: false, gigAppName: null,
      idleTitle: 'x', idleBody: 'y', tripBody: 'ControlMiles está registrando tu viaje',
    );
    expect(t.body, 'ControlMiles está registrando tu viaje');
    final blank = trackingNotificationLabels(
      hasActiveTrip: true, miles: 3, metric: false, gigAppName: null,
      idleTitle: 'x', idleBody: 'y', tripBody: '  ',
    );
    expect(blank.body, kTripNotificationBody);
  });

  test('missing translations fall back to the original texts, never blank', () {
    final l = trackingNotificationLabels(
      hasActiveTrip: false,
      miles: 0,
      metric: false,
      gigAppName: null,
      idleTitle: '  ',
      idleBody: '',
    );
    expect(l.title, kDefaultNotificationTitle);
    expect(l.body, kDefaultNotificationText);
    expect(l.showTimer, isFalse);
  });
}
