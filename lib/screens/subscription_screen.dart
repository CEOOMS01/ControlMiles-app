// Olympus Mont Systems LLC - ControlMiles
// lib/screens/subscription_screen.dart
//
// Personal plans, billed natively through Google Play (user decision
// 2026-09-29: no Stripe in the app; fleet plans stay on Stripe on
// controlmiles.com). One plan since 2026-11-13, sold monthly ($9.99) or yearly
// (Play subscription controlmiles_premium_monthly with a yearly base plan, or
// controlmiles_premium_annual; the 15-day free trial is a Play Console offer). Basic is no
// longer sold. Prices shown are Google Play's own, in the buyer's currency. This
// screen never grants anything: PlayBillingService sends each purchase to
// verify-play-purchase, which checks it with Google before turning the plan on.

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/app_state.dart';
import '../services/play_billing_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, this.previewPrices});

  /// Test/preview only: prices to show without Google Play (monthly, yearly, saving %).
  final ({String monthly, String annual, int? savings})? previewPrices;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _billing = PlayBillingService.instance;
  ProductDetails? _monthly;
  ProductDetails? _annual;
  // Yearly is what the card opens on when Play offers it (the cheaper way to pay).
  bool _chooseAnnual = true;
  bool _storeAvailable = true;
  bool _loadingProducts = true;
  // 'plan' while Google Play's sheet is open, 'restore' while restoring.
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
      // Knows the current Play subscription, so Basic -> Premium is an
      // upgrade (replacement), never a second subscription.
      await _billing.refreshOwned();
      final available = await _billing.isAvailable();
      final options = available ? await _billing.loadPlanOptions() : (monthly: null, annual: null);
      if (!mounted) return;
      setState(() {
        _storeAvailable = available;
        _monthly = options.monthly;
        _annual = options.annual;
        _chooseAnnual = options.annual != null;
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

  Future<void> _upgrade(AppState appState) async {
    final product = _chooseAnnual ? _annual : _monthly;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.tr('subscriptions_not_configured'))),
      );
      return;
    }
    setState(() => _loadingTier = 'plan');
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

  String _monthlyLabel() => widget.previewPrices?.monthly ??
      (_monthly == null ? '\$9.99/mo' : '${_billing.recurringPrice(_monthly!)}/mo');

  String _annualLabel() =>
      widget.previewPrices?.annual ?? (_annual == null ? '' : '${_billing.recurringPrice(_annual!)}/yr');

  Widget _billingChoice(
    AppState appState, {
    required bool selected,
    required String titleKey,
    required String price,
    String? badge,
    required VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          // Same height with or without the "Save %" line, so the two tiles line up.
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : (isDark ? Colors.white24 : const Color(0xFFD9D2C3)),
              width: selected ? 1.8 : 1,
            ),
            color: selected ? scheme.primary.withValues(alpha: 0.08) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appState.tr(titleKey),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF2E281F),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                price,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: scheme.primary),
              ),
              if (badge != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    badge,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.green),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The one plan. Monthly and yearly are two ways to pay for it: the choice only
  /// appears when Play offers both.
  Widget _buildPlanCard(AppState appState, {required bool isDark, required bool isCurrent}) {
    final isLoading = _loadingTier == 'plan';
    final both = widget.previewPrices != null || (_monthly != null && _annual != null);
    final annualSelected = both && _chooseAnnual;
    final savings = widget.previewPrices != null
        ? widget.previewPrices!.savings
        : PlayBillingService.savingsPercent(_monthly, _annual);
    final priceLabel = annualSelected ? _annualLabel() : _monthlyLabel();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1812) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(Icons.workspace_premium_rounded, color: Theme.of(context).colorScheme.primary, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  appState.tr('premium_plan'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    color: isDark ? Colors.white : const Color(0xFF2E281F),
                  ),
                ),
              ),
              // The current plan shows no single price: the app cannot tell from Play whether this
              // account pays monthly or yearly, and the yearly price was shown for both (2026-11-17).
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        appState.tr('current_plan'),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.green),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  priceLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            appState.tr('premium_plan_description'),
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF6B6250),
            ),
          ),
          const SizedBox(height: 18),
          if (isCurrent) ...[
            if (both)
              Row(
                children: [
                  _billingChoice(
                    appState,
                    selected: false,
                    titleKey: 'billing_monthly',
                    price: _monthlyLabel(),
                    onTap: null,
                  ),
                  const SizedBox(width: 10),
                  _billingChoice(
                    appState,
                    selected: false,
                    titleKey: 'billing_annual',
                    price: _annualLabel(),
                    badge: savings == null
                        ? null
                        : appState.tr('billing_save').replaceFirst('{pct}', '$savings'),
                    onTap: null,
                  ),
                ],
              ),
          ] else ...[
            if (both) ...[
              Row(
                children: [
                  _billingChoice(
                    appState,
                    selected: !annualSelected,
                    titleKey: 'billing_monthly',
                    price: _monthlyLabel(),
                    onTap: () => setState(() => _chooseAnnual = false),
                  ),
                  const SizedBox(width: 10),
                  _billingChoice(
                    appState,
                    selected: annualSelected,
                    titleKey: 'billing_annual',
                    price: _annualLabel(),
                    badge: savings == null
                        ? null
                        : appState.tr('billing_save').replaceFirst('{pct}', '$savings'),
                    onTap: () => setState(() => _chooseAnnual = true),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (isLoading || _loadingProducts || !_storeAvailable) ? null : () => _upgrade(appState),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final premiumEntitled = appState.premiumEntitled;
    final onFreeTrial = appState.isOnFreeTrial;
    final trialDaysLeft = appState.freeTrialDaysLeft;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12100C) : const Color(0xFFFAF6EE),
      appBar: AppBar(
        title: Text(appState.tr('subscription')),
        backgroundColor: isDark ? const Color(0xFF1C1812) : const Color(0xFF2E281F),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (onFreeTrial && trialDaysLeft != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                appState.tr('free_trial_note').replaceFirst('{days}', '$trialDaysLeft'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
          _buildPlanCard(appState, isDark: isDark, isCurrent: premiumEntitled),
          if (!_loadingProducts && !_storeAvailable) ...[
            const SizedBox(height: 16),
            Text(
              appState.tr('play_store_unavailable'),
              style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white60 : const Color(0xFF6B6250)),
            ),
          ],
          if (appState.baseEntitled || premiumEntitled) ...[
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: _manageSubscription,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(appState.tr('manage_subscription')),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
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
