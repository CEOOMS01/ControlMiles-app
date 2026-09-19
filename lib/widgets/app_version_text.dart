// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/app_version_text.dart
//
// BUG FIX (real bug found live, 2026-09-19): both places that show the app
// version to the user (this drawer's footer and Settings > About) had it
// literally hardcoded as the string "v2.0.1" -- not read from pubspec.yaml
// in any way. Every version bump since (pubspec.yaml is now well past that)
// left the on-screen label silently wrong. package_info_plus is already a
// dependency (used elsewhere in the app); this reads pubspec.yaml's real
// version at runtime instead of a string that has to be remembered and
// hand-edited on every bump.

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionText extends StatelessWidget {
  const AppVersionText({super.key, required this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version;
        return Text(version != null ? 'v$version' : '', style: style);
      },
    );
  }
}
