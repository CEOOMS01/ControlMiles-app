// Olympus Mont Systems LLC - ControlMiles
// lib/services/organization_service.dart
//
// Fuente única de verdad para el módulo Fleet: crear una organización,
// leerla, y listar su roster. La creación real (INSERT en organizations +
// organization_members + UPDATE de profiles.account_type) vive en el RPC
// create_organization (supabase/migrations) -- atómico en un solo statement
// de servidor en vez de 3 round-trips desde el cliente, porque
// tr_enforce_fleet_org exige que la membresía ya exista antes de que el
// UPDATE a account_type='fleet_admin' pase, y un fallo a mitad de 3 llamadas
// separadas dejaría al usuario en un estado a medias (org creada, cuenta
// todavía en 'gig').

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/organization.dart';

class OrganizationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Crea una organización nueva y promueve al llamador a fleet_admin,
  /// dueño de esa organización. Devuelve el id de la organización creada.
  Future<String> createOrganization(String name) async {
    final result = await _supabase.rpc(
      'create_organization',
      params: {'p_name': name},
    );
    return result as String;
  }

  Future<Organization?> getOrganization(String organizationId) async {
    final data = await _supabase
        .from('organizations')
        .select()
        .eq('id', organizationId)
        .maybeSingle();
    return data != null ? Organization.fromMap(data) : null;
  }

  /// Roster completo de la organización. Requiere que el llamador sea
  /// admin/owner de esa organización -- org_members_select_admin (RLS) es
  /// lo que realmente lo permite; un driver normal solo se ve a sí mismo
  /// (org_members_select_own) y esta consulta le devolvería una sola fila.
  Future<List<OrganizationMember>> listMembers(String organizationId) async {
    final data = await _supabase
        .from('organization_members')
        .select()
        .eq('organization_id', organizationId)
        .order('joined_at', ascending: true);
    return List<Map<String, dynamic>>.from(data)
        .map(OrganizationMember.fromMap)
        .toList();
  }

  /// Millas totales de la organización en el rango de fechas dado (ambos
  /// inclusive). Sumado en cliente sobre sessions.total_miles, mismo patrón
  /// que MileageDeductionBadge/_todayMiles en dashboard_screen.dart -- no
  /// hay agregación server-side para esto todavía.
  Future<double> getTotalMilesInRange(
    String organizationId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final data = await _supabase
        .from('sessions')
        .select('total_miles')
        .eq('organization_id', organizationId)
        .gte('start_time', start.toIso8601String())
        .lte('start_time', end.toIso8601String());

    double total = 0.0;
    for (final row in List<Map<String, dynamic>>.from(data)) {
      total += (row['total_miles'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }
}
