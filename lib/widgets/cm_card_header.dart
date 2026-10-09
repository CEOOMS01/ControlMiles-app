// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/cm_card_header.dart
//
// Card header strip (2026-10-09, owner's request): card titles ("ACTIVE
// ACTIVITY", "VEHICLE", "SUMMARY"...) were small gray labels that were barely
// visible. Every card now opens with a solid brown strip (the app's warm ink)
// and cream text, so each card reads as a block. Optional [trailing] (a badge
// or a "See all" link) sits on the right.

import 'package:flutter/material.dart';

import 'full_bleed.dart';

class CmCardHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  // Inside a card that already has padding: a rounded bar instead of an
  // edge-to-edge strip.
  final bool inset;

  const CmCardHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(kPageGutter, 10, kPageGutter, 10),
    this.inset = false,
  });

  static const brown = Color(0xFF2E281F);
  static const brownDark = Color(0xFF3D352A); // a step lighter on dark cards
  static const text = Color(0xFFF0E6D2);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? brownDark : brown,
        borderRadius: inset ? BorderRadius.circular(10) : null,
      ),
      padding: inset ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8) : padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: text),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Text style for a link or badge placed in a [CmCardHeader] (on brown).
const cmHeaderLinkStyle = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w900,
  letterSpacing: 0.8,
  color: Color(0xFFF2B48C), // light amber, readable on brown
);
