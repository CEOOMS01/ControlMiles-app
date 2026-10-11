// Olympus Mont Systems LLC - ControlMiles
// lib/config/app_flavor.dart
//
// Gig / Fleet split (2026-10-11): one codebase, two store apps.
//   * gig   -> "ControlMiles"        com.olimsys.controlmiles
//              personal mileage for gig drivers: personal trips only,
//              Google Play plans, auto-detect, IRS reports.
//   * fleet -> "ControlMiles Fleet"  com.olimsys.controlmiles.fleet
//              fleet drivers, bus monitors and the owner's quick look;
//              fleet trips only, no personal plans. Fleet management and
//              billing stay on controlmiles.com.
//
// The flavor comes from `flutter run/build --flavor gig|fleet` (Flutter's
// own appFlavor constant). It decides the app's mode -- never
// profiles.account_type, which one person with both apps installed would
// otherwise flip back and forth.

import 'package:flutter/services.dart' show appFlavor;

class AppFlavor {
  AppFlavor._();

  static final bool isFleet = appFlavor == 'fleet';
  static bool get isGig => !isFleet;

  static const gigPackage = 'com.olimsys.controlmiles';
  static const fleetPackage = 'com.olimsys.controlmiles.fleet';

  static String get packageName => isFleet ? fleetPackage : gigPackage;

  static const gigStoreUrl = 'https://play.google.com/store/apps/details?id=$gigPackage';
  static const fleetStoreUrl = 'https://play.google.com/store/apps/details?id=$fleetPackage';
}
