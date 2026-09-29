// Olympus Mont Systems LLC - ControlMiles
// lib/screens/subscription_screen.dart
//
// Personal plans, billed natively through Google Play (user decision
// 2026-09-29: no Stripe in the app; fleet plans stay on Stripe on
// controlmiles.com). Three-tier model: Started (the automatic 15-day free
// trial, no purchase -- AppState.isFreeTrialExpired), Basic and Premium
// (Play subscriptions controlmiles_basic_monthly / _premium_monthly; any
// Premium free trial is a Play Console offer). Prices shown are Google
// Play's own, in the buyer's currency. This screen never grants anything:
// PlayBillingService sends each purchase to verify-play-purchase, which
// checks it with Google before turning Basic/Premium on.

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/app_state.dart';
import '../services/play_billing_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _billing = PlayBillingService.instance;
  Map<String, ProductDetails> _products = {};
  bool _storeAvailable = true;
  bool _loadingProducts = true;
  // Which tier's button is spinning while Google Play's sheet is open.
  String? _loadingTier;

  @override
  void initState() {
    super.initState();
    _billing.events.addListener(_onBillingEvent);
    _loadProducts();
  }

  @override
  void dispose() {
    _billing.events.removeListener(_onBillingEvent);
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final available = await _billing.isAvailable();
      final products = available ? await _billing.loadProducts() : <String, ProductDetails>{};
      if (!mounted) return;
      setState(() {
        _storeAvailable = available;
        _products = products;
        _loadingProducts = false;
      });
    } catch (e) {
      debugPrint('[Subscription] loading Play products failed: $e');
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  void _onBillingEvent() {
    final event = _billing.events.value;
    if (!mounted || event == null) return;
    final appState = context.read<AppState>();
    if (event != PlayBillingEvent.pending) setState(() => _loadingTier = null);
    final message = switch (event) {
      PlayBillingEvent.verified => appState.tr('purchase_success'),
      PlayBillingEvent.pending => appState.tr('purchase_pending'),
      PlayBillingEvent.failed => appState.tr('purchase_failed'),
      PlayBillingEvent.notConfigured => appState.tr('subscriptions_not_configured'),
      PlayBillingEvent.canceled => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: event == PlayBillingEvent.failed ? Colors.red : null,
      ));
    }
  }

  Future<void> _upgrade(AppState appState, String productId) async {
    final product = _products[productId];
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.tr('subscriptions_not_configured'))),
      );
      return;
    }
    setState(() => _loadingTier = productId);
    try {
      await _billing.buy(product);
    } catch (e) {
      debugPrint('[Subscription] purchase launch failed: $e');
      if (!mounted) return;
      setState(() => _loadingTier = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.tr('purchase_failed')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _restore(AppState appState) async {
    setState(() => _loadingTier = 'restore');
    try {
      await _billing.restore();
    } finally {
      // Restored purchases arrive through the purchase stream; the spinner
      // only covers the request itself.
      if (mounted) setState(() => _loadingTier = null);
    }
  }

  /// Google Play's own subscription page for this app (cancel, change
  /// payment method, see renewal date).
  Future<void> _manageSubscription() async {
    final uri = Uri.parse(
      'https://play.google.com/store/account/subscriptions?package=com.olimsys.controlmiles',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _priceLabel(String productId, String fallback) {
    final p = _products[productId];
    return p == null ? fallback : '${p.price}/mo';
  }

  Widget _buildTierCard(
    AppState appState, {
    required bool isDark,
    required String titleKey,
    required String descriptionKey,
    required String priceLabel,
    required bool isCurrent,
    required bool showUpgrade,
    required String productId,
  }) {
    final isLoading = _loadingTier == productId;

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
                onPressed: (isLoading || _loadingProducts || !_storeAvailable)
                    ? null
                    : () => _upgrade(appState, productId),
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
    final onFreeTrial = appState.isOnFreeTrial;
    final trialDaysLeft = appState.freeTrialDaysLeft;

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
          if (onFreeTrial) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        appState.tr('started_plan'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      Icon(Icons.verified_rounded, color: Colors.green, size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appState.tr('started_plan_description'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                  if (trialDaysLeft != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      appState.tr('trial_days_left').replaceFirst('{days}', '$trialDaysLeft'),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.green),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildTierCard(
            appState,
            isDark: isDark,
            titleKey: 'basic_plan',
            descriptionKey: 'base_plan_description',
            priceLabel: _priceLabel(PlayBillingService.basicProductId, '\$5.99/mo'),
            isCurrent: baseEntitled && !premiumEntitled,
            // Premium already includes Base -- no point offering a
            // downgrade-shaped "Upgrade to Base" button to a Premium
            // subscriber.
            showUpgrade: !premiumEntitled,
            productId: PlayBillingService.basicProductId,
          ),
          const SizedBox(height: 16),
          _buildTierCard(
            appState,
            isDark: isDark,
            titleKey: 'premium_plan',
            descriptionKey: 'premium_plan_description',
            priceLabel: _priceLabel(PlayBillingService.premiumProductId, '\$9.99/mo'),
            isCurrent: premiumEntitled,
            showUpgrade: !premiumEntitled,
            productId: PlayBillingService.premiumProductId,
          ),
          if (!_loadingProducts && !_storeAvailable) ...[
            const SizedBox(height: 16),
            Text(
              appState.tr('play_store_unavailable'),
              style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
          ],
          if (baseEntitled || premiumEntitled) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _manageSubscription,
              child: Text(appState.tr('manage_subscription')),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadingTier == 'restore' ? null : () => _restore(appState),
            child: Text(appState.tr('restore_purchases')),
          ),
        ],
      ),
    );
  }
}
