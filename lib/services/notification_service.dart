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
import '../theme/app_colors.dart';

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
  static const int _autoDetectFailedNotificationId = 1006;

  // OJO: el recordatorio de pausa NO usa un id suelto sino el RANGO
  // 1007..1012 (base + índice de _pauseReminderLadder, 6 avisos escalonados).
  // No reutilizar ningún id entre 1007 y 1012 para nada más: colisionaría con
  // un peldaño de la escalera y lo sobrescribiría silenciosamente. El próximo
  // id libre para una notificación nueva es 1013.
  static const int _pauseReminderNotificationId = 1007;

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

  // Mismo criterio de Importance.high que _switchConfirmChannelId de
  // arriba: el driver no está mirando la app mientras el viaje está en
  // pausa (probablemente ni siquiera el teléfono), así que el recordatorio
  // necesita empujarse por encima de lo que sea que esté en pantalla, no
  // quedarse callado en la bandeja.
  static const String _pauseReminderChannelId = 'controlmiles_pause_reminder';
  static const String _pauseReminderChannelName = 'Recordatorio de pausa';
  static const String _pauseReminderChannelDescription =
      'Aviso cuando el tracking lleva varios minutos en pausa, por si se olvidó reanudar o finalizar el viaje';

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

    // BUG FIX (2026-09-15): esto apuntaba a '@mipmap/launcher_icon' — el icono
    // de launcher a todo color. Android 5.0+ ignora los colores del small icon
    // y usa SOLO su canal alfa, y el launcher icon es un cuadrado 100% opaco:
    // el resultado era un CUADRO BLANCO SÓLIDO en la barra de estado en cada
    // notificación que emite la app. El icono correcto es la silueta blanca
    // sobre transparente que ya existía (ic_stat_tracking, el mismo que el
    // motor de tracking ya usaba en tracelet_engine.dart) — ahora ambos caminos
    // usan el mismo asset.
    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_tracking');
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

    const pauseReminderChannel = AndroidNotificationChannel(
      _pauseReminderChannelId,
      _pauseReminderChannelName,
      description: _pauseReminderChannelDescription,
      importance: Importance.high,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.createNotificationChannel(switchConfirmChannel);
    await androidPlugin?.createNotificationChannel(pauseReminderChannel);
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

  // ============================================================
  // PREFERENCIA POR TIPO DE AVISO
  // ============================================================
  /// Pedido explícito (2026-09-16): "cada aviso de notificación del
  /// tracking o de la foto del odómetro tenga un check donde el cliente
  /// toca no volver a mostrar este aviso." Hasta ahora solo existía el
  /// interruptor MAESTRO (`notifications_enabled`): o todo o nada, así que
  /// alguien a quien solo le molestaba el resumen semanal tenía que apagar
  /// también los recordatorios que de verdad protegen su registro.
  ///
  /// Cada tipo informativo se puede silenciar por separado desde Ajustes.
  /// Deliberadamente NO hay clave para `showAutoDetectFailedNotification`:
  /// ese no es un aviso informativo sino un ERROR -- es exactamente el que
  /// habría delatado que la detección llevaba una semana muerta tras el
  /// renombrado del paquete. Silenciable = fallo silencioso otra vez.
  ///
  /// Las capturas semanales de odómetro tampoco aparecen aquí: son
  /// acciones obligatorias, no avisos (ver tracking_action_button.dart).
  static const String prefPauseReminder = 'notif_type_pause_reminder';
  static const String prefForgottenTrip = 'notif_type_forgotten_trip';
  static const String prefWeeklySummary = 'notif_type_weekly_summary';
  static const String prefGigAppSwitch = 'notif_type_gig_app_switch';
  static const String prefAutoTripStarted = 'notif_type_auto_trip_started';

  /// Todos activados por defecto -- silenciar es siempre una decisión
  /// explícita del usuario, nunca el estado inicial.
  Future<bool> isTypeEnabled(String prefKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? true;
  }

  Future<void> setTypeEnabled(String prefKey, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, enabled);

    // Los programados hay que cancelarlos de verdad: apagar el toggle no
    // debe dejar una alarma ya puesta en AlarmManager esperando disparar.
    if (!enabled) {
      if (prefKey == prefPauseReminder) await cancelPauseReminder();
      if (prefKey == prefForgottenTrip) await cancelForgottenTripReminder();
      if (prefKey == prefWeeklySummary) {
        await _plugin.cancel(_weeklySummaryNotificationId);
      }
    } else if (prefKey == prefWeeklySummary) {
      await scheduleWeeklySummaryReminder();
    }
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
    if (!await isTypeEnabled(prefForgottenTrip)) return;

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
          color: kBrandSeed,
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
  // TRACKING EN PAUSA
  // ============================================================
  /// Programa un recordatorio único, threshold minutos después de AHORA --
  /// mismo mecanismo que scheduleForgottenTripReminder (AlarmManager vía
  /// zonedSchedule, sobrevive backgrounding/kill del proceso). Se llama
  /// desde TrackingController.pauseTracking() al pausar, y desde los 3
  /// puntos de recuperación en frío (_recoverActiveState) si el estado
  /// recuperado ya estaba en pausa -- mismo criterio que
  /// _rescheduleForgottenTripReminderIfRunning ya usa para 'running'.
  /// Cadencia del recordatorio de pausa (pedido explícito, 2026-09-16: "me
  /// gustaría que se repitiera"). Antes era UN solo aviso a los 5 minutos y
  /// nada más -- si el conductor no lo veía en ese momento, el viaje se podía
  /// quedar pausado horas sin que nada se lo recordara.
  ///
  /// Se programa una ESCALERA de avisos, cada uno como su propia alarma
  /// one-shot con su propio id. Se eligió esto en vez de periodicallyShow()
  /// porque RepeatInterval solo ofrece everyMinute/hourly/daily: por minuto es
  /// spam y por hora llega tarde para el primer aviso. Los intervalos se van
  /// ABRIENDO (5m, 15m, 30m, 1h, 2h, 4h) en vez de repetir cada 5 minutos:
  /// insiste fuerte al principio, cuando lo más probable es un olvido real, y
  /// va bajando el ritmo si el conductor deliberadamente dejó el viaje en
  /// pausa. Tope a las ~8h acumuladas; más allá de eso el recordatorio de
  /// "viaje olvidado" ya cubre el caso.
  ///
  /// Los tiempos son ACUMULADOS desde el momento de pausar, no incrementales.
  static const List<Duration> _pauseReminderLadder = [
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 4),
  ];

  /// Ancla de la escalera: timestamp (ms epoch) del momento en que se pausó.
  static const String _pauseAnchorKey = 'controlmiles_pause_reminder_anchor_ms';

  /// BUG FIX (2026-09-16, encontrado en vivo con dumpsys alarm): la primera
  /// versión de esto programaba los peldaños como `now + offset` y cancelaba
  /// la escalera anterior en cada llamada. Pero `_reschedulePauseReminderIfPaused`
  /// corre desde `initializeOrRecover()`, que `AppLifecycleObserver` invoca
  /// CADA VEZ que la app vuelve a primer plano. Efecto: cada vez que el
  /// conductor abría la app, la escalera se reiniciaba desde cero y el
  /// peldaño de 5 minutos se cancelaba y se reposponía antes de poder
  /// dispararse. Se observó en vivo: las alarmas saltaron de 00:48:36 a
  /// 00:54:25 sin que ninguna llegara a sonar.
  ///
  /// Ahora la escalera se ancla al INSTANTE REAL DE LA PAUSA, persistido en
  /// disco, y los peldaños son horas absolutas (`anchor + offset`).
  /// Reprogramar pasa a ser idempotente: recalcula exactamente las mismas
  /// horas, así que abrir la app veinte veces no mueve nada. Los peldaños ya
  /// vencidos simplemente no se re-programan.
  ///
  /// [restart] en true SOLO al pausar de verdad (arranca un ancla nueva);
  /// en false desde los caminos de recuperación, que deben respetar el ancla
  /// ya existente.
  Future<void> schedulePauseReminder({bool restart = false}) async {
    if (!_initialized) return;
    if (!await _isEnabledInPrefs()) return;
    if (!await isTypeEnabled(prefPauseReminder)) return;

    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final int anchorMs;
    if (restart || !prefs.containsKey(_pauseAnchorKey)) {
      anchorMs = nowMs;
      await prefs.setInt(_pauseAnchorKey, anchorMs);
    } else {
      anchorMs = prefs.getInt(_pauseAnchorKey)!;
    }

    // Solo cancela las ALARMAS (no el ancla): se re-arman abajo con las
    // mismas horas absolutas, de modo que no hay deriva entre llamadas.
    await _cancelPauseReminderAlarms();

    final anchor = tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, anchorMs);
    final now = tz.TZDateTime.now(tz.local);
    final title = await _tr('pause_reminder_notification_title');
    final body = await _tr('pause_reminder_notification_body');

    for (var i = 0; i < _pauseReminderLadder.length; i++) {
      final when = anchor.add(_pauseReminderLadder[i]);
      // Peldaño ya vencido (la app se abrió cuando la pausa llevaba rato):
      // no tiene sentido re-programarlo en el pasado.
      if (!when.isAfter(now)) continue;

      await _plugin.zonedSchedule(
        _pauseReminderNotificationId + i,
        title,
        body,
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _pauseReminderChannelId,
            _pauseReminderChannelName,
            channelDescription: _pauseReminderChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            color: kBrandSeed,
          ),
          iOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
          macOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> _cancelPauseReminderAlarms() async {
    for (var i = 0; i < _pauseReminderLadder.length; i++) {
      await _plugin.cancel(_pauseReminderNotificationId + i);
    }
  }

  /// Cancela la escalera COMPLETA y borra el ancla: al reanudar o cerrar el
  /// viaje no debe quedar ni un aviso pendiente, y la próxima pausa tiene que
  /// arrancar su propio conteo desde cero.
  Future<void> cancelPauseReminder() async {
    await _cancelPauseReminderAlarms();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pauseAnchorKey);
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
    if (!await isTypeEnabled(prefWeeklySummary)) return;

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
          color: kBrandSeed,
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
    if (!await isTypeEnabled(prefAutoTripStarted)) return;

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
          color: kBrandSeed,
        ),
        iOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
        macOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
      ),
    );
  }

  /// REAL BUG FIX (2026-08-28, "bug silencioso en auto-detección"): the
  /// whole point of this notification is that arming used to be able to
  /// silently no-op -- the GPS engine failing to start (permission
  /// revoked, plugin error) previously left the UI showing "Auto-
  /// Detection ON" forever with zero indication anything was wrong. This
  /// fires from BOTH the interactive activation path (requestEnable,
  /// which ALSO shows a dialog since it has a live BuildContext) and the
  /// silent cold-boot restore path (restoreFromPrefs, which has no UI to
  /// show anything else -- this notification is the only signal that
  /// path can give). Same heads-up-capable channel as the other
  /// auto-detect notifications, since this needs to actually be seen.
  Future<void> showAutoDetectFailedNotification() async {
    if (!_initialized) return;

    final title = await _tr('auto_detect_failed_title');
    final body = await _tr('auto_detect_failed_body');

    await _plugin.show(
      _autoDetectFailedNotificationId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _switchConfirmChannelId,
          _switchConfirmChannelName,
          channelDescription: _switchConfirmChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          color: kBrandSeed,
        ),
        iOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
        macOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
      ),
    );
  }

  // ============================================================
  // CAMBIO DE APP GIG A MITAD DE VIAJE (premium)
  // ============================================================
  /// REVISED 2026-08-28, explicit user request: mid-trip switching is
  /// now always silent (see AutoTripDetectionService._pollForMidTripSwitch),
  /// same as trip-start -- no more "ask" mode. The switch already
  /// happened by the time this fires, purely informational.
  Future<void> showMidTripAutoSwitchedNotification({required String gigAppId}) async {
    if (!_initialized) return;
    if (!await isTypeEnabled(prefGigAppSwitch)) return;

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
          color: kBrandSeed,
        ),
        iOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
        macOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
      ),
    );
  }
}
