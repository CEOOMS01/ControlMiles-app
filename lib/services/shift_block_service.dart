// Olympus Mont Systems LLC - ControlMiles
// lib/services/shift_block_service.dart
//
// Hourly class blocks for fleet drivers (2026-09-29, driving-school style,
// explicit user request). The fleet schedules classes (weekly template +
// one-off, web /admin/shifts); the driver starts each class from W minutes
// before to W minutes after its start, the trip is tied to the class, and
// between classes nothing is tracked while the WORKDAY stays open until the
// driver ends it. All rules live in the DB (migration
// 20260929170000_hourly_shift_blocks.sql); this is a thin client.

import 'package:supabase_flutter/supabase_flutter.dart';

class ShiftBlock {
  final String id;
  final String startTime; // HH:MM:SS, fleet local time
  final String endTime;
  final String? note;
  final String? vehicleId;
  final String? vehicleLabel;
  final String? vehicleDisplayId;
  final String status; // scheduled | in_progress | done
  final int? lateMinutes;
  final DateTime opensAt;
  final DateTime closesAt;

  const ShiftBlock({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.note,
    required this.vehicleId,
    required this.vehicleLabel,
    required this.vehicleDisplayId,
    required this.status,
    required this.lateMinutes,
    required this.opensAt,
    required this.closesAt,
  });

  factory ShiftBlock.fromMap(Map<String, dynamic> m) => ShiftBlock(
        id: m['id'] as String,
        startTime: m['start_time'] as String,
        endTime: m['end_time'] as String,
        note: m['note'] as String?,
        vehicleId: m['vehicle_id'] as String?,
        vehicleLabel: m['vehicle_label'] as String?,
        vehicleDisplayId: m['vehicle_display_id'] as String?,
        status: m['status'] as String,
        lateMinutes: (m['late_minutes'] as num?)?.toInt(),
        opensAt: DateTime.parse(m['opens_at'] as String).toLocal(),
        closesAt: DateTime.parse(m['closes_at'] as String).toLocal(),
      );

  bool get isScheduled => status == 'scheduled';
  bool get isInProgress => status == 'in_progress';
  bool get isDone => status == 'done';

  bool isOpenToStart(DateTime now) =>
      isScheduled && !now.isBefore(opensAt) && !now.isAfter(closesAt);
  bool isMissed(DateTime now) => isScheduled && now.isAfter(closesAt);

  String get vehicleText {
    if (vehicleLabel == null) return vehicleDisplayId ?? '';
    return vehicleDisplayId == null ? vehicleLabel! : '$vehicleLabel ($vehicleDisplayId)';
  }
}

class ShiftDay {
  final List<ShiftBlock> blocks;
  final bool workdayOpen;
  final bool workdayClosed;

  const ShiftDay({required this.blocks, required this.workdayOpen, required this.workdayClosed});

  bool get hasBlocks => blocks.isNotEmpty;

  ShiftBlock? get inProgress {
    for (final b in blocks) {
      if (b.isInProgress) return b;
    }
    return null;
  }

  ShiftBlock? openToStart(DateTime now) {
    for (final b in blocks) {
      if (b.isOpenToStart(now)) return b;
    }
    return null;
  }

  /// The next class that hasn't opened yet (for "opens at ...").
  ShiftBlock? nextUpcoming(DateTime now) {
    for (final b in blocks) {
      if (b.isScheduled && now.isBefore(b.opensAt)) return b;
    }
    return null;
  }
}

class ShiftBlockService {
  final _db = Supabase.instance.client;

  Future<ShiftDay> getMyDay(String orgId) async {
    final data = await _db.rpc('get_my_shift_day', params: {'p_org': orgId}) as Map<String, dynamic>;
    final blocks = (data['blocks'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(ShiftBlock.fromMap)
        .toList();
    return ShiftDay(
      blocks: blocks,
      workdayOpen: data['workday_open'] == true,
      workdayClosed: data['workday_closed'] == true,
    );
  }

  Future<void> start(String blockId) =>
      _db.rpc('start_shift_block', params: {'p_block_id': blockId});

  /// Undo a start whose trip never got going (odometer/GPS step failed).
  Future<void> abortStart(String blockId) =>
      _db.rpc('abort_shift_block_start', params: {'p_block_id': blockId});

  Future<void> end(String blockId) =>
      _db.rpc('end_shift_block', params: {'p_block_id': blockId});

  Future<void> closeDay(String orgId) =>
      _db.rpc('close_my_workday', params: {'p_org': orgId});
}
