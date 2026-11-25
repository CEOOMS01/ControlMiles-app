import 'package:flutter_test/flutter_test.dart';

import 'package:controlmiles/logic/profile_merge.dart';

const _known = ProfileSnapshot(
  displayId: 'CM-1234',
  firstName: 'Ana',
  accountType: 'gig',
  premiumEntitled: true,
  baseEntitled: false,
  mileageMethod: 'standard',
  accountCreatedAt: null,
  tierEnforcementExempt: false,
);

void main() {
  test(
    'an answer with no row changes nothing (the plan and the name are not reset)',
    () {
      expect(mergeProfile(_known, null), _known);
    },
  );

  test('an answer without some fields keeps those fields', () {
    final merged = mergeProfile(_known, {'mileage_method': 'standard'});
    expect(merged.premiumEntitled, isTrue);
    expect(merged.firstName, 'Ana');
    expect(merged.displayId, 'CM-1234');
  });

  test(
    'null or empty text from the server does not erase the saved name or id',
    () {
      final merged = mergeProfile(_known, {
        'first_name': null,
        'display_id': '',
      });
      expect(merged.firstName, 'Ana');
      expect(merged.displayId, 'CM-1234');
    },
  );

  test('a plan that really lapsed still turns off: the server sends false', () {
    final merged = mergeProfile(_known, {
      'premium_entitled': false,
      'base_entitled': false,
    });
    expect(merged.premiumEntitled, isFalse);
  });

  test('what the server sends wins: new plan, name, creation date', () {
    final merged = mergeProfile(_known, {
      'premium_entitled': false,
      'base_entitled': true,
      'first_name': 'Beto',
      'created_at': '2026-01-02T03:04:05Z',
      'account_type': 'fleet_admin',
    });
    expect(merged.baseEntitled, isTrue);
    expect(merged.firstName, 'Beto');
    expect(merged.accountCreatedAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(merged.accountType, 'fleet_admin');
  });

  test('wrong types are ignored, not turned into defaults', () {
    final merged = mergeProfile(_known, {
      'premium_entitled': 'yes',
      'created_at': 7,
    });
    expect(merged.premiumEntitled, isTrue);
    expect(merged.accountCreatedAt, isNull);
  });
}
