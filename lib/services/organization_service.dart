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
import '../models/vehicle.dart';

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

  // ============================================================
  // FLEET PHASE 2 -- invites + vehicle assignment
  // ============================================================

  /// Invita a un usuario YA REGISTRADO en ControlMiles a unirse como
  /// driver. Limitación real, no oculta: organization_members.user_id
  /// tiene FK directo a profiles(id), así que no hay fila que crear hasta
  /// que esa persona ya tenga cuenta -- invitar a alguien que nunca se
  /// registró falla con un error claro ("No ControlMiles account found for
  /// that email"), no un no-op silencioso. Devuelve el id de la membresía
  /// pendiente creada.
  Future<String> inviteMemberByEmail(String organizationId, String email) async {
    final result = await _supabase.rpc(
      'invite_member_by_email',
      params: {'p_org_id': organizationId, 'p_email': email},
    );
    return result as String;
  }

  /// Acepta (accept=true) o rechaza (accept=false) una invitación
  /// pendiente. Aceptar promueve el perfil del llamador a fleet_driver
  /// server-side (ver la RPC) -- el caller debe refrescar
  /// AppState.fetchUserProfile()/fetchPendingInvites() después.
  Future<void> respondToInvite(String membershipId, bool accept) async {
    await _supabase.rpc(
      'respond_to_invite',
      params: {'p_membership_id': membershipId, 'p_accept': accept},
    );
  }

  /// Asigna un vehículo de la flota a un driver. Requiere que el llamador
  /// sea admin/owner de la organización dueña del vehículo -- verificado
  /// dentro de la RPC, no solo por RLS (ver assign_vehicle_to_driver).
  Future<void> assignVehicle({
    required String vehicleId,
    required String driverUserId,
  }) async {
    await _supabase.rpc(
      'assign_vehicle_to_driver',
      params: {'p_vehicle_id': vehicleId, 'p_driver_user_id': driverUserId},
    );
  }

  /// Todos los vehículos de la organización (asignados o no). vehicles_select
  /// (RLS) ya permite esto a cualquier miembro de la org, no solo
  /// admin/owner -- un driver puede ver la flota completa, no solo lo suyo.
  Future<List<Vehicle>> listOrgVehicles(String organizationId) async {
    final data = await _supabase
        .from('vehicles')
        .select()
        .eq('organization_id', organizationId)
        .eq('is_archived', false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data).map(Vehicle.fromMap).toList();
  }

  /// El vehículo asignado a ESTE driver específicamente -- lo que
  /// FleetDriverHomeScreen muestra en vez de un selector manual.
  Future<Vehicle?> getAssignedVehicle(String driverUserId) async {
    final data = await _supabase
        .from('vehicles')
        .select()
        .eq('assigned_driver_id', driverUserId)
        .eq('is_archived', false)
        .maybeSingle();
    return data != null ? Vehicle.fromMap(data) : null;
  }
}
