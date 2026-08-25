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

class CreateOrganizationScreen extends StatefulWidget {
  const CreateOrganizationScreen({super.key});

  @override
  State<CreateOrganizationScreen> createState() => _CreateOrganizationScreenState();
}

class _CreateOrganizationScreenState extends State<CreateOrganizationScreen> {
  final _nameController = TextEditingController();
  final _organizationService = OrganizationService();
  bool _isProcessing = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createOrganization(AppState appState) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = appState.tr('field_required'));
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      await _organizationService.createOrganization(name);

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
        setState(() => _error = '${appState.tr('error')}: ${e.toString()}');
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
          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.accountType),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
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
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () => _createOrganization(appState),
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
