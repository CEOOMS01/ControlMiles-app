// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/full_bleed.dart
//
// Full-width rows for the dashboard (explicit user request, 2026-10-01:
// "cada card de borde a borde horizontalmente"). The standard grouped-list
// pattern (iOS grouped tables, Material full-width lists): the page has no
// side margin for cards, each card is a full-width band with a hairline
// top and bottom border and no rounded corners, and its CONTENT keeps the
// page gutter so text lines up with the non-card elements (buttons,
// section titles), which keep their own horizontal padding.

import 'package:flutter/material.dart';

/// Horizontal gutter for content inside full-width rows and for the
/// elements that are not rows (buttons, section titles).
const double kPageGutter = 20;

/// Full-width row: background + hairline top/bottom borders, no radius.
BoxDecoration fullBleedCard({required Color color, required Color border, Color? accentBorder, double accentWidth = 1}) {
  final side = BorderSide(color: accentBorder ?? border, width: accentBorder != null ? accentWidth : 1);
  return BoxDecoration(
    color: color,
    border: Border(top: side, bottom: side),
  );
}

/// Pads a non-row element (button, title, chip) with the page gutter.
class Gutter extends StatelessWidget {
  final Widget child;
  const Gutter({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: kPageGutter), child: child);
}
