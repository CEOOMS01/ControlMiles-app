// Olympus Mont Systems LLC - ControlMiles
// lib/screens/subscription_screen.dart
//
// Real Stripe subscription management (see [[project_controlmiles]]).
// Two real tiers (2026-08-28): Base ($5.99, core app usage -- no
// enforcement built yet, see AppState.baseEntitled's own comment) and
// Premium ($9.99, adds Automatic Detection on top of everything Base
// has). This screen never collects a card number -- "Upgrade" and
// "Manage subscription" both call a Supabase edge function that returns
// a Stripe-hosted URL, opened externally via url_launcher. Payment
// details go straight to Stripe; this screen only ever reflects
// AppState.baseEntitled/premiumEntitled, which stripe-webhook keeps in
// sync server-side.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/app_state.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  // Tracks which tier's button is spinning, so tapping Base doesn't
  // disable Premium's button too (and vice versa).
  String? _loadingTier;

  Future<void> _upgrade(AppState appState, String tier) async {
    if (!mounted) return;
    setState(() => _loadingTier = tier);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create-checkout-session',
        body: {'tier': tier},
      );
      await _openReturnedUrl(appState, response.data);
    } catch (e) {
      _showError(appState, e);
    } finally {
      if (mounted) setState(() => _loadingTier = null);
    }
  }

  Future<void> _manageSubscription(AppState appState) async {
    if (!mounted) return;
    setState(() => _loadingTier = 'manage');
    try {
      final response = await Supabase.instance.client.functions.invoke('create-portal-session');
      await _openReturnedUrl(appState, response.data);
    } catch (e) {
      _showError(appState, e);
    } finally {
      if (mounted) setState(() => _loadingTier = null);
    }
  }

  Future<void> _openReturnedUrl(AppState appState, dynamic data) async {
    if (data is Map && data['configured'] == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appState.tr('subscriptions_not_configured'))),
        );
      }
      return;
    }

    final url = data is Map ? data['url'] as String? : null;
    if (url == null) {
      throw Exception(data is Map ? data['error'] : 'no url returned');
    }

    final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${appState.tr('error')}: could not open browser')),
      );
    }
  }

  void _showError(AppState appState, Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${appState.tr('error')}: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildTierCard(
    AppState appState, {
    required bool isDark,
    required String titleKey,
    required String descriptionKey,
    required String priceLabel,
    required bool isCurrent,
    required bool showUpgrade,
    required String tier,
  }) {
    final isLoading = _loadingTier == tier;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                appState.tr(titleKey),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              Text(
                priceLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            appState.tr(descriptionKey),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          if (isCurrent)
            Row(
              children: [
                Icon(Icons.verified_rounded, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Text(
                  appState.tr('current_plan'),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.green),
                ),
              ],
            )
          else if (showUpgrade)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isLoading ? null : () => _upgrade(appState, tier),
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : Text(appState.tr('upgrade_plan')),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseEntitled = appState.baseEntitled;
    final premiumEntitled = appState.premiumEntitled;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(appState.tr('subscription')),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildTierCard(
            appState,
            isDark: isDark,
            titleKey: 'basic_plan',
            descriptionKey: 'base_plan_description',
            priceLabel: '\$5.99/mo',
            isCurrent: baseEntitled && !premiumEntitled,
            // Premium already includes Base -- no point offering a
            // downgrade-shaped "Upgrade to Base" button to a Premium
            // subscriber.
            showUpgrade: !premiumEntitled,
            tier: 'base',
          ),
          const SizedBox(height: 16),
          _buildTierCard(
            appState,
            isDark: isDark,
            titleKey: 'premium_plan',
            descriptionKey: 'premium_plan_description',
            priceLabel: '\$9.99/mo',
            isCurrent: premiumEntitled,
            showUpgrade: !premiumEntitled,
            tier: 'premium',
          ),
          if (baseEntitled || premiumEntitled) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _loadingTier == 'manage' ? null : () => _manageSubscription(appState),
              child: _loadingTier == 'manage'
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : Text(appState.tr('manage_subscription')),
            ),
          ],
        ],
      ),
    );
  }
}
