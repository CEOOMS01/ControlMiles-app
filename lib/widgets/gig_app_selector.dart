// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/gig_app_selector.dart - VERSIÓN MEJORADA CON IRS PURPOSE

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'full_bleed.dart';

import '../logic/app_state.dart';
import '../models/gig_app.dart';
import '../routes/app_routes.dart';
import 'cm_card_header.dart';
import 'gig_app_shift_selector_sheet.dart';

class GigAppSelector extends StatelessWidget {
  final String? selectedGigApp;
  final String? activeGigApp;
  final Function(String) onAppSelected; // Para apps normales
  final Function(String, String?)?
  onCustomSelected; // Para Custom + IRS Purpose
  // BUG FIX (pedido explícito, bug silencioso): dashboard_screen.dart solo
  // invoca TrackingController.switchSection() cuando el tracking está
  // corriendo (running) -- en pausa, el RPC nunca se llama. Sin este flag,
  // el carrusel no tenía forma de saberlo y dejaba tocar otra tarjeta en
  // pausa igual, mostrando un "SWITCHED" falso. Ver guard en onTap abajo.
  final bool isPaused;

  const GigAppSelector({
    super.key,
    this.selectedGigApp,
    this.activeGigApp,
    required this.onAppSelected,
    this.onCustomSelected,
    this.isPaused = false,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // BUG FIX (consolidación pedida explícitamente): este catálogo vivía
    // duplicado a mano en 4 archivos (acá, dashboard_screen.dart,
    // reports_screen.dart, history_screen.dart) — ya se había desincronizado
    // una vez (Custom/Truck tenía dos colores distintos según la pantalla).
    // Ahora todos leen de GigAppCatalog (lib/models/gig_app.dart), fuente
    // única de verdad. De paso se unifican dos discrepancias menores que
    // solo existían acá: Uber pasa de Colors.black puro a 0xFF1E1E1E (el
    // "casi negro" que ya usaban las otras 3 pantallas) y Custom/Truck pasa
    // de azul 0xFF2563EB a gris pizarra 0xFF475569 (decisión explícita del
    // usuario al consolidar).
    final List<GigApp> apps = appState.carouselGigApps(
      alwaysShow: (activeGigApp != null && activeGigApp!.isNotEmpty)
          ? activeGigApp
          : selectedGigApp,
    );

    final isTracking = activeGigApp != null && activeGigApp!.isNotEmpty;

    // BUG FIX (pedido explícito): el carrusel era un ListView.builder
    // horizontal "suelto" sin marco -- las tarjetas se cortaban en
    // seco contra ambos bordes de la pantalla, dando la impresión de
    // que "desaparecían" en vez de indicar que hay más contenido para
    // deslizar. Ahora vive dentro de una caja con borde (mismo
    // lenguaje visual que el resto del Dashboard) y un ShaderMask con
    // gradiente en ambos extremos que atenúa gradualmente la primera/
    // última tarjeta en vez de cortarlas de golpe.
    //
    // BUG FIX (pedido explícito, "Full-width Divider"): el header ("ACTIVE
    // ACTIVITY" + badge) vivía FUERA de esta caja, en un Padding aparte --
    // no se veía como una sola card, sino como un título suelto flotando
    // encima de una caja distinta. Ahora ambos viven dentro del mismo
    // Container con borde, separados por un Divider de borde a borde,
    // mismo patrón que Vehicle/Stats/Summary.
    final borderColor = isDark
        ? const Color(0xFF2E281F)
        : const Color(0xFFE3D9C4);

    // Full-width row (2026-10-01), like the other dashboard cards.
    return Container(
      decoration: fullBleedCard(
        color: isDark ? const Color(0xFF1C1812) : Colors.white,
        border: borderColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brown header strip (2026-10-09). "ON LIVE" badge in the brand
          // blue (explicit user request, 2026-10-01), solid so it reads on brown.
          CmCardHeader(
            title: appState.tr('active_activity'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isTracking)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E93CA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ON LIVE',
                      style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                IconButton(
                  tooltip: appState.tr('shift_apps_picker_title'),
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  color: Colors.white,
                  icon: Icon(
                    appState.premiumEntitled
                        ? Icons.tune_rounded
                        : Icons.lock_outline_rounded,
                  ),
                  onPressed: () => _openAppPicker(context, appState),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ShaderMask(
              shaderCallback: (bounds) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.06, 0.94, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: SizedBox(
                height: 108,
                // Drag & drop (2026-10-29): long-press a card, then drag to
                // reorder. A plain tap still selects it.
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: kPageGutter),
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  itemCount: apps.length,
                  proxyDecorator: (child, index, animation) =>
                      Material(color: Colors.transparent, child: child),
                  onReorderItem: (oldIndex, newIndex) {
                    HapticFeedback.selectionClick();
                    final visible = apps.map((a) => a.id).toList();
                    visible.insert(newIndex, visible.removeAt(oldIndex));
                    // Apps hidden by the Premium picker keep their place
                    // after the visible ones.
                    final hidden = appState
                        .carouselGigApps()
                        .map((a) => a.id)
                        .where((id) => !visible.contains(id));
                    appState.setGigAppOrder([...visible, ...hidden]);
                  },
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    final isSelected = selectedGigApp == app.id;
                    final isActive = activeGigApp == app.id;
                    final isCustom = app.id == 'custom';

                    final baseColor = app.color;

                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(app.id),
                      index: index,
                      child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();

                        // Si ya está activo, no hacer nada
                        if (isTracking && isActive) return;

                        // BUG FIX (pedido explícito, bug silencioso
                        // carrusel+pausa): en pausa no existe un flujo real de
                        // "cambiar de gig app" todavía -- bloqueamos el tap acá
                        // mismo (antes de isCustom, para cubrir también el menú
                        // IRS de Custom/Truck) en vez de dejar que la UI se
                        // actualice sola y mienta con el banner "SWITCHED".
                        if (isTracking && isPaused) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                appState.tr('resume_to_switch_app'),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          return;
                        }

                        if (isCustom) {
                          _showIrsCategoryMenu(context, appState);
                        } else {
                          onAppSelected(app.id);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 95,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: isActive
                              ? baseColor
                              : isSelected
                              ? baseColor.withValues(alpha: 0.85)
                              : (isDark
                                    ? const Color(0xFF2E281F)
                                    : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isActive
                                ? baseColor
                                : isSelected
                                ? baseColor
                                : (isDark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300),
                            width: isActive ? 3 : 2,
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: baseColor.withValues(alpha: 0.5),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : [],
                        ),
                        child: Opacity(
                          opacity: isActive ? 1.0 : (isSelected ? 0.9 : 0.65),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                app.icon,
                                size: 32,
                                color: (isActive || isSelected)
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white70
                                          : baseColor.withValues(alpha: 0.6)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                app.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: (isActive || isSelected)
                                      ? Colors.white
                                      : (isDark
                                            ? Colors.white70
                                            : Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 10),
            child: Text(
              appState.tr('gig_reorder_hint'),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : const Color(0xFFA39A86),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Premium: choose which apps the carousel (and auto-detect) shows.
  void _openAppPicker(BuildContext context, AppState appState) {
    if (appState.premiumEntitled) {
      showGigAppShiftSelectorSheet(context);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appState.tr('premium_feature_locked_title')),
        content: Text(appState.tr('premium_feature_locked_body_apps')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(appState.tr('cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, AppRoutes.subscription);
            },
            child: Text(appState.tr('upgrade_plan')),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // MENÚ IRS PARA CUSTOM/TRUCK
  // ==============================================================
  void _showIrsCategoryMenu(BuildContext context, AppState appState) async {
    final selectedCategory = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => _buildIrsCategorySheet(modalContext, appState),
    );

    if (selectedCategory != null) {
      // Opción 1: Usar callback dedicado (recomendado)
      if (onCustomSelected != null) {
        onCustomSelected!('custom', selectedCategory);
      }
      // Opción 2: Fallback usando onAppSelected (mantener compatibilidad)
      else {
        onAppSelected('custom');
        // Nota: En este caso irsPurpose no se pasará automáticamente
      }
    }
  }

  Widget _buildIrsCategorySheet(BuildContext context, AppState appState) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final categories = [
      {
        'id': 'business',
        'labelKey': 'business_purpose',
        'icon': Icons.business_center,
      },
      {'id': 'work', 'labelKey': 'work_commute', 'icon': Icons.work},
      {'id': 'medical', 'labelKey': 'medical', 'icon': Icons.local_hospital},
      {'id': 'moving', 'labelKey': 'moving', 'icon': Icons.home_work},
      {
        'id': 'charitable',
        'labelKey': 'charitable',
        'icon': Icons.volunteer_activism,
      },
      {'id': 'education', 'labelKey': 'education_study', 'icon': Icons.school},
      {'id': 'personal', 'labelKey': 'personal_other', 'icon': Icons.person},
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      // BUG FIX (real, found via CGC Core monitoring -- "ListTile
      // background color or ink splashes may be invisible"): this
      // Container's own BoxDecoration.color sat between the category
      // ListTiles below and the nearest Material ancestor, hiding their
      // tap ripple. Wrapping the content in a transparent Material gives
      // them a nearer surface to paint on -- no visual change.
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              appState.tr('select_trip_purpose'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              appState.tr('irs_deduction_note'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: categories
                    .map(
                      (cat) => ListTile(
                        leading: Icon(
                          cat['icon'] as IconData,
                          color: theme.iconTheme.color,
                          size: 24,
                        ),
                        title: Text(
                          appState.tr(cat['labelKey'] as String),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () =>
                            Navigator.pop(context, cat['id'] as String),
                      ),
                    )
                    .toList(),
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  appState.tr('cancel'),
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
