// Olympus Mont Systems LLC - ControlMiles
// lib/widgets/org_mode_switcher.dart
//
// Fleet Sprint 2 (dual-mode UX, 2026-09-09): promotes switch_account_mode
// from its previous buried location (a plain list in Settings, shown to
// EVERY user regardless of eligibility) into a real context selector for
// hybrid users -- someone who both drives personally and belongs to a
// fleet.
//
// A NON-hybrid, 100% corporate driver (created via the invite-link flow's
// Case A, or a manually-claimed driver slot -- never had a personal
// account before) also ends up with defaultOrgId set, same as a real
// hybrid user -- defaultOrgId alone can't tell the two apart. The real
// distinguishing signal is whether this account has EVER tracked a
// personal (organization_id IS NULL) session: a currently-'gig' account
// with an org already proves it (they're literally in personal mode right
// now), and a currently-fleet account additionally checks its own trip
// history once. Exclusive corporate drivers (the spec's explicit "no
// necesita configurar vehículos personales" case) see nothing here.
//
// Deliberately does NOT try to guess whether the caller is that org's
// owner or a driver before calling the RPC -- switch_account_mode('fleet_
// admin') is attempted first (the common case for whoever set this up),
// and only on its own rejection does this fall back to 'fleet_driver'.
// The RPC's own role check is the real source of truth either way; a
// separate role lookup here would just be a second, driftable copy of it.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/app_state.dart';
import '../routes/app_routes.dart';
import '../services/organization_service.dart';
import '../errors/app_error.dart';

class OrgModeSwitcher extends StatefulWidget {
  const OrgModeSwitcher({super.key});

  @override
  State<OrgModeSwitcher> createState() => _OrgModeSwitcherState();
}

class _OrgModeSwitcherState extends State<OrgModeSwitcher> {
  final _organizationService = OrganizationService();
  String? _orgName;
  String? _orgNameForId;
  bool _isSwitching = false;
  bool? _hasPersonalHistory;

  Future<void> _loadOrgName(String orgId) async {
    if (_orgNameForId == orgId) return;
    final org = await _organizationService.getOrganization(orgId);
    if (mounted) {
      setState(() {
        _orgName = org?.name;
        _orgNameForId = orgId;
      });
    }
  }

  Future<void> _loadPersonalHistoryCheck() async {
    if (_hasPersonalHistory != null) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final row = await Supabase.instance.client
          .from('sessions')
          .select('id')
          .eq('user_id', userId)
          .isFilter('organization_id', null)
          .limit(1)
          .maybeSingle();
      if (mounted) setState(() => _hasPersonalHistory = row != null);
    } catch (_) {
      // Fails closed on purpose -- a lookup hiccup should not accidentally
      // expose the personal/company switcher to an exclusive corporate
      // driver who never had personal usage.
      if (mounted) setState(() => _hasPersonalHistory = false);
    }
  }

  Future<void> _switchTo(AppState appState, bool toCompany) async {
    if (_isSwitching) return;
    setState(() => _isSwitching = true);

    try {
      if (!toCompany) {
        await _organizationService.switchAccountMode('gig');
      } else {
        try {
          await _organizationService.switchAccountMode('fleet_admin');
        } catch (_) {
          await _organizationService.switchAccountMode('fleet_driver');
        }
      }

      await appState.refreshAccountType();
      if (!mounted) return;

      final target = toCompany
          ? (appState.isFleetAdmin ? AppRoutes.fleetDashboard : AppRoutes.driverOperations)
          : AppRoutes.dashboard;
      Navigator.pushNamedAndRemoveUntil(context, target, (route) => false);
    } catch (e) {
      if (mounted) {
        final appError = AppError.from(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appError.display(appState.tr(appError.messageKey))),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSwitching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final orgId = appState.defaultOrgId;

    // Hybrid-eligibility gate -- see file header. A plain gig account with
    // no org membership sees nothing here, full stop.
    if (orgId == null) return const SizedBox.shrink();

    // Currently in gig mode WITH an org on file already proves hybrid
    // status on its own (see file header) -- only a currently-fleet
    // account needs the extra personal-history check before showing this.
    if (appState.isFleetAccount) {
      _loadPersonalHistoryCheck();
      if (_hasPersonalHistory != true) return const SizedBox.shrink();
    }

    _loadOrgName(orgId);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final inactiveText = isDark ? Colors.white60 : const Color(0xFF64748B);
    final isCompanyMode = appState.isFleetAccount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segment(
              label: appState.tr('org_mode_personal'),
              selected: !isCompanyMode,
              primary: primary,
              inactiveText: inactiveText,
              onTap: () => _switchTo(appState, false),
            ),
          ),
          Expanded(
            child: _segment(
              label: appState
                  .tr('org_mode_company')
                  .replaceFirst('{org}', _orgName ?? '…'),
              selected: isCompanyMode,
              primary: primary,
              inactiveText: inactiveText,
              onTap: () => _switchTo(appState, true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required String label,
    required bool selected,
    required Color primary,
    required Color inactiveText,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isSwitching || selected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : inactiveText,
            ),
          ),
        ),
      ),
    );
  }
}
