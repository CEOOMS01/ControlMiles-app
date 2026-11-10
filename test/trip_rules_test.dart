import 'package:controlmiles/i18n/en.dart';
import 'package:controlmiles/i18n/es.dart';
import 'package:controlmiles/i18n/fr.dart';
import 'package:controlmiles/i18n/hi.dart';
import 'package:controlmiles/i18n/zh.dart';
import 'package:controlmiles/services/trip_rules_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a route from any location has no start point', () {
    final trip = RegularTrip.fromMap({
      'id': 'a',
      'start_any': true,
      'end_latitude': 39.29,
      'end_longitude': -76.67,
      'purpose': 'medical',
    });
    expect(trip.startAny, isTrue);
    expect(trip.startLatitude, isNull);
    expect(trip.endLongitude, -76.67);
  });

  test('settings without a saved row leave Work Hours off and Regular Trips on', () {
    final settings = TripClassificationSettings();
    expect(settings.regularEnabled, isTrue);
    expect(settings.workHoursInside, isFalse);
    expect(settings.workHoursOutside, isFalse);
    expect(settings.workDays, {1, 2, 3, 4, 5});
  });

  test('settings survive being saved and read back', () {
    final row = TripClassificationSettings(
      suggestionsEnabled: false,
      workHoursInside: true,
      workDays: {6, 1},
      workStartMinute: 1320,
      workEndMinute: 120,
    ).toRow('user', 'America/New_York');
    expect(row['work_days'], [1, 6]);
    expect(row['time_zone'], 'America/New_York');
    final back = TripClassificationSettings.fromMap(row);
    expect(back.suggestionsEnabled, isFalse);
    expect(back.workHoursInside, isTrue);
    expect(back.workDays, {1, 6});
    expect(back.workStartMinute, 1320);
    expect(back.workEndMinute, 120);
  });

  test('every new text exists in the five languages', () {
    final keys = enTexts.keys.where((k) => k.startsWith('regular_trip') || k.startsWith('account_') || k.startsWith('work_hours_') || k == 'my_work_title' || k == 'trip_rules_general_only');
    expect(keys.length, greaterThan(30));
    for (final texts in [esTexts, frTexts, zhTexts, hiTexts]) {
      for (final k in keys) {
        expect(texts[k], isNotNull, reason: k);
      }
    }
  });
}
