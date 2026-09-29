// Olympus Mont Systems LLC - ControlMiles
// lib/models/organization.dart

class Organization {
  final String id;
  final String name;
  final String? slug;
  final String? createdBy;
  final String complianceMode; // 'light_duty' | 'regulated_cmv' -- see
  // supabase/migrations organizations_add_compliance_mode: reserved for the
  // future FMCSA-certified ELD hardware tier, not built yet. Every org
  // created through the app today is 'light_duty'.
  final bool isActive;
  final DateTime createdAt;

  const Organization({
    required this.id,
    required this.name,
    this.slug,
    this.createdBy,
    required this.complianceMode,
    required this.isActive,
    required this.createdAt,
  });

  bool get isRegulatedCmv => complianceMode == 'regulated_cmv';

  factory Organization.fromMap(Map<String, dynamic> map) {
    return Organization(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      slug: map['slug'] as String?,
      createdBy: map['created_by'] as String?,
      complianceMode: map['compliance_mode'] as String? ?? 'light_duty',
      isActive: map['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class OrganizationMember {
  final String id;
  final String organizationId;
  final String userId;
  final String memberRole; // 'owner' | 'admin' | 'driver'
  final bool isActive;
  final DateTime? joinedAt;
  // From the embedded profiles row (listMembers). Found live 2026-09-29:
  // the fleet roster showed only "OWNER" / "DRIVER" with no names.
  final String? name;
  final String? displayId;

  const OrganizationMember({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.memberRole,
    required this.isActive,
    this.joinedAt,
    this.name,
    this.displayId,
  });

  bool get isOwnerOrAdmin => memberRole == 'owner' || memberRole == 'admin';

  static String? _profileName(dynamic profile) {
    if (profile is! Map) return null;
    final parts = [profile['first_name'], profile['last_name']]
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty)
        .join(' ');
    if (parts.isNotEmpty) return parts;
    final full = profile['full_name'] as String?;
    if (full != null && full.trim().isNotEmpty) return full;
    return profile['email'] as String?;
  }

  factory OrganizationMember.fromMap(Map<String, dynamic> map) {
    return OrganizationMember(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      userId: map['user_id'] as String,
      memberRole: map['member_role'] as String? ?? 'driver',
      isActive: map['is_active'] as bool? ?? true,
      joinedAt: map['joined_at'] != null
          ? DateTime.parse(map['joined_at'] as String)
          : null,
      name: _profileName(map['profiles']),
      displayId: (map['profiles'] as Map?)?['display_id'] as String?,
    );
  }
}

/// Fleet Phase 2: a not-yet-accepted organization_members row (is_active =
/// false), read from the invited user's own side -- includes the org's
/// name via the embedded FK select (organization_members.organization_id
/// -> organizations), so the accept/decline screen never needs a second
/// round-trip just to show which fleet is inviting them.
class PendingInvite {
  final String membershipId;
  final String organizationId;
  final String organizationName;
  final DateTime? invitedAt;

  const PendingInvite({
    required this.membershipId,
    required this.organizationId,
    required this.organizationName,
    this.invitedAt,
  });

  factory PendingInvite.fromMap(Map<String, dynamic> map) {
    final org = map['organizations'] as Map<String, dynamic>?;
    return PendingInvite(
      membershipId: map['id'] as String,
      organizationId: map['organization_id'] as String,
      organizationName: org?['name'] as String? ?? '',
      invitedAt: map['invited_at'] != null
          ? DateTime.parse(map['invited_at'] as String)
          : null,
    );
  }
}
