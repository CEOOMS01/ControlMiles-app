// The plugin has no Dart API: the app talks to it through the MethodChannel
// 'controlmiles/gig_app_detection' (see lib/services/gig_app_detection_service.dart).
// It exists as a plugin only so Flutter registers it in EVERY engine, including
// the headless one Android starts while the app is closed.
library;
