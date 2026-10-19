// Fleet app sign-in: the "Admin / Team fleet" answer is remembered on the
// phone and asked again only after a promotion (user rule, 2026-10-19).

import 'package:controlmiles/services/login_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nothing answered yet', () async {
    expect(await LoginPrefs.fleetEntry(), isNull);
    expect(await LoginPrefs.fleetPromoted(), isFalse);
  });

  test('the answer is remembered', () async {
    await LoginPrefs.setFleetEntry('team');
    expect(await LoginPrefs.fleetEntry(), 'team');
    await LoginPrefs.setFleetEntry('admin');
    expect(await LoginPrefs.fleetEntry(), 'admin');
  });

  test('clearing it asks again', () async {
    await LoginPrefs.setFleetEntry('team');
    await LoginPrefs.setFleetEntry(null);
    expect(await LoginPrefs.fleetEntry(), isNull);
  });

  test('an unknown stored value counts as not answered', () async {
    SharedPreferences.setMockInitialValues({'controlmiles_fleet_entry': 'driver'});
    expect(await LoginPrefs.fleetEntry(), isNull);
  });

  test('promotion flag is set and cleared', () async {
    await LoginPrefs.setFleetPromoted(true);
    expect(await LoginPrefs.fleetPromoted(), isTrue);
    await LoginPrefs.setFleetPromoted(false);
    expect(await LoginPrefs.fleetPromoted(), isFalse);
  });

  test('signing out keeps the answer (device-level preference)', () async {
    await LoginPrefs.setFleetEntry('team');
    await LoginPrefs.saveAfterSignIn(remember: false, staySignedIn: true);
    expect(await LoginPrefs.fleetEntry(), 'team');
  });
}
