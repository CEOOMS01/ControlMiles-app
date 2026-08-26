// Olympus Mont Systems LLC - ControlMiles
// lib/screens/inspection_detail_screen.dart
//
// Explicit user requirement: a driver should be able to see the last
// inspection recorded for their vehicle (theirs or a previous driver's,
// per vehicle_inspections_select_assigned_vehicle_latest), but never
// edit it -- "modo lectura del lado del conductor" (read-only on the
// driver's side). This screen is deliberately built with zero editable
// widgets: no TextField, no status toggle, no submit button. It only
// ever displays a VehicleInspection that already exists; there is no
// code path here that writes anything back.
//
// The submitter's name is deliberately not shown -- profiles RLS only
// lets a driver read their OWN profile or (if admin) an org member's,
// not an arbitrary other driver's, so a name would be blank/wrong when
// this is someone else's submission. Date + type + result + items is
// enough context without reaching for data this account can't see.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../models/vehicle_inspection.dart';

class InspectionDetailScreen extends StatelessWidget {
  final VehicleInspection inspection;
  final String vehicleName;

  const InspectionDetailScreen({
    super.key,
    required this.inspection,
    required this.vehicleName,
  });

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
        title: Text(vehicleName),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (inspection.isPass ? Colors.green : Colors.red).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      inspection.isPass ? Icons.check_circle_rounded : Icons.error_rounded,
                      color: inspection.isPass ? Colors.green.shade600 : Colors.red.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appState.tr(inspection.isPass ? 'inspection_result_pass' : 'inspection_result_fail'),
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: textColor),
                        ),
                        Text(
                          '${appState.tr(inspection.inspectionType == 'pre_trip' ? 'inspection_pre_trip' : 'inspection_post_trip')} · ${_formatDate(inspection.createdAt)}',
                          style: TextStyle(fontSize: 12.5, color: subTextColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (inspection.odometer != null) ...[
              const SizedBox(height: 10),
              Text(
                '${appState.tr('inspection_odometer_optional')}: ${inspection.odometer!.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 12.5, color: subTextColor),
              ),
            ],
            const SizedBox(height: 20),
            for (final item in inspection.items)
              _ReadOnlyItemTile(
                item: item,
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                subTextColor: subTextColor,
                appState: appState,
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.month}/${local.day}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _ReadOnlyItemTile extends StatelessWidget {
  final InspectionItem item;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color subTextColor;
  final AppState appState;

  const _ReadOnlyItemTile({
    required this.item,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.subTextColor,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final isDefect = item.status == InspectionItemStatus.defect;
    final category = InspectionCategory.all.firstWhere(
      (c) => c.id == item.category,
      orElse: () => InspectionCategory.all.last,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDefect ? Colors.red.shade200 : borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(category.icon, size: 18, color: isDefect ? Colors.red.shade700 : subTextColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appState.tr(category.labelKey),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textColor),
                ),
                if (isDefect && item.note != null && item.note!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.note!,
                      style: TextStyle(fontSize: 12.5, color: Colors.red.shade700),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            appState.tr(isDefect ? 'inspection_status_defect' : 'inspection_status_ok'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDefect ? Colors.red.shade600 : Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
