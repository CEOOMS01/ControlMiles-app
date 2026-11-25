// Olympus Mont Systems LLC - ControlMiles
// lib/logic/profile_merge.dart
//
// What the app does with a profile read from the server (2026-11-24). Testers said
// that after every update something in their setup was gone (the plan, the name).
// Cause: an answer with no row (the session not ready yet, a short network or
// policy hiccup) was read as "no subscription, no name" and those defaults were
// SAVED over the good values. Now an answer only changes what it really carries;
// everything else keeps what the phone already knew.

class ProfileSnapshot {
  final String? displayId;
  final String? firstName;
  final String accountType;
  final bool premiumEntitled;
  final bool baseEntitled;
  final String mileageMethod;
  final DateTime? accountCreatedAt;
  final bool tierEnforcementExempt;

  const ProfileSnapshot({
    required this.displayId,
    required this.firstName,
    required this.accountType,
    required this.premiumEntitled,
    required this.baseEntitled,
    required this.mileageMethod,
    required this.accountCreatedAt,
    required this.tierEnforcementExempt,
  });

  @override
  bool operator ==(Object other) =>
      other is ProfileSnapshot &&
      other.displayId == displayId &&
      other.firstName == firstName &&
      other.accountType == accountType &&
      other.premiumEntitled == premiumEntitled &&
      other.baseEntitled == baseEntitled &&
      other.mileageMethod == mileageMethod &&
      other.accountCreatedAt == accountCreatedAt &&
      other.tierEnforcementExempt == tierEnforcementExempt;

  @override
  int get hashCode => Object.hash(
    displayId,
    firstName,
    accountType,
    premiumEntitled,
    baseEntitled,
    mileageMethod,
    accountCreatedAt,
    tierEnforcementExempt,
  );
}

/// The profile after reading [row] from the server, starting from what the phone
/// [known] already. A missing row changes nothing; a missing field keeps its value.
/// A field the server does send always wins (a plan that really lapsed is `false`).
ProfileSnapshot mergeProfile(ProfileSnapshot known, Map<String, dynamic>? row) {
  if (row == null) return known;

  String? text(String key, String? keep) {
    final v = row[key];
    return v is String && v.isNotEmpty ? v : keep;
  }

  bool flag(String key, bool keep) {
    final v = row[key];
    return v is bool ? v : keep;
  }

  final created = row['created_at'];
  return ProfileSnapshot(
    displayId: text('display_id', known.displayId),
    firstName: text('first_name', known.firstName),
    accountType: text('account_type', known.accountType) ?? known.accountType,
    premiumEntitled: flag('premium_entitled', known.premiumEntitled),
    baseEntitled: flag('base_entitled', known.baseEntitled),
    mileageMethod:
        text('mileage_method', known.mileageMethod) ?? known.mileageMethod,
    accountCreatedAt: created is String
        ? (DateTime.tryParse(created) ?? known.accountCreatedAt)
        : known.accountCreatedAt,
    tierEnforcementExempt: flag(
      'tier_enforcement_exempt',
      known.tierEnforcementExempt,
    ),
  );
}
