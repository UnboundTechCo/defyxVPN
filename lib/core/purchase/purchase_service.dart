import 'dart:async';
import 'dart:io';

import 'package:defyx_vpn/core/config/api_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class BalancePurchaseService extends ChangeNotifier {
  BalancePurchaseService({
    required this.ref,
    required this.productIds,
    required Future<void> Function() refreshBalance,
  }) : _refreshBalance = refreshBalance;

  final WidgetRef ref;
  final Set<String> productIds;
  final Future<void> Function() _refreshBalance;
  final InAppPurchase _store = InAppPurchase.instance;
  final Set<String> _processing = <String>{};

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = <ProductDetails>[];

  bool isStoreAvailable = false;
  bool isLoading = false;
  bool isPurchasing = false;
  double balance = 0;
  String? errorMessage;
  Set<String> missingProductIds = <String>{};

  List<ProductDetails> get products => List.unmodifiable(_products);

  Future<void> initialize() async {
    _subscription ??= _store.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: _handleStreamError,
    );

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      isStoreAvailable = await _store.isAvailable();

      if (!isStoreAvailable) {
        throw StateError('App Store or Google Play is unavailable');
      }

      await Future.wait(<Future<void>>[
        loadProducts(),
        Future<void>.sync(_refreshBalance),
      ]);
    } catch (error) {
      errorMessage = _messageFrom(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProducts() async {
    final response = await _store.queryProductDetails(productIds);

    if (response.error != null) {
      throw StateError(response.error!.message);
    }

    _products = response.productDetails.toList()
      ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

    missingProductIds = response.notFoundIDs.toSet();
    notifyListeners();
  }

  ProductDetails? productById(String productId) {
    for (final product in _products) {
      if (product.id == productId) {
        return product;
      }
    }

    return null;
  }

  Future<void> purchase(String productId) async {
    if (!isStoreAvailable) {
      throw StateError('App Store or Google Play is unavailable');
    }

    if (isPurchasing) {
      throw StateError('Another purchase is already in progress');
    }

    final product = productById(productId);

    if (product == null) {
      throw StateError('Product $productId was not found');
    }

    isPurchasing = true;
    errorMessage = null;
    notifyListeners();

    try {
      final started = await _store.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
        autoConsume: Platform.isIOS,
      );

      if (!started) {
        throw StateError('The purchase could not be started');
      }
    } catch (error) {
      isPurchasing = false;
      errorMessage = _messageFrom(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> recoverPurchases() async {
    errorMessage = null;
    notifyListeners();

    try {
      await _store.restorePurchases();
      await Future<void>.sync(_refreshBalance);
    } catch (error) {
      errorMessage = _messageFrom(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        isPurchasing = true;
        errorMessage = null;
        notifyListeners();
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        isPurchasing = false;
        errorMessage = purchase.error?.message ?? 'Purchase failed';
        notifyListeners();
        continue;
      }

      if (purchase.status == PurchaseStatus.canceled) {
        isPurchasing = false;
        errorMessage = null;
        notifyListeners();
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _verifyAndCredit(purchase);
      }
    }
  }

  Future<void> _verifyAndCredit(PurchaseDetails purchase) async {
    final proof = purchase.verificationData.serverVerificationData;
    final key = purchase.purchaseID ?? proof;

    if (!_processing.add(key)) {
      return;
    }

    try {
      final premiumService = await ref.read(premiumApiServiceProvider.future);
      final response = await premiumService.verifyAndCredit(purchase);

      final data = response.data;
      final value = data?['balance'];

      if (data?['success'] != true || value is! num) {
        throw StateError('The store purchase could not be verified');
      }

      balance = value.toDouble();

      if (Platform.isIOS && purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }

      isPurchasing = false;
      errorMessage = null;
      notifyListeners();
    } catch (error) {
      isPurchasing = false;
      errorMessage = _messageFrom(error);
      notifyListeners();
    } finally {
      _processing.remove(key);
    }
  }

  void _handleStreamError(Object error) {
    isPurchasing = false;
    errorMessage = _messageFrom(error);
    notifyListeners();
  }

  String _messageFrom(Object error) {
    if (error is DioException) {
      final data = error.response?.data;

      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }

      return error.message ?? 'Network request failed';
    }

    return error.toString().replaceFirst('Bad state: ', '');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
