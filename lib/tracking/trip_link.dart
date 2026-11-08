// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/trip_link.dart
//
// One trip engine (2026-11-07, chosen after comparing with MileIQ, whose single
// drive service owns every drive). On Android each trip belongs to ONE background
// Flutter engine, the one DriveWakeService runs: it receives the GPS, starts,
// switches, pauses and ends trips, and runs the 10-minute clock. The open app runs
// no trip logic: it sends commands here and mirrors what the engine reports, so the
// screens keep reading TrackingController as before.
//
// Before this, the open app, the wake engine and Tracelet's headless engine could
// each hold their own copy of the same trip: duplicated trips, one engine turning
// off another's GPS, trips dying with the engine that started them.
//
// Both engines run in the same process, so they talk through IsolateNameServer:
// the engine listens on [_enginePortName] for commands, the app on [_appPortName]
// for state. iOS keeps the old single-isolate path (no wake engine there).

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer, PluginUtilities;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/diag_log.dart';
import 'auto_trip_detection_service.dart';
import 'background_gps_service.dart';
import 'drive_wake.dart';
import 'tracking_controller.dart';

class TripLink {
  TripLink._();

  static const _enginePortName = 'cm_trip_engine';
  static const _appPortName = 'cm_trip_app';

  /// True in the open app on Android: trip work goes to the engine.
  static bool isClient = false;

  /// True inside the trip engine.
  static bool isEngine = false;

  // ============================================================
  // APP SIDE
  // ============================================================
  static ReceivePort? _appPort;
  static int _nextId = 0;
  static final Map<int, Completer<Object?>> _pending = {};

  /// Called once by the app before any screen reads a trip.
  static void startClient() {
    if (kIsWeb || !Platform.isAndroid) return;
    isClient = true;
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(_appPortName);
    IsolateNameServer.registerPortWithName(port.sendPort, _appPortName);
    _appPort = port;
    port.listen(_onEngineMessage);
  }

  static void _onEngineMessage(dynamic msg) {
    if (msg is! Map) return;
    final state = msg['state'];
    if (state is Map) TrackingController.applyEngineState(Map<String, Object?>.from(state));
    if (msg['type'] == 'event') {
      TrackingController.applyEngineEvent(msg['name'] as String, msg['value']);
    } else if (msg['type'] == 'reply') {
      _pending.remove(msg['id'])?.complete(msg['result']);
    }
  }

  static SendPort? get _engine => IsolateNameServer.lookupPortByName(_enginePortName);

  /// Starts the engine when it is not running, and waits for it to listen.
  static Future<SendPort?> _ensureEngine() async {
    final running = _engine;
    if (running != null) return running;
    final handle = PluginUtilities.getCallbackHandle(driveWakeEntry);
    if (handle == null) return null;
    try {
      await const MethodChannel('controlmiles/drive_wake').invokeMethod('startEngine', {'handle': handle.toRawHandle()});
    } catch (e) {
      DiagLog.add('engine start failed', {'error': e});
      return null;
    }
    for (var i = 0; i < 75; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final port = _engine;
      if (port != null) return port;
    }
    DiagLog.add('engine did not come up');
    return null;
  }

  /// Sends one command and returns the engine's answer (null when unreachable).
  /// [start]: bring the engine up if it is not running.
  static Future<Object?> command(String name, [Map<String, Object?> args = const {}, bool start = true]) async {
    if (_appPort == null) return null;
    final port = start ? await _ensureEngine() : _engine;
    if (port == null) return null;
    final id = ++_nextId;
    final done = Completer<Object?>();
    _pending[id] = done;
    port.send({'id': id, 'cmd': name, 'args': args});
    return done.future.timeout(const Duration(seconds: 90), onTimeout: () {
      _pending.remove(id);
      return null;
    });
  }

  // ============================================================
  // ENGINE SIDE
  // ============================================================
  static DateTime _lastCommandAt = DateTime.now();
  static Timer? _pushTimer;
  static String? _lastSent;
  static int _sentRoutePoints = 0;

  /// How long since the app last asked the engine for anything.
  static Duration get idleFor => DateTime.now().difference(_lastCommandAt);

