// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/language_selector_tile.dart
//
// One "Language" row that opens a dropdown with the 11 languages
// (2026-09-30, explicit user request: the language options must live in
// one button that opens them, never laid out loose on a settings screen).
// Same menu style as the login screen's flag picker.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_texts.dart';
import '../logic/app_state.dart';

class LanguageSelectorTile extends StatelessWidget {
  /// Called after the language changes (e.g. to show a confirmation).
  final void Function(AppLanguage lang)? onChanged;

  const LanguageSelectorTile({super.key, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF6B6250);
    final primary = Theme.of(context).colorScheme.primary;
    final current = appState.currentLanguage;

    return PopupMenuButton<AppLanguage>(
      tooltip: appState.tr('language'),
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      constraints: const BoxConstraints(minWidth: 220, maxHeight: 420),
      onSelected: (lang) {
        if (lang == current) return;
        appState.setLanguage(lang);
        onChanged?.call(lang);
      },
      itemBuilder: (context) => AppLanguage.values
          .map(
            (lang) => PopupMenuItem<AppLanguage>(
              value: lang,
              child: Row(
                children: [
                  Text(lang.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lang.label,
                      style: TextStyle(fontWeight: lang == current ? FontWeight.w800 : FontWeight.w500),
                    ),
                  ),
                  if (lang == current) Icon(Icons.check_rounded, size: 18, color: primary),
                ],
              ),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(Icons.language_rounded, color: primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                appState.tr('language'),
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
            ),
            Text('${current.flag} ${current.label}', style: TextStyle(color: subTextColor, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, color: subTextColor),
          ],
        ),
      ),
    );
  }
}
