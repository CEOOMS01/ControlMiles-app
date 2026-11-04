// Olympus Mont Systems LLC - ControlMiles
// lib/services/work_place_service.dart
//
// Work places (2026-11-01, Gig Premium): when the driver stays ~2.5 minutes
// inside one of their saved places during their work hours, show "Arrived at
// X -- start tracking?". When they leave a place with a trip running, show
// "Stop tracking?". Reminders only, unless the driver gave the place a purpose
// (2026-11-03): then, with the opt-in switch on, arriving starts a trip of that
// purpose, and a purpose trip that sits ~3 minutes inside a place with a
// purpose is closed. Gig-app trips are never touched.
//
// Uses Tracelet's native geofences (same engine as the trip GPS). Location
// never leaves the phone for this. Premium only: setPremium() is called by
// AppState, and a lapsed account has its geofences removed.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracelet/tracelet.dart' as tl;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../tracking/tracking_controller.dart';
import 'local_storage_service.dart';
import 'notification_service.dart';
import 'odometer_capture_service.dart';
import 'vehicle_service.dart';
import 'work_places.dart';
import 'work_schedule.dart';

class WorkPlaceService {
  WorkPlaceService._();

  static const _kPremium = 'work_places_premium';

  /// Stay this long inside a place before the arrival reminder, the opt-in
  /// auto start, or the auto stop of a purpose trip (ms).
  static const int dwellMs = 180000;

