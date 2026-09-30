// Olympus Mont Systems LLC - ControlMiles
// lib/screens/register_own_vehicle_screen.dart
//
// Owner-operators (2026-09-30, explicit user request: "otra opción cuando
// el driver maneja su propio truck"). When the fleet allows it (web
// Settings), a driver without a company vehicle registers their own here;
// it joins the fleet marked driver-owned and assigned to them, so the
// normal pre-trip + trip flow follows. Server: register_my_own_vehicle.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_error.dart';
import '../logic/app_state.dart';

class RegisterOwnVehicleScreen extends StatefulWidget {
  final String organizationId;

  const RegisterOwnVehicleScreen({super.key, required this.organizationId});

  @override
  State<RegisterOwnVehicleScreen> createState() => _RegisterOwnVehicleScreenState();
}

class _RegisterOwnVehicleScreenState extends State<RegisterOwnVehicleScreen> {
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _plate = TextEditingController();
  final _vin = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_make, _model, _year, _plate, _vin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(AppState appState) async {
    if (_saving) return;
    if (_make.text.trim().isEmpty || _model.text.trim().isEmpty) {
      setState(() => _error = appState.tr('own_vehicle_make_model_required'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc('register_my_own_vehicle', params: {
        'p_organization_id': widget.organizationId,
        'p_make': _make.text.trim(),
        'p_model': _model.text.trim(),
        'p_year': int.tryParse(_year.text.trim()),
        'p_plate': _plate.text.trim(),
        'p_vin': _vin.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final err = AppError.from(e);
      setState(() {
        _saving = false;
        _error = err.display(appState.tr(err.messageKey));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        );

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(appState.tr('own_vehicle_title')),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(appState.tr('own_vehicle_intro'), style: TextStyle(fontSize: 13, height: 1.4, color: subTextColor)),
            const SizedBox(height: 16),
            TextField(controller: _make, textCapitalization: TextCapitalization.words, decoration: deco(appState.tr('own_vehicle_make'))),
            const SizedBox(height: 12),
            TextField(controller: _model, textCapitalization: TextCapitalization.words, decoration: deco(appState.tr('own_vehicle_model'))),
            const SizedBox(height: 12),
            TextField(controller: _year, keyboardType: TextInputType.number, decoration: deco(appState.tr('own_vehicle_year'))),
            const SizedBox(height: 12),
            TextField(controller: _plate, textCapitalization: TextCapitalization.characters, decoration: deco(appState.tr('own_vehicle_plate'))),
            const SizedBox(height: 12),
            TextField(controller: _vin, textCapitalization: TextCapitalization.characters, decoration: deco(appState.tr('own_vehicle_vin'))),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : () => _save(appState),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(appState.tr('own_vehicle_save').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
