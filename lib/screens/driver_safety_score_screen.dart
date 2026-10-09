// Olympus Mont Systems LLC - ControlMiles
// lib/screens/driver_safety_score_screen.dart
//
// "My safety score" (2026-09-30): the driver's own score lives here --
// opened from Settings or from a 15-day summary message -- instead of on
// the driver's main screen, per explicit user request (like Samsara's
// "You" tab). Same numbers the fleet admin sees on the web.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../widgets/driver_safety_score_card.dart';

class DriverSafetyScoreScreen extends StatelessWidget {
  const DriverSafetyScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF12100C) : const Color(0xFFFAF6EE);
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF6B6250);
    final orgId = appState.defaultOrgId;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(appState.tr('safety_score_title')),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (orgId != null) DriverSafetyScoreCard(organizationId: orgId),
            const SizedBox(height: 16),
            Text(appState.tr('safety_score_how'), style: TextStyle(fontSize: 12.5, height: 1.4, color: subTextColor)),
          ],
        ),
      ),
    );
  }
}
