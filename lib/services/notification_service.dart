// Olympus Mont Systems LLC - ControlMiles
// lib/services/notification_service.dart
//
// BUG FIX (toggle de notificaciones inerte): antes SettingsScreen escribía
// la clave `notifications_enabled` en SharedPreferences y ningún código la
// leía — no existía ningún sistema de notificaciones en la app, ni local
// ni push. Este servicio es la implementación real: dos recordatorios
// locales (viaje olvidado activo + resumen semanal de millas), ambos
// respetando el toggle de Settings a través de AppState.
//
// Alcance deliberado: solo notificaciones LOCALES, disparadas por el propio
// proceso de la app. No hay backend de push (este proyecto no tiene Edge
// Functions ni FCM configurado) — construir eso sería un proyecto aparte de
// infraestructura, no un bug fix.

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../routes/app_routes.dart';
import '../models/gig_app.dart';
import '../i18n/app_texts.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // IDs fijos por tipo de notificación — reusar el mismo ID al programar de
  // nuevo simplemente reemplaza la notificación pendiente anterior, así que
  // nunca hay duplicados sin necesidad de llevar un registro aparte.
  static const int _forgottenTripNotificationId = 1001;
  static const int _weeklySummaryNotificationId = 1002;
  static const int _midTripSwitchNotificationId = 1004;
  static const int _autoTripStartedNotificationId = 1005;

  static const String _channelId = 'controlmiles_reminders';
  static const String _channelName = 'Recordatorios';
  static const String _channelDescription =
      'Recordatorios de viaje activo y resumen semanal de millas';

  // Real gap found live (2026-08-27, explicit user request: "el banner
  // sí se ve dentro de la app, quiero que se vea fuera de ella"): the
  // mid-trip auto-switch CONFIRMATION was on the low-key _channelId
  // (Importance.defaultImportance), which on Android sits quietly in
  // the notification tray -- exactly wrong for this, since the driver
  // is by definition using a DIFFERENT app (the one just auto-detected)
  // when it fires, not looking at ControlMiles. Needs its own channel:
  // Importance.high is the real minimum Android requires for a
  // heads-up (peeking) notification that pops over whatever app is in
  // front -- deliberately NOT importance.max/fullScreenIntent like the
  // urgent trip-start channel, since this is purely informational (the
  // switch already happened), not "stop and confirm something now."
  static const String _switchConfirmChannelId = 'controlmiles_switch_confirm';
  static const String _switchConfirmChannelName = 'Cambio de app confirmado';
  static const String _switchConfirmChannelDescription =
      'Aviso visible cuando la detección automática cambia de app gig durante un viaje';

  // Referencia opcional al GlobalKey<NavigatorState> de MaterialApp, seteada
  // desde main.dart — permite que tocar la notificación de resumen semanal
  // abra Reports directamente en vez de solo abrir la app en la pantalla
  // que ya estuviera visible.
  GlobalKey<NavigatorState>? navigatorKey;

  // ============================================================
  // INIT
  // ============================================================
  Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_initialized) return;
    this.navigatorKey = navigatorKey;

    try {
      tz_data.initializeTimeZones();
      // flutter_timezone 5.x devuelve un TimezoneInfo (no un String plano
      // como versiones viejas) — el identificador IANA está en .identifier.
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz.identifier));
    } catch (e) {
      // Si falla la detección de timezone (dispositivo raro, permiso, lo
      // que sea), seguimos con UTC en vez de tumbar la inicialización
      // entera — los recordatorios simplemente dispararán en hora UTC.
      debugPrint('[NotificationService] Timezone detection failed, falling back to UTC: $e');
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false, // se pide explícito más abajo
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit, macOS: darwinInit),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _createAndroidChannel();
    await _requestPermissions();

    _initialized = true;

    // Si el usuario ya tiene notificaciones habilitadas, asegurar que el
    // resumen semanal quede programado desde ya (idempotente — programar
    // de nuevo con el mismo ID solo actualiza el horario, no duplica).
    final enabled = await _isEnabledInPrefs();
    if (enabled) {
      await scheduleWeeklySummaryReminder();
    }
  }

  Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.defaultImportance,
    );

    const switchConfirmChannel = AndroidNotificationChannel(
      _switchConfirmChannelId,
      _switchConfirmChannelName,
      description: _switchConfirmChannelDescription,
      importance: Importance.high,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.createNotificationChannel(switchConfirmChannel);
  }

  Future<void> _requestPermissions() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('[NotificationService] Permission request failed: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.id == _weeklySummaryNotificationId) {
      final nav = navigatorKey?.currentState;
      nav?.pushNamed(AppRoutes.reports);
    }
    // La de "viaje olvidado" no navega a ningún lado en particular — el
    // usuario ya ve el estado de tracking apenas abre la app en Dashboard.
  }

  Future<bool> _isEnabledInPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  // BUG FIX (pedido explícito, encontrado en vivo -- notificaciones
  // aparecían en español con la app en inglés): las 3 notificaciones de
  // este servicio tenían su texto hardcodeado en español directamente en
  // .zonedSchedule()/.show(). Este servicio no tiene BuildContext/AppState
  // (corre en background/headless), así que lee el idioma guardado
  // directo de SharedPreferences -- misma clave que AppState.loadFromPrefs()
  // usa ('controlmiles_lang') -- y resuelve el texto vía AppTexts.get(),
  // el mismo lookup estático que odometer_capture_service.dart ya usa por
  // la misma razón (sin BuildContext disponible ahí tampoco).
  Future<String> _tr(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('controlmiles_lang') ?? 'en';
    return AppTexts.get(key, langCode);
  }

  // ============================================================
  // ENABLE / DISABLE (llamado desde AppState.setNotificationsEnabled)
  // ============================================================
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await scheduleWeeklySummaryReminder();
      // El recordatorio de viaje olvidado se programa solo cuando arranca
      // un viaje real (ver TrackingController.startTripFlow) — no hay
      // nada que reprogramar acá si no hay tracking activo ahora mismo.
    } else {
      await cancelAll();
    }
  }

  // ============================================================
  // VIAJE OLVIDADO ACTIVO
  // ============================================================
  /// Programa un recordatorio único, threshold horas después de AHORA. Se
  /// llama al iniciar un viaje (startTripFlow) y, best-effort, cada vez que
  /// se recupera un viaje activo tras un reinicio de la app
  /// (_recoverActiveState) — en ese segundo caso el conteo de `threshold`
  /// horas se reinicia desde el momento de la recuperación, no desde el
  /// inicio real del viaje (no se guarda el start_time original en el
  /// checkpoint local). Para un recordatorio informativo no crítico es un
  /// costo aceptable; documentado acá para que no sorprenda.
  Future<void> scheduleForgottenTripReminder({
    Duration threshold = const Duration(hours: 8),
  }) async {
    if (!_initialized) return;
    if (!await _isEnabledInPrefs()) return;

    final scheduledDate = tz.TZDateTime.now(tz.local).add(threshold);
    final title = await _tr('forgotten_trip_notification_title');
    final body = await _tr('forgotten_trip_notification_body');

    await _plugin.zonedSchedule(
      _forgottenTripNotificationId,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelForgottenTripReminder() async {
    await _plugin.cancel(_forgottenTripNotificationId);
  }

  // ============================================================
  // RESUMEN SEMANAL
  // ============================================================
  /// Recordatorio recurrente, todos los domingos ~8pm hora local. El texto
  /// es genérico a propósito — un local notification programado con
  /// anticipación no puede llevar cifras en vivo (millas reales de la
  /// semana) sin un mecanismo de fondo aparte; acá solo se avisa que el
  /// resumen está listo y, al tocarlo, se abre Reports para verlo con datos
  /// reales de la DB.
  Future<void> scheduleWeeklySummaryReminder() async {
    if (!_initialized) return;
    if (!await _isEnabledInPrefs()) return;

    final scheduledDate = _nextInstanceOfSundayEightPm();
    final title = await _tr('weekly_summary_notification_title');
    final body = await _tr('weekly_summary_notification_body');

    await _plugin.zonedSchedule(
      _weeklySummaryNotificationId,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  tz.TZDateTime _nextInstanceOfSundayEightPm() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20);

    while (scheduled.weekday != DateTime.sunday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> cancelWeeklySummaryReminder() async {
    await _plugin.cancel(_weeklySummaryNotificationId);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ============================================================
  // DETECCIÓN AUTOMÁTICA DE VIAJES (premium)
  // ============================================================
  /// A specific gig app was identified with real confidence and the
  /// trip already started silently -- purely informational, matching
  /// showMidTripAutoSwitchedNotification's pattern exactly (same
  /// heads-up-capable channel, so it's actually visible while the
  /// driver is in the gig app, not ControlMiles).
  Future<void> showAutoTripStartedNotification({required String gigAppId}) async {
    if (!_initialized) return;

    final title = await _tr('auto_trip_started_title');
    final appName = GigAppCatalog.byId(gigAppId).name;
    final bodyPrefix = await _tr('auto_trip_started_body');
    final body = '$bodyPrefix $appName.';

    await _plugin.show(
      _autoTripStartedNotificationId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _switchConfirmChannelId,
          _switchConfirmChannelName,
          channelDescription: _switchConfirmChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
        macOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
      ),
    );
  }

  // ============================================================
  // CAMBIO DE APP GIG A MITAD DE VIAJE (premium)
  // ============================================================
  /// "Ask" mode (AppState.autoSwitchGigApp == false, the default) --
  /// informational, not urgent: ending/starting a trip needs the
  /// odometer confirmed right now,
  /// but switching which gig app an already-running trip is tracking
  /// under doesn't need that same urgency. Tapping just opens the app --
  /// the actual switch/dismiss action lives on DashboardScreen's status
  /// card (AutoTripDetectionService.confirmMidTripSwitch/
  /// dismissMidTripSwitch), not on the notification itself.
  Future<void> showMidTripSwitchSuggestedNotification({required String gigAppId}) async {
    if (!_initialized) return;

    final title = await _tr('mid_trip_switch_suggested_title');
    final appName = GigAppCatalog.byId(gigAppId).name;
    final bodyPrefix = await _tr('mid_trip_switch_suggested_body');
    final body = '$bodyPrefix $appName';

    await _plugin.show(
      _midTripSwitchNotificationId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// "Auto" mode (AppState.autoSwitchGigApp == true) -- the switch
  /// already happened by the time this fires, purely informational.
  Future<void> showMidTripAutoSwitchedNotification({required String gigAppId}) async {
    if (!_initialized) return;

    final title = await _tr('mid_trip_auto_switched_title');
    final appName = GigAppCatalog.byId(gigAppId).name;
    final bodyPrefix = await _tr('mid_trip_auto_switched_body');
    final body = '$bodyPrefix $appName.';

    await _plugin.show(
      _midTripSwitchNotificationId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _switchConfirmChannelId,
          _switchConfirmChannelName,
          channelDescription: _switchConfirmChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
        macOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
      ),
    );
  }
}
