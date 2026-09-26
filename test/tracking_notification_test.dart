// The persistent tracking notification is what a driver glances at during a
// 9-hour trip to know ControlMiles is still recording, so its clock and its
// distance have to be right.

import 'package:flutter_test/flutter_test.dart';
import 'package:controlmiles/tracking/tracking_notification.dart';

void main() {
  group('notificationStartedAtMs', () {
    final now = DateTime.utc(2026, 9, 26, 15, 0, 0);

    test('the clock reads the active time so far', () {
      final started = notificationStartedAtMs(now, const Duration(hours: 2, minutes: 5));
      expect(now.millisecondsSinceEpoch - started, const Duration(hours: 2, minutes: 5).inMilliseconds);
    });

    test('a brand-new trip starts counting from now', () {
      expect(notificationStartedAtMs(now, Duration.zero), now.millisecondsSinceEpoch);
    });

    test('time spent paused is not counted: only active time is passed in', () {
      // 3h since the trip was created, but only 1h20m of it was driving.
      final started = notificationStartedAtMs(now, const Duration(hours: 1, minutes: 20));
      expect((now.millisecondsSinceEpoch - started) ~/ 60000, 80);
    });

    test('a negative elapsed never puts the start in the future', () {
      expect(notificationStartedAtMs(now, const Duration(seconds: -5)), now.millisecondsSinceEpoch);
    });
  });

  group('trackingNotificationText', () {
    test('miles and kilometres, one decimal, no words to translate', () {
      expect(trackingNotificationText(miles: 12.44, metric: false), '12.4 mi');
      expect(trackingNotificationText(miles: 10, metric: true), '16.1 km');
      expect(trackingNotificationText(miles: 0, metric: false), '0.0 mi');
    });

    test('bad values read as zero', () {
      expect(trackingNotificationText(miles: double.nan, metric: false), '0.0 mi');
      expect(trackingNotificationText(miles: -3, metric: true), '0.0 km');
    });
  });

  group('shouldRefreshNotification', () {
    final t0 = DateTime.utc(2026, 9, 26, 15, 0, 0);

    test('the first reading is always shown', () {
      expect(shouldRefreshNotification(lastRefreshAt: null, now: t0, lastText: null, newText: '0.1 mi'), isTrue);
    });

    test('at most once every 15 seconds', () {
      expect(
          shouldRefreshNotification(
              lastRefreshAt: t0, now: t0.add(const Duration(seconds: 10)), lastText: '1.0 mi', newText: '1.1 mi'),
          isFalse);
      expect(
          shouldRefreshNotification(
              lastRefreshAt: t0, now: t0.add(const Duration(seconds: 15)), lastText: '1.0 mi', newText: '1.1 mi'),
          isTrue);
    });

    test('never re-posts identical text', () {
      expect(
          shouldRefreshNotification(
              lastRefreshAt: t0, now: t0.add(const Duration(minutes: 5)), lastText: '1.0 mi', newText: '1.0 mi'),
          isFalse);
    });
  });

  group('the notification card', () {
    test('title carries the live distance, in the driver unit', () {
      expect(trackingNotificationTitle(miles: 12.44, metric: false), 'ControlMiles \u00b7 12.4 mi');
      expect(trackingNotificationTitle(miles: 10, metric: true), 'ControlMiles \u00b7 16.1 km');
      expect(trackingNotificationTitle(miles: 0, metric: false), 'ControlMiles \u00b7 0.0 mi');
    });

    test('text names the gig app, or falls back to the default', () {
      expect(trackingNotificationBody('Uber'), 'Uber');
      expect(trackingNotificationBody('  Uber Eats '), 'Uber Eats');
      expect(trackingNotificationBody(null), kDefaultNotificationText);
      expect(trackingNotificationBody('   '), kDefaultNotificationText);
    });

    test('defaults are the original plugin texts', () {
      expect(kDefaultNotificationTitle, 'ControlMiles Tracking');
      expect(kDefaultNotificationText, 'Recording miles securely');
    });
  });
}
