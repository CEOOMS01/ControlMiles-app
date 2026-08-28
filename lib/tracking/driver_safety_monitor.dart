// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/driver_safety_monitor.dart
//
// Fleet driver-safety event detection (see [[project_controlmiles]]).
// Explicit user request: reuse GPS ticks already flowing through
// TrackingController.processGpsTick's Fleet-only block (same one that
// already writes session_gps_breadcrumbs / update_vehicle_location) to
// surface harsh braking, hard acceleration, and speeding on the org
// admin's ControlMiles Fleet WEB dashboard (controlmiles-web,
// src/app/admin/safety/) -- no new hardware, no new data collection.
//
// Deliberately a separate class from AntifraudEngine, not an extension
// of it: AntifraudEngine's maxAccelerationMps2 (8.0) exists to REJECT
// GPS-spoofed ticks, tuned far above anything a real vehicle does.
// Conflating the two would risk loosening antifraud's own carefully-
// tuned spoof detection. This class only ever runs on ticks
// AntifraudEngine already accepted (result.isValid), with its own
// thresholds tuned for real driving behavior instead.
//
// Speeding uses a fixed, not road-aware, ceiling -- no maps/speed-limit
// API is integrated. A known, documented simplification, not an
// oversight; the same category of simplification most competitors'
// entry tiers use too (see the competitor research in
// [[project_controlmiles]]).

class SafetyEvent {
  final String type; // 'harsh_braking' | 'hard_acceleration' | 'speeding'
  final double speedMps;

  const SafetyEvent(this.type, this.speedMps);
}

class DriverSafetyMonitor {
  static const double _harshBrakingThresholdMps2 = -3.5;
  static const double _hardAccelerationThresholdMps2 = 3.5;
  static const double _speedingThresholdMps = 33.5; // ~75 mph / ~120 km/h

  // Debounce: a sustained hard stop or a long stretch over the speed
  // ceiling should log ONE event, not one per tick. Tracks which event
  // type (if any) is already "open" and only re-fires after it clears.
  static String? _activeEventType;

  static double? _lastSpeed;
  static DateTime? _lastTimestamp;

  static void reset() {
    _lastSpeed = null;
    _lastTimestamp = null;
    _activeEventType = null;
  }

  /// Call only with ticks AntifraudEngine already accepted. Returns the
  /// detected event, or null if nothing crossed a threshold this tick.
  static SafetyEvent? evaluate({
    required double speed,
    required DateTime timestamp,
  }) {
    final prevSpeed = _lastSpeed;
    final prevTimestamp = _lastTimestamp;
    _lastSpeed = speed;
    _lastTimestamp = timestamp;

    if (speed > _speedingThresholdMps) {
      if (_activeEventType == 'speeding') return null;
      _activeEventType = 'speeding';
      return SafetyEvent('speeding', speed);
    }

    if (prevSpeed == null || prevTimestamp == null) {
      _activeEventType = null;
      return null;
    }

    final deltaSeconds = timestamp.difference(prevTimestamp).inMilliseconds / 1000.0;
    if (deltaSeconds <= 0) {
      _activeEventType = null;
      return null;
    }

    final accelMps2 = (speed - prevSpeed) / deltaSeconds;

    if (accelMps2 <= _harshBrakingThresholdMps2) {
      if (_activeEventType == 'harsh_braking') return null;
      _activeEventType = 'harsh_braking';
      return SafetyEvent('harsh_braking', speed);
    }

    if (accelMps2 >= _hardAccelerationThresholdMps2) {
      if (_activeEventType == 'hard_acceleration') return null;
      _activeEventType = 'hard_acceleration';
      return SafetyEvent('hard_acceleration', speed);
    }

    _activeEventType = null;
    return null;
  }
}
