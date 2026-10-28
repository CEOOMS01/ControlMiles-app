// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/gps_issue_banner.dart
//
// Dashboard banner for GpsWatchdog: GPS off / permission off (trip paused), GPS back on
// (tap Resume), or no signal (trip running, miles not counted).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../tracking/gps_watchdog.dart';

class GpsIssueBanner extends StatelessWidget {
  const GpsIssueBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return ValueListenableBuilder<GpsIssue>(
      valueListenable: GpsWatchdog.issue,
      builder: (context, issue, _) {
        if (issue == GpsIssue.none) return const SizedBox.shrink();
        final (titleKey, bodyKey, icon, color) = switch (issue) {
          GpsIssue.gpsOff => ('gps_off_title', 'gps_off_body', Icons.location_disabled_rounded, Colors.orange.shade800),
          GpsIssue.permissionOff =>
            ('gps_perm_title', 'gps_perm_body', Icons.location_disabled_rounded, Colors.orange.shade800),
          GpsIssue.gpsBackOn => ('gps_back_title', 'gps_back_body', Icons.location_on_rounded, Colors.green.shade700),
          GpsIssue.noSignal => ('gps_nosig_title', 'gps_nosig_body', Icons.gps_not_fixed_rounded, Colors.orange.shade800),
          GpsIssue.none => ('', '', Icons.info, Colors.grey),
        };
        final needsSettings = issue == GpsIssue.gpsOff || issue == GpsIssue.permissionOff;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      appState.tr(titleKey),
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(appState.tr(bodyKey), style: const TextStyle(fontSize: 13.5, height: 1.35)),
              if (needsSettings) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: GpsWatchdog.openSettings,
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: Text(appState.tr('gps_open_settings')),
                    style: FilledButton.styleFrom(backgroundColor: color),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
