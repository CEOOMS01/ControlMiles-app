// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/gig_app_selector.dart - VERSIÓN MEJORADA CON IRS PURPOSE

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../logic/app_state.dart';
import '../models/gig_app.dart';
import '../tracking/tracking_controller.dart';

class GigAppSelector extends StatelessWidget {
  final String? selectedGigApp;
  final String? activeGigApp;
  final Function(String) onAppSelected;           // Para apps normales
  final Function(String, String?)? onCustomSelected; // Para Custom + IRS Purpose
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
    final List<GigApp> apps = GigAppCatalog.all;

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
    final borderColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  appState.tr('active_activity')?.toUpperCase() ?? 'ACTIVE ACTIVITY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    letterSpacing: 1.2,
                  ),
                ),
                if (isTracking)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      appState.tr('tracking_active')?.toUpperCase() ?? 'TRACKING ACTIVE',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),
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
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: apps.length,
                itemBuilder: (context, index) {
              final app = apps[index];
              final isSelected = selectedGigApp == app.id;
              final isActive = activeGigApp == app.id;
              final isCustom = app.id == 'custom';

              final baseColor = app.color;

              return GestureDetector(
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
                          appState.tr('resume_to_switch_app') ??
                              'Resume tracking to switch activity',
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
                            ? baseColor.withOpacity(0.85)
                            : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive
                          ? baseColor
                          : isSelected
                              ? baseColor
                              : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                      width: isActive ? 3 : 2,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: baseColor.withOpacity(0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            )
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
                              : (isDark ? Colors.white70 : baseColor.withOpacity(0.6)),
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
                                : (isDark ? Colors.white70 : Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
                },
              ),
            ),
          ),
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
      {'id': 'business',   'labelKey': 'business_purpose',   'icon': Icons.business_center},
      {'id': 'work',       'labelKey': 'work_commute',       'icon': Icons.work},
      {'id': 'medical',    'labelKey': 'medical',            'icon': Icons.local_hospital},
      {'id': 'moving',     'labelKey': 'moving',             'icon': Icons.home_work},
      {'id': 'charitable', 'labelKey': 'charitable',         'icon': Icons.volunteer_activism},
      {'id': 'education',  'labelKey': 'education_study',    'icon': Icons.school},
      {'id': 'personal',   'labelKey': 'personal_other',     'icon': Icons.person},
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
            appState.tr('select_trip_purpose') ?? 'Select Trip Purpose',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            appState.tr('irs_deduction_note') ?? 'For IRS tax deduction purposes',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),

          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: categories.map((cat) => ListTile(
                leading: Icon(
                  cat['icon'] as IconData,
                  color: theme.iconTheme.color,
                  size: 24,
                ),
                title: Text(
                  appState.tr(cat['labelKey'] as String) ?? cat['labelKey'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => Navigator.pop(context, cat['id'] as String),
              )).toList(),
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                appState.tr('cancel') ?? 'Cancel',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}