// Olympus Mont Systems LLC - ControlMiles
// lib/services/notification_service.dart
//
// 2026-11-06: ControlMiles keeps four notifications, no more:
//   1. the trip-recording notice (the tracking engine's foreground service, in
//      tracelet_engine.dart -- Android requires it while a trip records);
//   2. "Checking your drive..." while the phone wakes up for a detected drive
//      (packages/cm_drive_wake, a short-lived foreground service);
//   3. "Did you finish your trip?" after 5 minutes without moving (this file);
//   4. "Trip finished" when the app closed a trip that sat still (this file).
// Everything else that used to live here (forgotten-trip and pause reminders,
// the weekly summary, work-hours and work-place reminders, GPS alerts, app-switch
// and auto-start notices...) was removed. Alarms scheduled by older versions are
// cancelled in [_cancelOldNotifications] so they never fire after an update.
//
// Only LOCAL notifications, raised by the app's own process. No push backend.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/app_texts.dart';
import '../theme/app_colors.dart';
import '../tracking/trip_inactivity.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Ids of the two notifications that remain.
  static const int _tripStillId = 1044;
  static const int _tripInfoId = 1045;
  static const String _actTripContinue = 'trip_still_continue';
  static const String _actTripEnd = 'trip_still_end';

  static const String _channelId = 'controlmiles_trip_alerts';
  static const String _channelName = 'Trip alerts';
  static const String _channelDescription = 'Asks if your trip is over, and tells you when a still trip was closed';

  // Ids and channels of the notifications that no longer exist: cancelled and
  // removed once on startup so an update leaves nothing behind (scheduled alarms
  // included).
  static const List<int> _oldIds = [
    1001, 1002, 1004, 1005, 1006, // forgotten trip, weekly summary, app switch, auto start, auto failed
    1007, 1008, 1009, 1010, 1011, 1012, // pause reminder ladder
    1013, 1014, // paused status, GPS alert
    1020, 1021, 1022, 1023, 1024, 1025, 1026, // work-hours start
    1030, 1031, 1032, 1033, 1034, 1035, 1036, // work-hours end
    1040, 1041, 1042, 1043, // work places
  ];
  static const List<String> _oldChannels = [
    'controlmiles_reminders',
    'controlmiles_switch_confirm',
    'controlmiles_pause_reminder',
    'controlmiles_paused_status',
    'controlmiles_work_schedule',
    'controlmiles_gps_alert',
  ];

  // The app's navigator, set from main.dart (work places use it to open the app).
  GlobalKey<NavigatorState>? navigatorKey;

  // ============================================================
  // INIT
  // ============================================================
  Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_initialized) return;
    this.navigatorKey = navigatorKey;
    await _lightInit();
    await _requestPermissions();
  }

  /// Setup that is safe from the background isolate too (it never opens system
  /// settings screens).
  Future<bool> _lightInit() async {
    if (_initialized) return true;
    try {
      // The white silhouette icon: Android keeps only the alpha channel of a small
      // icon, so the full-colour launcher icon would show as a solid white square.
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_tracking'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ));
      await _cancelOldNotifications(android);
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('[NotificationService] init failed: $e');
      return false;
    }
  }

  Future<void> _cancelOldNotifications(AndroidFlutterLocalNotificationsPlugin? android) async {
    try {
      for (final id in _oldIds) {
        await _plugin.cancel(id);
      }
      for (final c in _oldChannels) {
        await android?.deleteNotificationChannel(c);
      }
    } catch (e) {
      debugPrint('[NotificationService] cleaning old notifications failed: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      // Android asks for the notification permission on the step-by-step
      // permissions page, with an explanation. Only iOS asks here.
      if (!Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      debugPrint('[NotificationService] Permission request failed: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // "Did you finish your trip?" buttons (see TripInactivity).
    if (response.payload == 'trip_still') {
      if (response.actionId == _actTripEnd) {
        unawaited(TripInactivity.endNow());
      } else if (response.actionId == _actTripContinue) {
        unawaited(TripInactivity.continueTrip());
      }
    }
  }

  // The language comes straight from SharedPreferences (same key as AppState),
  // because this can run in the background with no BuildContext.
  Future<String> _tr(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('controlmiles_lang') ?? 'en';
    return AppTexts.get(key, langCode);
  }

  /// The Settings switch: turning notifications off clears what is showing.
  Future<void> setEnabled(bool enabled) async {
    if (!enabled) await cancelAll();
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ============================================================
  // A TRIP THAT STOPPED MOVING (see TripInactivity)
  // The question has two buttons that open the app and answer it; the other is
  // a plain notice of what the app just did.
  // ============================================================
  Future<void> showTripStillPrompt() async {
    if (!await _lightInit()) return;
    final title = await _tr('trip_still_title');
    final body = await _tr('trip_still_body');
    final keepGoing = await _tr('trip_still_continue');
    final endTrip = await _tr('trip_still_end');
    await _plugin.show(
      _tripStillId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          color: kBrandSeed,
          timeoutAfter: 5 * 60 * 1000,
          actions: [
            AndroidNotificationAction(_actTripContinue, keepGoing, showsUserInterface: true, cancelNotification: true),
            AndroidNotificationAction(_actTripEnd, endTrip, showsUserInterface: true, cancelNotification: true),
          ],
        ),
      ),
      payload: 'trip_still',
    );
  }

  Future<void> cancelTripStillPrompt() async {
    if (!await _lightInit()) return;
    await _plugin.cancel(_tripStillId);
  }

  /// The app closed a trip that sat still for too long.
  Future<void> showTripAutoClosed() async {
    if (!await _lightInit()) return;
    final title = await _tr('trip_autoclosed_title');
    final body = await _tr('trip_autoclosed_body');
    await _plugin.show(
      _tripInfoId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          color: kBrandSeed,
        ),
      ),
      payload: 'trip_info',
    );
  }
}
