// Olympus Mont Systems LLC - ControlMiles
// lib/models/gig_app.dart
//
// FUENTE ÚNICA DE VERDAD para el catálogo de gig apps (id, nombre, ícono,
// color). Antes este catálogo estaba duplicado a mano en 4 archivos
// (gig_app_selector.dart, dashboard_screen.dart, reports_screen.dart,
// history_screen.dart) — agregar o cambiar una app significaba editar los
// 4 y arriesgarse a que queden desincronizados (ya pasó: Custom/Truck tenía
// dos colores distintos según la pantalla). Ahora todos importan este
// archivo.

import 'package:flutter/material.dart';

@immutable
class GigApp {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const GigApp({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

class GigAppCatalog {
  GigAppCatalog._();

  // Ícono/color de fallback para cualquier gig_app que no esté en la lista
  // (dato legado, o gig_app_id todavía no agregado acá).
  static const GigApp _fallback = GigApp(
    id: '',
    name: '',
    icon: Icons.local_shipping_rounded,
    color: Color(0xFF475569),
  );

  static const List<GigApp> all = [
    GigApp(
      id: 'uber',
      name: 'Uber',
      icon: Icons.directions_car_rounded,
      color: Color(0xFF1E1E1E),
    ),
    GigApp(
      id: 'lyft',
      name: 'Lyft',
      icon: Icons.electric_car_rounded,
      color: Color(0xFFFF00BF),
    ),
    // Empower pasó de teal (0xFF00A3AD) a azul navy — ese teal que dejó
    // libre se lo lleva el ícono nuevo de Roadie.
    GigApp(
      id: 'empower',
      name: 'Empower',
      icon: Icons.person_pin_circle_rounded,
      color: Color(0xFF1E3A8A),
    ),
    GigApp(
      id: 'amazon',
      name: 'Amazon Flex',
      icon: Icons.inventory_2_rounded,
      color: Color(0xFFFF9900),
    ),
    GigApp(
      id: 'uber_eats',
      name: 'Uber Eats',
      icon: Icons.restaurant_rounded,
      color: Color(0xFF06C167),
    ),
    GigApp(
      id: 'doordash',
      name: 'DoorDash',
      icon: Icons.fastfood_rounded,
      color: Color(0xFFFF3008),
    ),
    GigApp(
      id: 'instacart',
      name: 'Instacart',
      icon: Icons.shopping_basket_rounded,
      color: Color(0xFF43B02A),
    ),
    GigApp(
      id: 'roadie',
      name: 'Roadie',
      icon: Icons.route_rounded,
      color: Color(0xFF00A3AD),
    ),
    // Explicit user request (2026-08-27): 3 platforms ControlMiles had
    // no coverage for at all, manual selection included -- added here
    // first (gig_app_packages' catalog only maps a package to an id
    // that already exists in THIS list; a package-only entry with no
    // matching GigApp would fall back to the generic icon/raw-id name).
    GigApp(
      id: 'veho',
      name: 'Veho',
      icon: Icons.local_post_office_rounded,
      color: Color(0xFF7C3AED),
    ),
    GigApp(
      id: 'jitsu',
      name: 'Jitsu',
      icon: Icons.local_mall_rounded,
      color: Color(0xFF0EA5E9),
    ),
    GigApp(
      id: 'walmart_spark',
      name: 'Spark Driver',
      icon: Icons.bolt_rounded,
      color: Color(0xFFFFC220),
    ),
    // BUG FIX (pedido explícito): Custom/Truck tenía dos colores distintos
    // según la pantalla — azul #2563EB en el carrusel (gig_app_selector.dart)
    // vs. gris pizarra #475569 en Dashboard/Reports/Historial. Se unificó
    // a #475569 (el que ya usaban 3 de las 4 pantallas).
    // BUG FIX (pedido explícito, bug #1 del batch de 4): Custom debe ser
    // siempre la última tarjeta del carrusel (extremo derecho) — se movió
    // al final de la lista, después de Roadie.
    GigApp(
      id: 'custom',
      name: 'Custom/Truck',
      icon: Icons.local_shipping_rounded,
      color: Color(0xFF475569),
    ),
  ];

  /// Busca una gig app por id. Si no existe en el catálogo (dato legado o
  /// id nuevo todavía no agregado acá), devuelve un fallback neutro con el
  /// mismo id/nombre crudo en vez de tirar una excepción.
  static GigApp byId(String id) {
    for (final app in all) {
      if (app.id == id) return app;
    }
    return GigApp(
      id: id,
      name: id,
      icon: _fallback.icon,
      color: _fallback.color,
    );
  }
}

// BUG FIX (pedido explícito): irs_purpose se guarda correctamente en la DB
// desde hace semanas (gig_app_selector.dart ya lo captura, tracking_
// controller.dart ya lo persiste) pero NADA lo mostraba después -- ni
// history_screen.dart, ni reports_screen.dart, ni el PDF de report_service.
// dart lo leían nunca. Un viaje "Custom" sin su propósito visible no sirve
// para validar la deducción ante una autoridad, que es exactamente para lo
// que existe este campo. Fuente única de verdad para el mapeo id -> label,
// mismo criterio que GigAppCatalog arriba (antes esto habría terminado
// duplicado a mano en 3 archivos).
class IrsPurposeCatalog {
  IrsPurposeCatalog._();

  // id -> clave i18n (para UI en pantalla, localizada). Mismos ids que ya
  // usa gig_app_selector.dart's categories list -- no reinventar acá.
  static const Map<String, String> _labelKeys = {
    'business': 'business_purpose',
    'work': 'work_commute',
    'medical': 'medical',
    'moving': 'moving',
    'charitable': 'charitable',
    'education': 'education_study',
    'personal': 'personal_other',
  };

  // id -> texto plano en inglés (para el PDF, que ya es 100% inglés
  // hardcodeado sin importar el idioma de la app -- mismo criterio que
  // "VERIFIED" y los demás textos fijos de report_service.dart).
  static const Map<String, String> _plainLabels = {
    'business': 'Business',
    'work': 'Work Commute',
    'medical': 'Medical',
    'moving': 'Moving',
    'charitable': 'Charitable',
    'education': 'Education',
    'personal': 'Personal',
  };

  static String? labelKeyFor(String? purposeId) =>
      (purposeId == null || purposeId.isEmpty) ? null : _labelKeys[purposeId];

  static String plainLabelFor(String? purposeId) =>
      (purposeId == null || purposeId.isEmpty) ? '' : (_plainLabels[purposeId] ?? purposeId);
}
