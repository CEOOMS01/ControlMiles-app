// Olympus Mont Systems LLC - ControlMiles
// lib/services/play_billing_service.dart
//
// Google Play Billing for the app's personal plans (user decision
// 2026-09-29: the app stops charging through Stripe and uses Android's
// native billing; fleet plans stay on Stripe on controlmiles.com).
//
// Flow: the app buys through Google Play with applicationUserName = the
// Supabase user id; every purchase (or restore) goes to the
// verify-play-purchase edge function, which reads the real state from the
// Google Play Developer API and only then turns Basic/Premium on
// (profiles.base_entitled / premium_entitled). Only after the server
// accepted it is the purchase completed (acknowledged) here. Renewals and
// cancellations reach the server directly (play-rtdn), not through the app.
//
// The purchase stream is listened to from app start (main.dart), so a
// purchase that finishes while the app was closed is still processed.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart' show ReplacementMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum PlayBillingEvent { verified, pending, canceled, failed, notConfigured }

class PlayBillingService {
  PlayBillingService._();
  static final instance = PlayBillingService._();

  // Play Console subscription product IDs (must match _shared/google_play.ts).
  static const basicProductId = 'controlmiles_basic_monthly';
  static const premiumProductId = 'controlmiles_premium_monthly';
  static const productIds = {basicProductId, premiumProductId};

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void> Function()? _onVerified;

  /// Last outcome, for the subscription screen's spinner/snackbars.
  final ValueNotifier<PlayBillingEvent?> events = ValueNotifier(null);

  /// The subscription this device currently owns, needed to upgrade
  /// Basic -> Premium as a replacement instead of a second subscription.
  GooglePlayPurchaseDetails? _ownedSubscription;

  void start({required Future<void> Function() onVerified}) {
    _onVerified = onVerified;
    _subscription ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('[PlayBilling] purchase stream error: $e'),
    );
    if (Supabase.instance.client.auth.currentUser != null) unawaited(refreshOwned());
  }

  Future<bool> isAvailable() => _iap.isAvailable();

  /// Loads the subscription this Google account already owns from Play.
  ///
  /// Audit fix (2026-10-03): _ownedSubscription used to be set only after a
  /// purchase in the same app session, so after a restart a Basic subscriber
  /// tapping Premium bought a SECOND subscription (charged twice) instead of
  /// upgrading. Also verifies any owned purchase the server never confirmed
  /// (e.g. the app was killed mid-verification), before Google refunds it.
  Future<void> refreshOwned() async {
    try {
      if (!await _iap.isAvailable()) return;
      final addition = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases(
        applicationUserName: Supabase.instance.client.auth.currentUser?.id,
      );
      GooglePlayPurchaseDetails? owned;
      for (final purchase in response.pastPurchases) {
        if (!productIds.contains(purchase.productID)) continue;
        if (purchase.status != PurchaseStatus.purchased && purchase.status != PurchaseStatus.restored) continue;
        owned = purchase;
        if (!purchase.billingClientPurchase.isAcknowledged) {
          await _verifyAndComplete(purchase);
        }
      }
      _ownedSubscription = owned;
    } catch (e) {
      debugPrint('[PlayBilling] loading owned purchases failed: $e');
    }
  }

  /// One ProductDetails per product (Play returns one per offer; the first
  /// is the one with the base plan's current offer, e.g. a free trial).
  Future<Map<String, ProductDetails>> loadProducts() async {
    final response = await _iap.queryProductDetails(productIds);
    final byId = <String, ProductDetails>{};
    for (final p in response.productDetails) {
      byId.putIfAbsent(p.id, () => p);
    }
    return byId;
  }

  Future<void> buy(ProductDetails product) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');

    final owned = _ownedSubscription;
    final PurchaseParam param = (owned != null && owned.productID != product.id)
        ? GooglePlayPurchaseParam(
            productDetails: product,
            applicationUserName: userId,
            changeSubscriptionParam: ChangeSubscriptionParam(
              oldPurchaseDetails: owned,
              // Google's recommended mode for an upgrade: pay the prorated
              // difference now, keep the renewal date.
              replacementMode: ReplacementMode.chargeProratedPrice,
            ),
          )
        : PurchaseParam(productDetails: product, applicationUserName: userId);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    await _iap.restorePurchases(applicationUserName: userId);
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          events.value = PlayBillingEvent.pending;
          break;
        case PurchaseStatus.canceled:
          events.value = PlayBillingEvent.canceled;
          break;
        case PurchaseStatus.error:
          debugPrint('[PlayBilling] purchase error: ${purchase.error}');
          events.value = PlayBillingEvent.failed;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndComplete(purchase);
          break;
      }
    }
  }

  Future<void> _verifyAndComplete(PurchaseDetails purchase) async {
    if (!productIds.contains(purchase.productID)) return;
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'verify-play-purchase',
        body: {
          'productId': purchase.productID,
          // On Android this is the Play purchase token.
          'purchaseToken': purchase.verificationData.serverVerificationData,
        },
      );
      final data = response.data;
      if (data is Map && data['configured'] == false) {
        events.value = PlayBillingEvent.notConfigured;
        return;
      }
      if (purchase is GooglePlayPurchaseDetails) _ownedSubscription = purchase;
      // Acknowledge only once the server has it on record (the server
      // acknowledges too); Google refunds unacknowledged purchases.
      if (purchase.pendingCompletePurchase) await _iap.completePurchase(purchase);
      await _onVerified?.call();
      events.value = PlayBillingEvent.verified;
    } catch (e) {
      debugPrint('[PlayBilling] verification failed: $e');
      events.value = PlayBillingEvent.failed;
    }
  }
}
