import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

const premiumProductIds = <String>{
  'defyx_premium_1_month',
  'defyx_premium_3_months',
  'defyx_premium_6_months',
  'defyx_premium_12_months',
};

final premiumPurchaseProvider =
    StateNotifierProvider<PremiumPurchaseNotifier, PremiumPurchaseState>(
      (ref) => PremiumPurchaseNotifier(),
    );

class PremiumPurchaseState {
  final bool isAvailable;
  final bool isLoading;
  final List<ProductDetails> products;
  final String? errorMessage;
  final PurchaseDetails? lastPurchase;

  const PremiumPurchaseState({
    this.isAvailable = false,
    this.isLoading = false,
    this.products = const [],
    this.errorMessage,
    this.lastPurchase,
  });

  PremiumPurchaseState copyWith({
    bool? isAvailable,
    bool? isLoading,
    List<ProductDetails>? products,
    String? errorMessage,
    PurchaseDetails? lastPurchase,
    bool clearError = false,
  }) {
    return PremiumPurchaseState(
      isAvailable: isAvailable ?? this.isAvailable,
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastPurchase: lastPurchase ?? this.lastPurchase,
    );
  }
}

class PremiumPurchaseNotifier extends StateNotifier<PremiumPurchaseState> {
  PremiumPurchaseNotifier() : super(const PremiumPurchaseState()) {
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object error) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        );
      },
    );
    loadProducts();
  }

  final _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final available = await _inAppPurchase.isAvailable();
    if (!available) {
      state = state.copyWith(isAvailable: false, isLoading: false);
      return;
    }

    final response = await _inAppPurchase.queryProductDetails(
      premiumProductIds,
    );
    if (response.error != null) {
      state = state.copyWith(
        isAvailable: true,
        isLoading: false,
        errorMessage: response.error!.message,
      );
      return;
    }

    state = state.copyWith(
      isAvailable: true,
      isLoading: false,
      products: response.productDetails,
    );
  }

  Future<void> purchase(ProductDetails product) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _inAppPurchase.restorePurchases();
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      state = state.copyWith(isLoading: false, lastPurchase: purchase);

      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
