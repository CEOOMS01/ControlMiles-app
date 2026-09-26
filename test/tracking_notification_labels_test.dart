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

  test('a real trip shows distance, gig app and the timer', () {
    final l = labels(trip: true);
    expect(l.title, 'ControlMiles · 12.4 mi');
    expect(l.body, 'Uber');
    expect(l.showTimer, isTrue);
  });

  test('a real trip in kilometres', () {
    expect(labels(trip: true, miles: 10, metric: true).title, 'ControlMiles · 16.1 km');
  });

  test('a trip whose app is not known yet still shows the timer', () {
    final l = labels(trip: true, app: null);
    expect(l.showTimer, isTrue);
    expect(l.body, kDefaultNotificationText);
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
