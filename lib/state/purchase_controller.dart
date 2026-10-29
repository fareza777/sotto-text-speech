import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'settings_controller.dart';

/// One-time "Remove ads" purchase handled by Google Play Billing.
///
/// The product must exist in Play Console with this exact ID. Until it does,
/// [productReady] stays false and the UI offers the rewarded alternative.
class PurchaseController extends ChangeNotifier {
  PurchaseController(this._settings);

  static const removeAdsId = 'sotto_remove_ads';

  final SettingsController _settings;
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;
  bool _available = false;
  bool _busy = false;
  String? _error;

  bool get available => _available;
  bool get purchased => _settings.adsRemoved;
  bool get busy => _busy;
  bool get productReady => _product != null;
  String? get error => _error;
  String get price => _product?.price ?? r'$4.99';

  Future<void> init() async {
    try {
      _available = await _iap.isAvailable();
      if (!_available) {
        notifyListeners();
        return;
      }
      _sub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object error) {
          _error = '$error';
          notifyListeners();
        },
      );
      await _loadProduct();
      unawaited(_iap.restorePurchases().catchError((Object _) {}));
    } catch (error) {
      _error = '$error';
    }
    notifyListeners();
  }

  Future<void> _loadProduct() async {
    final response = await _iap.queryProductDetails({removeAdsId});
    if (response.productDetails.isNotEmpty) {
      _product = response.productDetails.first;
      _error = null;
    } else if (response.error != null) {
      _error = response.error!.message;
    }
  }

  Future<void> buyRemoveAds() async {
    final product = _product;
    if (product == null) {
      _error = 'Remove ads is not available in this build yet.';
      notifyListeners();
      return;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _error = 'Google Play could not start the purchase.';
      }
    } catch (error) {
      _error = '$error';
    }
    _busy = false;
    notifyListeners();
  }

  Future<void> restore() async {
    if (!_available) return;
    try {
      await _iap.restorePurchases();
    } catch (error) {
      _error = '$error';
      notifyListeners();
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != removeAdsId) continue;
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _settings.setAdsRemoved(true);
        case PurchaseStatus.error:
          _error = purchase.error?.message ?? 'The purchase failed.';
        case PurchaseStatus.pending:
        case PurchaseStatus.canceled:
          break;
      }
      if (purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
        } catch (_) {
          // Acknowledging again on the next launch is handled by Play.
        }
      }
    }
    notifyListeners();
  }

  /// Debug-only switch so the purchase UI can be exercised on a sideloaded build.
  Future<void> debugToggleEntitlement() async {
    await _settings.setAdsRemoved(!_settings.adsRemoved);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
