import 'package:controlmiles/errors/app_error.dart';
import 'package:controlmiles/services/shift_block_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

ShiftBlock block(String id, DateTime start, {String status = 'scheduled', int windowMin = 10}) =>
    ShiftBlock(
      id: id,
      startTime: '08:00:00',
      endTime: '09:00:00',
      note: null,
      vehicleId: null,
      vehicleLabel: null,
      vehicleDisplayId: null,
      status: status,
      lateMinutes: null,
      opensAt: start.subtract(Duration(minutes: windowMin)),
      closesAt: start.add(Duration(minutes: windowMin)),
    );

void main() {
  final start = DateTime(2026, 9, 29, 8);

  test('a class opens W minutes before its start and closes W minutes after', () {
    final b = block('a', start);
    expect(b.isOpenToStart(start.subtract(const Duration(minutes: 11))), isFalse);
    expect(b.isOpenToStart(start.subtract(const Duration(minutes: 10))), isTrue);
    expect(b.isOpenToStart(start.add(const Duration(minutes: 10))), isTrue);
    expect(b.isOpenToStart(start.add(const Duration(minutes: 11))), isFalse);
    expect(b.isMissed(start.add(const Duration(minutes: 11))), isTrue);
  });

  test('a started or finished class is never open to start or missed', () {
    final now = start.add(const Duration(hours: 3));
    expect(block('a', start, status: 'in_progress').isMissed(now), isFalse);
    expect(block('a', start, status: 'done').isOpenToStart(start), isFalse);
  });

  test('the day finds the open class and the next one', () {
    final day = ShiftDay(
      blocks: [block('a', start), block('b', start.add(const Duration(hours: 2)))],
      workdayOpen: false,
      workdayClosed: false,
    );
    expect(day.openToStart(start)!.id, 'a');
    expect(day.nextUpcoming(start.add(const Duration(minutes: 30)))!.id, 'b');
    expect(day.openToStart(start.add(const Duration(minutes: 30))), isNull);
  });

  test('class start refusals map to their own codes', () {
    AppError e(String m) => AppError.from(PostgrestException(message: m, code: 'P0001'));
    expect(e('SHIFT_BLOCK_TOO_EARLY:07:50 AM').code, 416);
    expect(e('SHIFT_BLOCK_TOO_EARLY:07:50 AM').display('Opens at {time}.'), 'Opens at 07:50 AM. (416)');
    expect(e('SHIFT_BLOCK_WINDOW_CLOSED').code, 417);
    expect(e('SHIFT_BLOCK_ANOTHER_IN_PROGRESS').code, 418);
    expect(e('WORKDAY_ALREADY_CLOSED').code, 419);
    expect(e('WORKDAY_BLOCK_IN_PROGRESS').code, 422);
  });
}
