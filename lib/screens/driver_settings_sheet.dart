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
import '../routes/app_routes.dart';
import 'driver_safety_score_screen.dart';
import '../widgets/language_selector_tile.dart';
import '../onboarding/app_tour.dart';

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
    // BUG FIX (pedido explícito, logout que no navega): capturar el
    // Navigator raíz ANTES del await -- este context vive dentro de un
    // bottom sheet, que el usuario puede cerrar (swipe/tap fuera) mientras
    // signOutAndClear() todavía está en curso; si eso pasa, el context
    // puntual del sheet se desmonta y `context.mounted` da false, saltando
    // la navegación en silencio aunque la sesión ya se haya cerrado. Ver
    // el mismo fix en main_drawer.dart para el detalle completo.
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    await appState.signOutAndClear();
    rootNavigator.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1812) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2E281F);
    final borderColor = isDark
        ? const Color(0xFF2E281F)
        : const Color(0xFFE3D9C4);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // BUG FIX (real, found via CGC Core monitoring -- "ListTile
      // background color or ink splashes may be invisible"): this
      // Container's own BoxDecoration.color sat between the ListTile below
      // and the nearest Material ancestor, hiding its tap ripple. Wrapping
      // the content in a transparent Material gives it a nearer surface
      // to paint on -- no visual change, the Container's color still
      // shows through.
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              appState.tr('settings'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.dark_mode_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                appState.tr('dark_mode'),
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
              trailing: Switch.adaptive(
                value: appState.isDarkMode,
                onChanged: (v) => appState.setDarkMode(v),
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            // The driver's own safety score lives here (2026-09-30), not
            // on the main screen. Bus monitors don't drive: no score.
            if (!appState.isMonitor) ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.speed_rounded, color: Theme.of(context).colorScheme.primary),
              title: Text(
                appState.tr('safety_score_title'),
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                // Capture the navigator before the sheet (and this
                // context) closes.
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(MaterialPageRoute(builder: (_) => const DriverSafetyScoreScreen()));
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.school_rounded, color: Theme.of(context).colorScheme.primary),
              title: Text(
                appState.tr('tutorial_whats_new'),
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                final nav = Navigator.of(context);
                final rootContext = nav.context;
                nav.pop();
                AppTourService.replay(rootContext);
              },
            ),
            const Divider(),
            // One button that opens the languages (2026-09-30).
            const LanguageSelectorTile(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _signOut(context, appState),
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: Text(
                  appState.tr('sign_out'),
                  style: const TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
