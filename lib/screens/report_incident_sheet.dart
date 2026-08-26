// Olympus Mont Systems LLC - ControlMiles
// lib/screens/report_incident_sheet.dart
//
// Mid-trip incident report, reached from DriverOperationsScreen while a
// trip is active. Deliberately a modal bottom sheet, not a full-page
// navigation push -- "something went wrong, tell your admin quickly"
// should be a fast, low-friction action, not a multi-step flow like the
// pre-trip DVIR checklist.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../services/incident_service.dart';

Future<void> showReportIncidentSheet(
  BuildContext context, {
  required String organizationId,
  String? sessionId,
  String? vehicleId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportIncidentSheet(
      organizationId: organizationId,
      sessionId: sessionId,
      vehicleId: vehicleId,
    ),
  );
}

const _kCategories = ['breakdown', 'accident', 'delay', 'other'];

class _ReportIncidentSheet extends StatefulWidget {
  final String organizationId;
  final String? sessionId;
  final String? vehicleId;

  const _ReportIncidentSheet({
    required this.organizationId,
    this.sessionId,
    this.vehicleId,
  });

  @override
  State<_ReportIncidentSheet> createState() => _ReportIncidentSheetState();
}

class _ReportIncidentSheetState extends State<_ReportIncidentSheet> {
  final _descriptionController = TextEditingController();
  final _incidentService = IncidentService();
  String _category = 'breakdown';
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState appState) async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      setState(() => _error = appState.tr('field_required'));
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _incidentService.reportIncident(
        organizationId: widget.organizationId,
        category: _category,
        description: description,
        sessionId: widget.sessionId,
        vehicleId: widget.vehicleId,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.tr('report_incident_success'))),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = '${appState.tr('error')}: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              appState.tr('report_incident_title'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
            ),
            const SizedBox(height: 16),
            Text(
              appState.tr('report_incident_category_label'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kCategories.map((c) {
                final selected = c == _category;
                return ChoiceChip(
                  label: Text(appState.tr('incident_category_$c')),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : textColor,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                labelText: appState.tr('report_incident_description_label'),
                hintText: appState.tr('report_incident_description_hint'),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: borderColor),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : () => _submit(appState),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        appState.tr('report_incident_submit').toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
