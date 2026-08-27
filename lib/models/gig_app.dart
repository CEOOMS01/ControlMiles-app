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

  // Colores (2026-08-27, pedido explícito -- mitigación legal): antes cada
  // color era literalmente el hex oficial de marca de cada plataforma. Se
  // corrieron todos un paso en tono/luminosidad -- reconocibles como "el
  // mismo color" pero ya no un match 1:1 con la guía de marca de cada
  // compañía, reduciendo el riesgo de que un mismatch de "trade dress"
  // (nombre + color de marca exacto + sin disclaimer) se sume al análisis
  // de nominative fair use. Ver [[project_controlmiles]] / la revisión de
  // riesgo legal de esta misma fecha.
  static const List<GigApp> all = [
    GigApp(
      id: 'uber',
      name: 'Uber',
      icon: Icons.directions_car_rounded,
      color: Color(0xFF2B2B33),
    ),
    GigApp(
      id: 'lyft',
      name: 'Lyft',
      icon: Icons.electric_car_rounded,
      color: Color(0xFFE0399F),
    ),
    // Empower pasó de teal (0xFF00A3AD) a azul navy — ese teal que dejó
    // libre se lo lleva el ícono nuevo de Roadie.
    GigApp(
      id: 'empower',
      name: 'Empower',
      icon: Icons.person_pin_circle_rounded,
      color: Color(0xFF2C4A96),
    ),
    GigApp(
      id: 'amazon',
      name: 'Amazon Flex',
      icon: Icons.inventory_2_rounded,
      color: Color(0xFFE8890A),
    ),
    GigApp(
      id: 'uber_eats',
      name: 'Uber Eats',
      icon: Icons.restaurant_rounded,
      color: Color(0xFF1CA85E),
    ),
    GigApp(
      id: 'doordash',
      name: 'DoorDash',
      icon: Icons.fastfood_rounded,
      color: Color(0xFFE0421F),
    ),
    GigApp(
      id: 'instacart',
      name: 'Instacart',
      icon: Icons.shopping_basket_rounded,
      color: Color(0xFF4C9E3A),
    ),
    GigApp(
      id: 'roadie',
      name: 'Roadie',
      icon: Icons.route_rounded,
      color: Color(0xFF1C97A0),
    ),
    // Shipt's driver app is literally called "Shipt Shopper" -- a
    // distinct platform from Instacart (whose own driver app package,
    // com.instacart.shopper, already maps to 'instacart' above). Added
    // same day as the veho/jitsu/walmart_spark batch below, caught
    // separately by the user after that batch shipped.
    GigApp(
      id: 'shipt',
      name: 'Shipt',
      icon: Icons.local_grocery_store_rounded,
      color: Color(0xFFB82830),
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
      color: Color(0xFF7048C4),
    ),
    GigApp(
      id: 'jitsu',
      name: 'Jitsu',
      icon: Icons.local_mall_rounded,
      color: Color(0xFF1E93C7),
    ),
    GigApp(
      id: 'walmart_spark',
      name: 'Spark Driver',
      icon: Icons.bolt_rounded,
      color: Color(0xFFE8B22E),
    ),
    // Explicit user request (2026-08-27), 12 more platforms researched via
    // WebSearch against real Play Store listings (never guessed) --
    // package names mirrored into gig_app_packages, see that migration's
    // own comment for per-app verification notes. Two of these (Wingz,
    // Alto) have NO verified Android package -- Wingz's driver app isn't
    // distributed via Google Play at all (confirmed via Wingz's own help
    // docs), and Alto's drivers are W-2 employees with no confirmed public
    // driver-specific APK, only a passenger-app package that would be the
    // wrong thing to detect against. Both still get a manual-selection
    // entry here; neither gets a gig_app_packages row, so auto-detect
    // simply never resolves to them (matches this catalog's own contract:
    // a package-only entry needs a matching id here, but an id here
    // doesn't require a package there).
    GigApp(
      id: 'grubhub',
      name: 'Grubhub',
      icon: Icons.lunch_dining_rounded,
      color: Color(0xFFD93B2E),
    ),
    GigApp(
      id: 'gopuff',
      name: 'Gopuff',
      icon: Icons.local_convenience_store_rounded,
      color: Color(0xFFB8D93A),
    ),
    // Curb has two real, currently-listed driver apps from the same
    // developer (Curb Mobility, LLC) -- "Curb Driver" and the newer
    // "Curb One" -- both mapped to this one id in gig_app_packages
    // rather than guessing which is "the" real one, same pattern already
    // used for Amazon Flex's two packages.
    GigApp(
      id: 'curb',
      name: 'Curb',
      icon: Icons.local_taxi_rounded,
      color: Color(0xFFD9A62E),
    ),
    GigApp(
      id: 'point_pickup',
      name: 'Point Pickup',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFF3B7BAD),
    ),
    GigApp(
      id: 'skipcart',
      name: 'Skipcart',
      icon: Icons.shopping_cart_rounded,
      color: Color(0xFF3F9142),
    ),
    // Real brand name is "Dispatch" (dispatchit.com); Play Store package
    // is literally com.dispatchit -- verified against the actual listing,
    // not the many unrelated "dispatch"-named logistics-SaaS apps that
    // also turned up in search.
    GigApp(
      id: 'dispatch',
      name: 'Dispatch',
      icon: Icons.delivery_dining_rounded,
      color: Color(0xFF3D5A99),
    ),
    GigApp(
      id: 'deliverthat',
      name: 'DeliverThat',
      icon: Icons.restaurant_menu_rounded,
      color: Color(0xFFC2703D),
    ),
    // No verified Android package -- see the batch comment above.
    GigApp(
      id: 'wingz',
      name: 'Wingz',
      icon: Icons.flight_takeoff_rounded,
      color: Color(0xFF5B6FA8),
    ),
    GigApp(
      id: 'hopskipdrive',
      name: 'HopSkipDrive',
      icon: Icons.school_rounded,
      color: Color(0xFF2E9E8F),
    ),
    // No verified Android package -- see the batch comment above.
    GigApp(
      id: 'alto',
      name: 'Alto',
      icon: Icons.directions_car_filled_rounded,
      color: Color(0xFF6B4FA0),
    ),
    GigApp(
      id: 'goshare',
      name: 'GoShare',
      icon: Icons.warehouse_rounded,
      color: Color(0xFFB8622E),
    ),
    // Courial (courial.com) -- corrected 2026-08-27: initially misread
    // as "Curri" (curri.com), a real but entirely different company,
    // before the user pointed to the actual courial.com site. Driver app
    // is "Courial Partner" (live.courial.partner) -- distinct from
    // com.courial.user, which is the customer-facing app, same
    // driver-vs-customer split every other platform in this catalog has.
    GigApp(
      id: 'courial',
      name: 'Courial',
      icon: Icons.miscellaneous_services_rounded,
      color: Color(0xFFBF5B2E),
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
