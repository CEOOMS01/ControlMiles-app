import 'package:controlmiles/errors/app_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('odometer below the registered reading gets code 415, not the raw exception', () {
    // Exactly what reached the screen live on 2026-09-29.
    const e = PostgrestException(
      message: 'ODOMETER_BELOW_REGISTERED:208198.00',
      code: 'P0001',
      details: 'Bad Request',
    );
    final err = AppError.from(e);
    expect(err.code, 415);
    final shown = err.display('Lower than the {value} mi on record.');
    expect(shown, 'Lower than the 208,198 mi on record. (415)');
    expect(shown, isNot(contains('PostgrestException')));
  });

  test('a hand-written RPC message is shown without the PostgrestException wrapper', () {
    const e = PostgrestException(message: 'Only an org admin can do that', code: 'P0001');
    final shown = AppError.from(e).display('');
    expect(shown, 'Only an org admin can do that (450)');
  });
}
