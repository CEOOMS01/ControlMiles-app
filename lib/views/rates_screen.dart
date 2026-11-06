// Olympus Mont Systems LLC - ControlMiles
// lib/views/rates_screen.dart
//
// "Rates" (2026-11-05): what the IRS pays per mile for each trip purpose, as of
// today. Same figures the estimates use (lib/data/irs_rates.dart); the rate that
// applies to a trip is the one in effect on the day it was driven.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/irs_rates.dart';
import '../logic/app_state.dart';
import '../theme/cm_colors.dart';

class RatesScreen extends StatelessWidget {
  const RatesScreen({super.key});

  static const _rows = [
    ('business', 'business_purpose'),
    ('medical', 'medical'),
    ('charitable', 'charitable'),
    ('moving', 'moving'),
    ('personal', 'personal_other'),
  ];

  static String _money(double cents) {
    final dollars = cents / 100;
    // $0.76, $0.235, $0.00 -- as many decimals as the rate really has.
    final text = dollars.toStringAsFixed(3);
    return '\$${text.endsWith('0') ? text.substring(0, text.length - 1) : text}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : CmColors.ink;
    final subColor = isDark ? Colors.white70 : CmColors.inkDim;
    final border = isDark ? CmColors.ink : CmColors.sand;
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text(appState.tr('rates_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(appState.tr('rates_intro'), style: TextStyle(fontSize: 14, height: 1.4, color: subColor)),
          TextButton(
            style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: EdgeInsets.zero),
            onPressed: () => launchUrl(
              Uri.parse('https://www.irs.gov/tax-professionals/standard-mileage-rates'),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(appState.tr('rates_learn_more')),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(appState.tr('rates_by_purpose'), style: TextStyle(fontSize: 12, color: subColor))),
              Text(appState.tr('rates_per_mile'), style: TextStyle(fontSize: 12, color: subColor)),
            ],
          ),
          const SizedBox(height: 6),
          for (final (id, labelKey) in _rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border))),
              child: Row(
                children: [
                  Expanded(
                    child: Text(appState.tr(labelKey), style: TextStyle(fontSize: 17, color: textColor)),
                  ),
                  Text(
                    _money(ratePerMileCentsForPurpose(id, today)),
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: subColor),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(appState.tr('rates_note'), style: TextStyle(fontSize: 12, height: 1.4, color: subColor)),
        ],
      ),
    );
  }
}
