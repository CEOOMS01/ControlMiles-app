// Olympus Mont Systems LLC - ControlMiles
// lib/screens/fuel_purchase_capture_screen.dart
//
// Fuel purchase capture, piece 2 of the real IFTA build (explicit user
// request, 2026-09-17): the missing input that keeps a fileable IFTA
// return out of reach -- gallons purchased per jurisdiction can only ever
// come from the driver's own receipt, no public source has it (see
// ifta_fuel_tax_rates for the other half, the tax RATE, which is public).
//
// Single photo (image_picker, same as vehicle_inspection_screen.dart --
// no live-stream camera pipeline needed for a receipt), one OCR pass
// (FuelReceiptOcrService), then every extracted field lands in an
// editable form the driver confirms or corrects before submitting --
// OCR here is a convenience prefill, never a blind auto-submit, same
// philosophy as odometer capture's manual-override path.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../models/vehicle.dart';
import '../services/fuel_purchase_service.dart';
import '../services/fuel_receipt_ocr_service.dart';
import '../errors/app_error.dart';

// Real US states IFTA actually covers (Alaska/Hawaii excluded -- matches
// ifta_us_state_boundaries and the real IFTA tax matrix synced from
// iftach.org, see sync-ifta-tax-rates's own header comment for why those
// two aren't in the matrix at all). Kept as a flat list here rather than
// a DB round-trip -- same 50-item stability as the tax rate matrix's own
// hardcoded fuel-type list, and a driver picking a state needs this
// instantly, not after a network call.
const List<(String, String)> _kIftaStates = [
  ('AL', 'Alabama'), ('AZ', 'Arizona'), ('AR', 'Arkansas'), ('CA', 'California'),
  ('CO', 'Colorado'), ('CT', 'Connecticut'), ('DE', 'Delaware'), ('FL', 'Florida'),
  ('GA', 'Georgia'), ('ID', 'Idaho'), ('IL', 'Illinois'), ('IN', 'Indiana'),
  ('IA', 'Iowa'), ('KS', 'Kansas'), ('KY', 'Kentucky'), ('LA', 'Louisiana'),
  ('ME', 'Maine'), ('MD', 'Maryland'), ('MA', 'Massachusetts'), ('MI', 'Michigan'),
  ('MN', 'Minnesota'), ('MS', 'Mississippi'), ('MO', 'Missouri'), ('MT', 'Montana'),
  ('NE', 'Nebraska'), ('NV', 'Nevada'), ('NH', 'New Hampshire'), ('NJ', 'New Jersey'),
  ('NM', 'New Mexico'), ('NY', 'New York'), ('NC', 'North Carolina'), ('ND', 'North Dakota'),
  ('OH', 'Ohio'), ('OK', 'Oklahoma'), ('OR', 'Oregon'), ('PA', 'Pennsylvania'),
  ('RI', 'Rhode Island'), ('SC', 'South Carolina'), ('SD', 'South Dakota'), ('TN', 'Tennessee'),
  ('TX', 'Texas'), ('UT', 'Utah'), ('VT', 'Vermont'), ('VA', 'Virginia'),
  ('WA', 'Washington'), ('WV', 'West Virginia'), ('WI', 'Wisconsin'), ('WY', 'Wyoming'),
];

class FuelPurchaseCaptureScreen extends StatefulWidget {
  final Vehicle vehicle;

  const FuelPurchaseCaptureScreen({super.key, required this.vehicle});

  @override
  State<FuelPurchaseCaptureScreen> createState() => _FuelPurchaseCaptureScreenState();
}

class _FuelPurchaseCaptureScreenState extends State<FuelPurchaseCaptureScreen> {
  final _picker = ImagePicker();
  final _fuelService = FuelPurchaseService();
  final _ocrService = FuelReceiptOcrService();

  final _gallonsController = TextEditingController();
  final _pricePerGallonController = TextEditingController();
  final _totalCostController = TextEditingController();
  final _vendorController = TextEditingController();

