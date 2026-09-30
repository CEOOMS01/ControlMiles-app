// Olympus Mont Systems LLC - ControlMiles
// lib/services/driver_notification_service.dart
//
// The fleet driver's message inbox (driver_notifications, 2026-09-30):
// a note after a trip that had harsh braking / hard acceleration /
// speeding, and a driving summary every 15 days. Rows carry a kind +
// numbers; the text is written in the app, in the driver's language
// (see DriverNotificationsScreen). RLS returns only the caller's own.

import 'package:supabase_flutter/supabase_flutter.dart';

class DriverNotification {
  final String id;
  final String kind; // 'trip_safety' | 'safety_summary'
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool read;

  const DriverNotification({
    required this.id,
    required this.kind,
    required this.data,
    required this.createdAt,
    required this.read,
  });

  factory DriverNotification.fromMap(Map<String, dynamic> m) => DriverNotification(
        id: m['id'] as String,
        kind: m['kind'] as String,
        data: Map<String, dynamic>.from((m['data'] as Map?) ?? const {}),
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        read: m['read_at'] != null,
      );

  int intOf(String key) => (data[key] as num?)?.toInt() ?? 0;
  int? scoreOf(String key) => (data[key] as num?)?.round();
}

class DriverNotificationService {
  final _client = Supabase.instance.client;

  Future<List<DriverNotification>> list() async {
    final rows = await _client
        .from('driver_notifications')
        .select('id, kind, data, created_at, read_at')
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List).map((r) => DriverNotification.fromMap(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<int> unreadCount() async {
    final res = await _client
        .from('driver_notifications')
        .select('id')
        .isFilter('read_at', null)
        .count(CountOption.exact);
    return res.count;
  }

  Future<void> markAllRead() async {
    await _client.rpc('mark_driver_notifications_read');
  }
}
