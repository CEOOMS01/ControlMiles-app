// Olympus Mont Systems LLC - ControlMiles
// lib/screens/driver_settings_sheet.dart
//
// Deliberately NOT the full SettingsScreen (notifications, metric
// system, about, delete-account) -- explicit user requirement: a
// fleet_driver on DriverOperationsScreen sees language + dark mode and
// nothing else, plus sign out as the one unavoidable escape hatch every
// screen needs.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../i18n/app_texts.dart';
import '../routes/app_routes.dart';

Future<void> showDriverSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _DriverSettingsSheet(),
  );
}

class _DriverSettingsSheet extends StatelessWidget {
  const _DriverSettingsSheet();

  Future<void> _signOut(BuildContext context, AppState appState) async {
    await appState.signOutAndClear();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Container(
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
              decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(
            appState.tr('settings'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.dark_mode_rounded, color: Theme.of(context).colorScheme.primary),
            title: Text(appState.tr('dark_mode'), style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            trailing: Switch.adaptive(
              value: appState.isDarkMode,
              onChanged: (v) => appState.setDarkMode(v),
              activeThumbColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Divider(),
          Text(
            appState.tr('language'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppLanguage.values.map((lang) {
              final selected = appState.currentLanguage == lang;
              return ChoiceChip(
                label: Text('${lang.flag} ${lang.label}'),
                selected: selected,
                onSelected: (_) => appState.setLanguage(lang),
                selectedColor: Theme.of(context).colorScheme.primary,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : textColor,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _signOut(context, appState),
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              label: Text(appState.tr('sign_out'), style: const TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }
}
