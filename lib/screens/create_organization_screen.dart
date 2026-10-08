// Olympus Mont Systems LLC - ControlMiles
// lib/screens/create_organization_screen.dart
//
// Fleet Phase 1: the only path into Fleet mode this phase supports is
// creating a brand-new organization and becoming its owner (the
// create_organization RPC -- atomic, see supabase/migrations). Joining an
// existing fleet via invite is Phase 2, not wired here yet.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../routes/app_routes.dart';
import '../services/organization_service.dart';
import '../errors/app_error.dart';

class CreateOrganizationScreen extends StatefulWidget {
  const CreateOrganizationScreen({super.key});

  @override
  State<CreateOrganizationScreen> createState() => _CreateOrganizationScreenState();
}

// Fleet profiles (2026-09-30): same list as the web onboarding
// (controlmiles-web src/lib/fleet-profiles.ts).
const _fleetTypes = [
  ('delivery', 'fleet_profile_delivery', 'fleet_profile_delivery_desc'),
  ('field_service', 'fleet_profile_field_service', 'fleet_profile_field_service_desc'),
  ('trucking', 'fleet_profile_trucking', 'fleet_profile_trucking_desc'),
  ('construction', 'fleet_profile_construction', 'fleet_profile_construction_desc'),
  ('passenger', 'fleet_profile_passenger', 'fleet_profile_passenger_desc'),
  ('school_transport', 'fleet_profile_school', 'fleet_profile_school_desc'),
  ('sales', 'fleet_profile_sales', 'fleet_profile_sales_desc'),
  ('driving_school', 'fleet_type_driving_school', 'fleet_type_driving_school_desc'),
  ('general', 'fleet_profile_general', 'fleet_profile_general_desc'),
];

class _CreateOrganizationScreenState extends State<CreateOrganizationScreen> {
  final _nameController = TextEditingController();
  final _organizationService = OrganizationService();
  bool _isProcessing = false;
  String? _error;
  // "What kind of fleet is it?" (2026-09-29). 2026-10-03: nothing is
  // preselected and the owner confirms it -- the type is locked once the
  // fleet exists (set_fleet_type -> FLEET_TYPE_LOCKED; support changes it).
  String? _fleetType;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createOrganization(AppState appState, String fleetTypeTitle) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = appState.tr('field_required'));
      return;
    }
    final fleetType = _fleetType;
    if (fleetType == null) {
      setState(() => _error = appState.tr('fleet_type_choose_first'));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appState.tr('fleet_type_confirm_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fleetTypeTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            Text(appState.tr('fleet_type_hint')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(appState.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(appState.tr('confirm'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      await _organizationService.createOrganization(name, industryTemplate: fleetType);

      // El RPC ya promovió profiles.account_type a 'fleet_admin' server-side
      // -- esto solo refresca la copia en memoria/caché de AppState para
      // que isFleetAdmin sea true en el resto de esta sesión sin reiniciar
      // la app.
      await appState.refreshAccountType();
      await appState.completeAccountTypeChoice();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.fleetDashboard);
    } catch (e) {
      if (mounted) {
        final appError = AppError.from(e);
        setState(() => _error = appError.display(appState.tr(appError.messageKey)));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.roleChooser),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.local_shipping_rounded, size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                appState.tr('create_fleet_title'),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(height: 6),
              Text(
                appState.tr('create_fleet_subtitle'),
                style: TextStyle(fontSize: 13, color: subTextColor),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                enabled: !_isProcessing,
                decoration: InputDecoration(
                  labelText: appState.tr('fleet_name_label'),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                appState.tr('fleet_type_question'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
              ),
              const SizedBox(height: 8),
              for (final option in _fleetTypes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _isProcessing ? null : () => setState(() => _fleetType = option.$1),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _fleetType == option.$1
                              ? Theme.of(context).colorScheme.primary
                              : borderColor,
                          width: _fleetType == option.$1 ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _fleetType == option.$1
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(appState.tr(option.$2),
                                    style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),
                                Text(appState.tr(option.$3),
                                    style: TextStyle(fontSize: 12.5, color: subTextColor)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 15, color: subTextColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(appState.tr('fleet_type_hint'),
                        style: TextStyle(fontSize: 11.5, color: subTextColor)),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isProcessing || _fleetType == null)
                      ? null
                      : () => _createOrganization(
                            appState,
                            appState.tr(_fleetTypes.firstWhere((t) => t.$1 == _fleetType).$2),
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          appState.tr('create_fleet_button').toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
