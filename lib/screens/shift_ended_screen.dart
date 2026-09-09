// Olympus Mont Systems LLC - ControlMiles
// lib/screens/shift_ended_screen.dart
//
// Fleet Sprint 3 (shift-scoped privacy, 2026-09-09, explicit user request):
// reached the instant a fleet_driver ends their trip/turno (see
// TrackingActionButton._handleEndTrip -> DriverOperationsScreen.onTripEnded),
// AFTER any mandatory weekly odometer-close dialog already resolved. A
// dead end on purpose -- no drawer, no Settings, no Vehicle info, nothing
// but "start the next turno" or sign out -- so a driver has zero
// functional access to the app outside their assigned working hours,
// without the App Store/Play Store risk of literally force-quitting the
// process (which also wouldn't add any real privacy beyond what the
// background auto-detect exclusion already covers for fleet accounts).
// Gig accounts never reach this screen -- Dashboard's own onTripEnded
// callback doesn't navigate anywhere, matching the user's explicit
// scope ("solo... driver fleet, no... gig app").

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../routes/app_routes.dart';

class ShiftEndedScreen extends StatelessWidget {
  const ShiftEndedScreen({super.key});

  Future<void> _signOut(BuildContext context, AppState appState) async {
    await appState.signOutAndClear();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final primary = Theme.of(context).colorScheme.primary;

    return PopScope(
      // No back-navigation escape hatch into DriverOperationsScreen's
      // still-idle-but-technically-usable state -- the only two ways out
      // are the buttons below.
      canPop: false,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bedtime_rounded, size: 56, color: primary),
                  const SizedBox(height: 20),
                  Text(
                    appState.tr('shift_ended_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    appState.tr('shift_ended_body'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: subTextColor),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.driverOperations,
                        (route) => false,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        appState.tr('shift_ended_start_next').toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => _signOut(context, appState),
                    child: Text(
                      appState.tr('sign_out'),
                      style: TextStyle(color: subTextColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