  File? _receiptFile;
  String? _stateCode;
  // Full IFTA return (2026-09-30): the return is filed per fuel type, and
  // the state is pre-filled from where the phone is -- the driver is at
  // the pump when logging, the same way Motive/Samsara fill the
  // jurisdiction from GPS. Always editable.
  String _fuelType = 'diesel';
  bool _stateFromLocation = false;
  // Fleet profile (2026-09-30): the state only matters for IFTA; fleets
  // whose profile doesn't use IFTA (e.g. a driving school) don't see it.
  bool _showState = true;
  DateTime _purchaseDate = DateTime.now();
  bool _ocrSource = false;
  double? _ocrConfidence;
  bool _isScanning = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final orgId = widget.vehicle.organizationId;
    if (orgId != null) {
      try {
        final org = await Supabase.instance.client
            .from('organizations')
            .select('industry_template, show_all_modules')
            .eq('id', orgId)
            .maybeSingle();
        final profile = org?['industry_template'] as String? ?? 'general';
        final showAll = org?['show_all_modules'] as bool? ?? false;
        final ifta = showAll || const ['general', 'trucking', 'construction'].contains(profile);
        if (mounted) setState(() => _showState = ifta);
        if (!ifta) return;
      } catch (_) {}
    }
    _prefillStateFromLocation();
  }

  /// Only when location permission is already granted -- never prompts
  /// from this screen. Any failure just leaves the picker empty.
  Future<void> _prefillStateFromLocation() async {
    try {
      final permission = await geo.Geolocator.checkPermission();
      if (permission != geo.LocationPermission.always &&
          permission != geo.LocationPermission.whileInUse) {
        return;
      }
      final pos = await geo.Geolocator.getLastKnownPosition() ??
          await geo.Geolocator.getCurrentPosition(
            locationSettings: const geo.LocationSettings(
              accuracy: geo.LocationAccuracy.medium,
              timeLimit: Duration(seconds: 8),
            ),
          );
      final code = await Supabase.instance.client.rpc(
        'ifta_state_at_point',
        params: {'p_lat': pos.latitude, 'p_lng': pos.longitude},
      );
      if (!mounted || _stateCode != null || code is! String) return;
      if (_kIftaStates.any((s) => s.$1 == code)) {
        setState(() {
          _stateCode = code;
          _stateFromLocation = true;
        });
      }
    } catch (e) {
      debugPrint('[ControlMiles] fuel state prefill skipped: $e');
    }
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _gallonsController.dispose();
    _pricePerGallonController.dispose();
    _totalCostController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _captureReceipt(AppState appState) async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    setState(() {
      _receiptFile = file;
      _isScanning = true;
      _error = null;
    });

    final result = await _ocrService.scanReceipt(file);
    if (!mounted) return;

    setState(() {
      _isScanning = false;
      if (result.gallons != null) {
        _gallonsController.text = result.gallons!.toStringAsFixed(3);
      }
      if (result.pricePerGallon != null) {
        _pricePerGallonController.text = result.pricePerGallon!.toStringAsFixed(3);
      }
      if (result.totalCost != null) {
        _totalCostController.text = result.totalCost!.toStringAsFixed(2);
      }
      if (result.purchaseDate != null) {
        _purchaseDate = result.purchaseDate!;
      }
      _ocrSource = result.fieldsFoundRatio > 0;
      _ocrConfidence = result.fieldsFoundRatio > 0 ? result.fieldsFoundRatio : null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _purchaseDate = picked);
  }

  Future<void> _submit(AppState appState) async {
    if (_isSubmitting) return;

    if (_receiptFile == null) {
      setState(() => _error = appState.tr('fuel_receipt_photo_required'));
      return;
    }
    final gallons = double.tryParse(_gallonsController.text.trim());
    if (gallons == null || gallons <= 0) {
      setState(() => _error = appState.tr('fuel_gallons_required'));
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await _fuelService.submitFuelPurchase(
        vehicleId: widget.vehicle.id,
        receiptFile: _receiptFile!,
        purchaseDate: _purchaseDate,
        gallons: gallons,
        stateCode: _stateCode,
        fuelType: _fuelType,
        vendorName: _vendorController.text.trim().isEmpty ? null : _vendorController.text.trim(),
        pricePerGallonUsd: double.tryParse(_pricePerGallonController.text.trim()),
        totalCostUsd: double.tryParse(_totalCostController.text.trim()),
        language: appState.currentLanguage,
        ocrSource: _ocrSource,
        ocrConfidence: _ocrConfidence,
      );

      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        final appError = AppError.from(e);
        setState(() {
          _isSubmitting = false;
          _error = appError.display(appState.tr(appError.messageKey));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF12100C) : const Color(0xFFFAF6EE);
    final cardColor = isDark ? const Color(0xFF1C1812) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF6B6250);
    final borderColor = isDark ? const Color(0xFF2E281F) : const Color(0xFFE3D9C4);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(appState.tr('fuel_log_purchase_title')),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.vehicle.displayName, style: TextStyle(fontSize: 13, color: subTextColor, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            InkWell(
              onTap: () => _captureReceipt(appState),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: _receiptFile != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_receiptFile!, fit: BoxFit.cover),
                          if (_isScanning)
                            Container(
                              color: Colors.black45,
                              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                            ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 32, color: primary),
                            const SizedBox(height: 8),
                            Text(appState.tr('fuel_tap_to_scan_receipt'), style: TextStyle(color: subTextColor, fontSize: 13)),
                          ],
                        ),
                      ),
              ),
            ),
            if (_receiptFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: () => _captureReceipt(appState),
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: Text(appState.tr('fuel_retake_photo')),
                ),
              ),

            const SizedBox(height: 20),

            _FieldLabel(appState.tr('fuel_gallons_label'), textColor),
            TextField(
              controller: _gallonsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration('0.000', borderColor),
            ),

            const SizedBox(height: 14),
            _FieldLabel(appState.tr('fuel_type_label'), textColor),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'diesel', label: Text(appState.tr('fuel_type_diesel'))),
                ButtonSegment(value: 'gasoline', label: Text(appState.tr('fuel_type_gasoline'))),
              ],
              selected: {_fuelType},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _fuelType = v.first),
            ),

            const SizedBox(height: 14),
            _FieldLabel(appState.tr('fuel_price_per_gallon_label'), textColor),
            TextField(
              controller: _pricePerGallonController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration('0.000', borderColor),
            ),

            const SizedBox(height: 14),
            _FieldLabel(appState.tr('fuel_total_cost_label'), textColor),
            TextField(
              controller: _totalCostController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration('0.00', borderColor),
            ),

            if (_showState) ...[
            const SizedBox(height: 14),
            _FieldLabel(appState.tr('fuel_state_label'), textColor),
            DropdownButtonFormField<String>(
              initialValue: _stateCode,
              decoration: _inputDecoration(appState.tr('fuel_state_hint'), borderColor),
              items: _kIftaStates
                  .map((s) => DropdownMenuItem(value: s.$1, child: Text('${s.$2} (${s.$1})')))
                  .toList(),
              onChanged: (v) => setState(() {
                _stateCode = v;
                _stateFromLocation = false;
              }),
            ),
            if (_stateFromLocation)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.my_location_rounded, size: 14, color: subTextColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(appState.tr('fuel_state_from_location'),
                          style: TextStyle(fontSize: 11.5, color: subTextColor)),
                    ),
                  ],
                ),
              ),

            ],
            const SizedBox(height: 14),
            _FieldLabel(appState.tr('fuel_vendor_label'), textColor),
            TextField(
              controller: _vendorController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(appState.tr('fuel_vendor_hint'), borderColor),
            ),

            const SizedBox(height: 14),
            _FieldLabel(appState.tr('fuel_date_label'), textColor),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: _inputDecoration('', borderColor),
                child: Text(
                  '${_purchaseDate.year}-${_purchaseDate.month.toString().padLeft(2, '0')}-${_purchaseDate.day.toString().padLeft(2, '0')}',
                  style: TextStyle(color: textColor),
                ),
              ),
            ),

            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : () => _submit(appState),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(appState.tr('fuel_save_purchase').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, Color borderColor) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _FieldLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
