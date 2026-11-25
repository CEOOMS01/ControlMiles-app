// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/update_gate.dart
//
// The screen that stops the app when a newer version exists (2026-11-24): it cannot be
// dismissed, it stays when the driver comes back from Google Play without updating, and
// it is checked again every time the app is opened. The app underneath is kept (hidden,
// not rebuilt) so nothing is lost if the notice goes away. Background trip recording is
// not touched, and a trip in progress delays the notice (see AppUpdateService).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../services/app_update_service.dart';
import '../services/supabase_bootstrap.dart';

class UpdateGate extends StatefulWidget {
  final Widget child;

  /// False in tests, which set AppUpdateService.requirement themselves.
  final bool checkOnStart;
  const UpdateGate({super.key, required this.child, this.checkOnStart = true});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.checkOnStart) unawaited(_firstCheck());
  }

  Future<void> _firstCheck() async {
    try {
      await SupabaseBootstrap.ensure();
    } catch (_) {
      // Offline or slow start: refresh() falls back to what the phone learned before.
    }
    await AppUpdateService.refresh(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.checkOnStart) {
      unawaited(AppUpdateService.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UpdateRequirement?>(
      valueListenable: AppUpdateService.requirement,
      builder: (context, requirement, _) {
        // Same widget tree whether blocked or not, so the app underneath keeps its state.
        return Stack(
          fit: StackFit.expand,
          children: [
            Offstage(offstage: requirement != null, child: widget.child),
            if (requirement != null)
              UpdateRequiredScreen(requirement: requirement),
          ],
        );
      },
    );
  }
}

class UpdateRequiredScreen extends StatelessWidget {
  final UpdateRequirement requirement;
  const UpdateRequiredScreen({super.key, required this.requirement});

  @override
  Widget build(BuildContext context) {
    final tr = context.read<AppState>().tr;
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.system_update_alt_rounded,
                      size: 56,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      tr('update_available_title'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr('update_required_body'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: AppUpdateService.openStore,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(tr('update_now')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
