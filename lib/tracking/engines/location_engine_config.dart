// Olympus Mont Systems LLC - ControlMiles
// lib/tracking/engines/location_engine_config.dart
//
// Single switch selecting which background-location engine
// BackgroundGpsService delegates to. See that file's own header comment
// for the full picture; this file exists on its own so flipping the
// switch later never requires touching engine code.
//
// - useBackgroundGeolocationPaidEngine = false (default, current state):
//   `tracelet` (free, Apache-2.0, github.com/Ikolvi/Tracelet) is active.
//   Chosen 2026-09-15 specifically because flutter_background_geolocation's
//   production license ($300 one-time) wasn't affordable before launch --
//   see TraceletEngine's own header for why this specific package and not
//   a hand-rolled location+activity-recognition combo.
// - useBackgroundGeolocationPaidEngine = true: BgGeolocationEngine (the
//   original, already-built integration, untouched) takes over instead.
//   Flip this the day the license is purchased -- no other file needs to
//   change. Both engines implement the exact same
//   initialize()/startTracking()/stopTracking()/isRunning surface
//   BackgroundGpsService and every one of its callers already depend on.
const bool useBackgroundGeolocationPaidEngine = false;
