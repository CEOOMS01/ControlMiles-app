// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/pinned_bar.dart
//
// A bar of fixed height that stays at the top of a CustomScrollView while the
// rest scrolls under it (the buttons of Reports and My Trips).

import 'package:flutter/material.dart';

class PinnedBar extends SliverPersistentHeaderDelegate {
  PinnedBar({required this.extent, required this.color, required this.child});

  final double extent;
  final Color color;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: color, alignment: Alignment.center, child: child);

  @override
  bool shouldRebuild(covariant PinnedBar old) => old.extent != extent || old.color != color || old.child != child;
}