  static void serve() {
    isEngine = true;
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(_enginePortName);
    IsolateNameServer.registerPortWithName(port.sendPort, _enginePortName);
    port.listen(_onCommand);
    _pushTimer = Timer.periodic(const Duration(seconds: 1), (_) => pushState());
    TrackingController.autoFlashEvent.addListener(() => _forward('autoFlash', TrackingController.autoFlashEvent));
    TrackingController.segmentDiscarded.addListener(() => _forward('segmentDiscarded', TrackingController.segmentDiscarded));
  }

  static void stopServing() {
    _pushTimer?.cancel();
    IsolateNameServer.removePortNameMapping(_enginePortName);
  }

  /// One-shot signals go to the app and are cleared here, so the next one fires again.
  static void _forward(String name, ValueNotifier<String?> notifier) {
    final value = notifier.value;
    if (value == null) return;
    IsolateNameServer.lookupPortByName(_appPortName)?.send({'type': 'event', 'name': name, 'value': value});
    scheduleMicrotask(() => notifier.value = null);
  }

  static Map<String, Object?> _state({bool fullRoute = false}) {
    final s = TrackingController.engineState();
    final route = TrackingController.liveRoute.value;
    if (fullRoute || route.length < _sentRoutePoints) _sentRoutePoints = 0;
    s['routeFrom'] = _sentRoutePoints;
    s['route'] = [for (final p in route.skip(_sentRoutePoints)) ...[p.lat, p.lng]];
    _sentRoutePoints = route.length;
    return s;
  }

  /// Sends the trip's state to the app when it changed (the app may be closed).
  static void pushState() {
    final app = IsolateNameServer.lookupPortByName(_appPortName);
    if (app == null) return;
    final key = '${TrackingController.engineState()}#${TrackingController.liveRoute.value.length}';
    if (key == _lastSent) return;
    _lastSent = key;
    app.send({'type': 'state', 'state': _state()});
  }

  static final Completer<void> _ready = Completer<void>();

  /// The engine recovered any open trip: commands may run now. One that came in
  /// earlier waited, so a recovery can never wipe a trip a command just started.
  static void markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  static Future<void> _onCommand(dynamic msg) async {
    if (msg is! Map) return;
    _lastCommandAt = DateTime.now();
    await _ready.future;
    final cmd = msg['cmd'] as String? ?? '';
    final args = Map<String, Object?>.from((msg['args'] as Map?) ?? const {});
    Object? result;
    try {
      result = await _run(cmd, args);
    } catch (e) {
      DiagLog.add('engine command failed', {'cmd': cmd, 'error': e});
    }
    _lastCommandAt = DateTime.now();
    _lastSent = null;
    IsolateNameServer.lookupPortByName(_appPortName)
        ?.send({'type': 'reply', 'id': msg['id'], 'result': result, 'state': _state(fullRoute: true)});
  }

  static Future<Object?> _run(String cmd, Map<String, Object?> a) async {
    switch (cmd) {
      case 'hello':
        return true;
      case 'start':
        await AutoTripDetectionService.instance.reloadShiftStartOdometer();
        await TrackingController.startTripFlow(
          context: null,
          gigApp: a['gigApp'] as String,
          irsPurpose: a['irsPurpose'] as String?,
          organizationId: a['organizationId'] as String?,
          shiftBlockId: a['shiftBlockId'] as String?,
          preSelectedVehicleId: a['preSelectedVehicleId'] as String?,
          useAutoDetectOdometer: a['useAutoDetectOdometer'] == true,
        );
        // Started from the button: not an automatic trip (no flash, no auto purpose).
        TrackingController.startedViaAutoDetect = false;
        return TrackingController.currentState == TrackingState.running;
      case 'pause':
        return TrackingController.pauseTracking();
      case 'resume':
        return TrackingController.resumeTracking();
      case 'switch':
        return TrackingController.switchSection(a['gigApp'] as String, irsPurpose: a['irsPurpose'] as String?);
      case 'stop':
        return TrackingController.stopTracking(askPurposeInApp: a['askPurposeInApp'] == true);
      case 'resync':
        await BackgroundGpsService.resyncNotification();
        return true;
    }
    return null;
  }
}