  static Future<void> setPremium(bool premium) async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getBool(_kPremium) ?? false) == premium) return;
    await prefs.setBool(_kPremium, premium);
    await sync();
  }

  static Future<bool> _isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPremium) ?? false;
  }

  /// Makes the native geofences match the saved places. Safe to call any
  /// time (idempotent). Never touches a trip that is already being recorded:
  /// the geofence-only mode is started only when the engine is idle.
  static Future<void> sync() async {
    try {
      final existing = await tl.Tracelet.getGeofences();
      for (final g in existing) {
        if (g.identifier.startsWith(WorkPlace.idPrefix)) {
          await tl.Tracelet.removeGeofence(g.identifier);
        }
      }

      final wanted = (await _isPremium() &&
              await NotificationService.instance.isTypeEnabled(NotificationService.prefWorkPlaces))
          ? await WorkPlaceStore.load()
          : <WorkPlace>[];
      if (wanted.isEmpty) return;

      await tl.Tracelet.addGeofences([
        for (final p in wanted)
          tl.Geofence(
            identifier: p.geofenceId,
            latitude: p.latitude,
            longitude: p.longitude,
            radius: p.radius,
            notifyOnEntry: false,
            notifyOnExit: true,
            notifyOnDwell: true,
            loiteringDelay: dwellMs,
            extras: {'name': p.name},
          ),
      ]);

      // Idle engine -> geofence-only mode (very low battery). If a trip or
      // auto-detect is already running, the geofences work in that mode too.
      final state = await tl.Tracelet.getState();
      if (!state.enabled) await tl.Tracelet.startGeofences();
    } catch (e) {
      debugPrint('[WorkPlaceService] sync failed: $e');
    }
  }

  /// After a trip ends the engine is stopped, which also stops the geofences:
  /// bring the geofence-only mode back.
  static Future<void> rearmAfterTrip() => sync();

  /// Foreground and headless (app closed) geofence events both end here.
  static Future<void> handleEvent(tl.GeofenceEvent event) async {
    if (!event.identifier.startsWith(WorkPlace.idPrefix)) return;
    try {
      if (!await _isPremium()) return;
      if (!await NotificationService.instance.isTypeEnabled(NotificationService.prefWorkPlaces)) {
        return;
      }
      final name = (event.extras['name'] as String?) ?? '';
      final tripActive = await LocalStorageService.hasActiveTrip();
      final place = await _placeFor(event.identifier);

      if (event.action == tl.GeofenceAction.dwell) {
        if (tripActive) {
          // Parked at a place that has a purpose, with a trip of that kind
          // running and nothing moving for the dwell time: the trip is over.
          if (place?.purpose != null && await _autoStop()) {
            await NotificationService.instance.showWorkPlaceAutoStopped(name);
          }
          return;
        }
        if (!await _insideWorkHours(DateTime.now())) return;
        if (place?.purpose != null && await WorkPlaceStore.autoStart() && await _autoStart(place!)) {
          await NotificationService.instance.showWorkPlaceAutoStarted(name);
          return;
        }
        await NotificationService.instance.showWorkPlaceArrival(name);
      } else if (event.action == tl.GeofenceAction.exit) {
        // Leaving a place that has a purpose is how its trip begins: no
        // "stop tracking?" reminder there (the arrival closes it instead).
        if (!tripActive || place?.purpose != null) return;
        await NotificationService.instance.showWorkPlaceExit(name);
      }
    } catch (e) {
      debugPrint('[WorkPlaceService] handleEvent failed: $e');
    }
  }

  static Future<WorkPlace?> _placeFor(String geofenceId) async {
    for (final p in await WorkPlaceStore.load()) {
      if (p.geofenceId == geofenceId) return p;
    }
    return null;
  }

  /// Opt-in start at a place that has a purpose. Only from the running app
  /// (it needs the session and the navigator), and only when it can start
  /// with no screen: if this week's odometer photo is still missing, the
  /// driver gets the normal reminder instead. Returns true if a trip started.
  static Future<bool> _autoStart(WorkPlace place) async {
    try {
      if (TrackingController.currentState != TrackingState.idle) return false;
      final nav = NotificationService.instance.navigatorKey?.currentState;
      final user = Supabase.instance.client.auth.currentUser;
      if (nav == null || user == null) return false;

      final vehicle = await VehicleService().getActiveOrAssignedVehicle(user.id);
      if (vehicle != null && await OdometerCaptureService().needsCheckpointStartThisWeek(vehicle.id)) {
        return false;
      }
      if (!nav.mounted) return false;

      await TrackingController.startTripFlow(
        context: nav.context,
        gigApp: 'custom',
        irsPurpose: place.purpose,
      );
      return TrackingController.currentState == TrackingState.running;
    } catch (e) {
      debugPrint('[WorkPlaceService] auto start failed: $e');
      return false;
    }
  }

  /// Ends a purpose trip (never a gig-app trip, whose long stops are normal).
  /// Runs only where the trip lives in memory, i.e. the running app; from a
  /// closed app the exit reminder still shows. Returns true if it closed.
  static Future<bool> _autoStop() async {
    try {
      if (TrackingController.currentState == TrackingState.idle ||
          TrackingController.activeSessionId == null ||
          TrackingController.currentGigApp != 'custom') {
        return false;
      }
      return await TrackingController.stopTracking();
    } catch (e) {
      debugPrint('[WorkPlaceService] auto stop failed: $e');
      return false;
    }
  }

  /// With the work-hours reminder on, places alert only inside those hours
  /// (and days). With it off, there is no schedule to respect: always.
  static Future<bool> _insideWorkHours(DateTime now) async {
    final s = await WorkSchedule.load();
    if (!s.enabled) return true;
    final minutes = now.hour * 60 + now.minute;
    final overnight = s.endMinutes <= s.startMinutes;
    if (!overnight) {
      return s.days.contains(now.weekday) &&
          minutes >= s.startMinutes &&
          minutes < s.endMinutes;
    }
    // Night shift: the evening part belongs to today's day, the early-morning
    // part to yesterday's.
    if (minutes >= s.startMinutes) return s.days.contains(now.weekday);
    if (minutes < s.endMinutes) {
      return s.days.contains(now.weekday == 1 ? 7 : now.weekday - 1);
    }
    return false;
  }
}
