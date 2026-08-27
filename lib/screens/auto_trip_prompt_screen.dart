// Olympus Mont Systems LLC - ControlMiles
// lib/screens/auto_trip_prompt_screen.dart
//
// Premium Gig feature: shown when AutoTripDetectionService detects
// motion with no active trip. Explicit user requirement -- odometer
// entry stays mandatory "en ese mismo momento" even for an
// auto-detected trip, so this screen doesn't silently start tracking;
// it only pre-fills the moment of confirmation, then hands off to the
// exact same TrackingController.startTripFlow every manual trip already
// goes through (odometer capture included, same antifraud/audit path).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../tracking/auto_trip_detection_service.dart';
import '../tracking/tracking_controller.dart';
import '../widgets/gig_app_selector.dart';

class AutoTripPromptScreen extends StatefulWidget {
  const AutoTripPromptScreen({super.key});

  @override
  State<AutoTripPromptScreen> createState() => _AutoTripPromptScreenState();
}

class _AutoTripPromptScreenState extends State<AutoTripPromptScreen> {
  String? _selectedGigApp;
  String? _selectedIrsPurpose;
  bool _isStarting = false;
  bool _prefilledFromArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-selects the gig app AutoTripDetectionService already detected
    // (foreground-app polling) -- still just a suggestion, the selector
    // below stays fully editable, the user confirms either way.
    if (!_prefilledFromArgs) {
      _prefilledFromArgs = true;
      final detectedGigAppId = ModalRoute.of(context)?.settings.arguments as String?;
      if (detectedGigAppId != null && detectedGigAppId.isNotEmpty) {
        _selectedGigApp = detectedGigAppId;
      }
    }
  }

  @override
  void dispose() {
    // Covers the back-button/swipe-to-dismiss paths too, not just the
    // two explicit buttons below -- either way the notification/guard
    // must clear so the NEXT real motion detection can prompt again.
    AutoTripDetectionService.instance.clearPrompt();
    super.dispose();
  }

  Future<void> _confirm(AppState appState) async {
    if (_selectedGigApp == null || _isStarting) {
      if (_selectedGigApp == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appState.tr('select_an_activity_before_starting_tracking'))),
        );
      }
      return;
    }

    setState(() => _isStarting = true);
    await TrackingController.startTripFlow(
      context: context,
      gigApp: _selectedGigApp!,
      irsPurpose: _selectedGigApp == 'custom' ? _selectedIrsPurpose : null,
      // Carries forward the shift-start reading captured when auto-detect
      // was turned on, instead of asking for the odometer again on every
      // detected trip -- falls back to the normal per-trip camera screen
      // on its own if that cache is somehow empty (e.g. cleared mid-shift
      // some other way), see TrackingController.startTripFlow itself.
      useAutoDetectOdometer: true,
    );

    // startTripFlow navigates internally (odometer capture) and only
    // returns once that whole flow is done (confirmed or cancelled) --
    // either way this screen's job is finished.
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return PopScope(
      canPop: !_isStarting,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(
            appState.tr('auto_trip_prompt_title').toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
          ),
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions_car_filled_rounded, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        appState.tr('auto_trip_prompt_body'),
                        style: TextStyle(fontSize: 13, color: textColor, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GigAppSelector(
                selectedGigApp: _selectedGigApp,
                activeGigApp: null,
                onAppSelected: (appId) => setState(() {
                  _selectedGigApp = appId;
                  _selectedIrsPurpose = null;
                }),
                onCustomSelected: (appId, irsPurpose) => setState(() {
                  _selectedGigApp = appId;
                  _selectedIrsPurpose = irsPurpose;
                }),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isStarting ? null : () => _confirm(appState),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isStarting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          appState.tr('auto_trip_prompt_confirm'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isStarting ? null : () => Navigator.pop(context),
                  child: Text(
                    appState.tr('auto_trip_prompt_dismiss'),
                    style: TextStyle(color: subTextColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
