// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/cm_dark_app_bar.dart
//
// The dark top bar shared by the screens opened from the menu (2026-11-09), so they
// all look the same.

import 'package:flutter/material.dart';

PreferredSizeWidget cmDarkAppBar(BuildContext context, String title, {List<Widget>? actions}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return AppBar(
    title: Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
    actions: actions,
    backgroundColor: isDark ? const Color(0xFF1C1812) : const Color(0xFF2E281F),
    foregroundColor: Colors.white,
    elevation: 0,
  );
}
