// Olympus Mont Systems LLC - ControlMiles
// lib/screens/vehicle_inspection_screen.dart
//
// Fleet Phase 4: DVIR-style pre/post-trip checklist. Driver marks each
// category OK or Defect; a defect requires a note and may attach a photo
// (image_picker -- simpler than odometer_capture_screen.dart's raw
// CameraController+OCR pipeline, which doesn't apply here since there's no
// number to read off a photo). Submission is atomic server-side
// (submit_vehicle_inspection) -- the client never decides pass/fail itself.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../models/vehicle.dart';
import '../models/vehicle_inspection.dart';
import '../services/inspection_service.dart';

class VehicleInspectionScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleInspectionScreen({super.key, required this.vehicle});

  @override
  State<VehicleInspectionScreen> createState() => _VehicleInspectionScreenState();
}

class _VehicleInspectionScreenState extends State<VehicleInspectionScreen> {
  final _inspectionService = InspectionService();
  final _picker = ImagePicker();
  final _odometerController = TextEditingController();

  String _inspectionType = 'pre_trip';
  final Map<String, InspectionItemStatus> _statuses = {
    for (final c in InspectionCategory.all) c.id: InspectionItemStatus.ok,
  };
  final Map<String, TextEditingController> _notes = {
    for (final c in InspectionCategory.all) c.id: TextEditingController(),
  };
  final Map<String, File> _photos = {};

  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _odometerController.dispose();
    for (final c in _notes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto(String categoryId) async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _photos[categoryId] = File(picked.path));
  }

  Future<void> _submit(AppState appState) async {
    if (_isSubmitting) return;

    final defectCategories = _statuses.entries.where((e) => e.value == InspectionItemStatus.defect);
    for (final entry in defectCategories) {
      if (_notes[entry.key]!.text.trim().isEmpty) {
        setState(() => _error = appState.tr('inspection_defect_note_required'));
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final items = <InspectionItem>[];
      for (final category in InspectionCategory.all) {
        final status = _statuses[category.id]!;
        String? photoUrl;
        final file = _photos[category.id];
        if (file != null) {
          photoUrl = await _inspectionService.uploadDefectPhoto(file: file, category: category.id);
        }
        items.add(InspectionItem(
          category: category.id,
          status: status,
          note: _notes[category.id]!.text,
          photoUrl: photoUrl,
        ));
      }

      final odometer = double.tryParse(_odometerController.text.trim());

      final result = await _inspectionService.submitInspection(
        vehicleId: widget.vehicle.id,
        inspectionType: _inspectionType,
        items: items,
        odometer: odometer,
      );

      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = '${appState.tr('error')}: $e';
        });
      }
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
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(widget.vehicle.displayName),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _TypeChip(
                      label: appState.tr('inspection_pre_trip'),
                      selected: _inspectionType == 'pre_trip',
                      onTap: () => setState(() => _inspectionType = 'pre_trip'),
                      primary: primary,
                      borderColor: borderColor,
                      textColor: textColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TypeChip(
                      label: appState.tr('inspection_post_trip'),
                      selected: _inspectionType == 'post_trip',
                      onTap: () => setState(() => _inspectionType = 'post_trip'),
                      primary: primary,
                      borderColor: borderColor,
                      textColor: textColor,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                children: [
                  for (final category in InspectionCategory.all)
                    _CategoryTile(
                      category: category,
                      status: _statuses[category.id]!,
                      noteController: _notes[category.id]!,
                      photo: _photos[category.id],
                      onStatusChanged: (s) => setState(() => _statuses[category.id] = s),
                      onPickPhoto: () => _pickPhoto(category.id),
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      primary: primary,
                      appState: appState,
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _odometerController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: appState.tr('inspection_odometer_optional'),
                      labelStyle: TextStyle(color: subTextColor),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
                  ],
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : () => _submit(appState),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      appState.tr('inspection_submit').toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color primary;
  final Color borderColor;
  final Color textColor;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.primary,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? primary : borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: selected ? Colors.white : textColor,
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final InspectionCategory category;
  final InspectionItemStatus status;
  final TextEditingController noteController;
  final File? photo;
  final ValueChanged<InspectionItemStatus> onStatusChanged;
  final VoidCallback onPickPhoto;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color subTextColor;
  final Color primary;
  final AppState appState;

  const _CategoryTile({
    required this.category,
    required this.status,
    required this.noteController,
    required this.photo,
    required this.onStatusChanged,
    required this.onPickPhoto,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.subTextColor,
    required this.primary,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final isDefect = status == InspectionItemStatus.defect;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDefect ? Colors.red.shade200 : borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(category.icon, size: 20, color: isDefect ? Colors.red.shade700 : primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  appState.tr(category.labelKey),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textColor),
                ),
              ),
              _StatusToggle(
                status: status,
                onChanged: onStatusChanged,
                primary: primary,
                borderColor: borderColor,
                textColor: textColor,
                appState: appState,
              ),
            ],
          ),
          if (isDefect) ...[
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              maxLines: 2,
              style: TextStyle(color: textColor, fontSize: 13),
              decoration: InputDecoration(
                hintText: appState.tr('inspection_defect_note_hint'),
                hintStyle: TextStyle(color: subTextColor, fontSize: 12.5),
                isDense: true,
                filled: true,
                fillColor: Colors.red.shade50.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.red.shade100),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onPickPhoto,
                  icon: Icon(Icons.camera_alt_rounded, size: 16, color: Colors.red.shade700),
                  label: Text(
                    photo == null
                        ? appState.tr('inspection_photo_optional')
                        : appState.tr('inspection_photo_added'),
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12.5),
                  ),
                ),
                if (photo != null) ...[
                  const SizedBox(width: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(photo!, width: 32, height: 32, fit: BoxFit.cover),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusToggle extends StatelessWidget {
  final InspectionItemStatus status;
  final ValueChanged<InspectionItemStatus> onChanged;
  final Color primary;
  final Color borderColor;
  final Color textColor;
  final AppState appState;

  const _StatusToggle({
    required this.status,
    required this.onChanged,
    required this.primary,
    required this.borderColor,
    required this.textColor,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final isOk = status == InspectionItemStatus.ok;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton(
            label: appState.tr('inspection_status_ok'),
            selected: isOk,
            selectedColor: Colors.green.shade600,
            onTap: () => onChanged(InspectionItemStatus.ok),
            leftRadius: true,
          ),
          _toggleButton(
            label: appState.tr('inspection_status_defect'),
            selected: !isOk,
            selectedColor: Colors.red.shade600,
            onTap: () => onChanged(InspectionItemStatus.defect),
            leftRadius: false,
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required String label,
    required bool selected,
    required Color selectedColor,
    required VoidCallback onTap,
    required bool leftRadius,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.horizontal(
        left: leftRadius ? const Radius.circular(9) : Radius.zero,
        right: !leftRadius ? const Radius.circular(9) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: leftRadius ? const Radius.circular(9) : Radius.zero,
            right: !leftRadius ? const Radius.circular(9) : Radius.zero,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : textColor,
          ),
        ),
      ),
    );
  }
}
