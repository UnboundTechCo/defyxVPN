import 'dart:async';
import 'dart:io';

import 'package:defyx_vpn/core/premium/api_premium.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:defyx_vpn/shared/services/crash_reporting_service.dart';

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
  late String _correlationId;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = <ProductDetails>[];

  bool isStoreAvailable = false;
  bool isLoading = false;
  bool isPurchasing = false;
  double balance = 0;
  String? errorMessage;
  Set<String> missingProductIds = <String>{};
  Completer<void>? _purchaseCompletion;

  List<ProductDetails> get products => List.unmodifiable(_products);

  Future<void> initialize() async {
    _correlationId = DateTime.now()
        .toUtc()
        .microsecondsSinceEpoch
        .toRadixString(16);
    _subscription ??= _store.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: _handleStreamError,
    );

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _logStage('store_availability', outcome: 'started');
      isStoreAvailable = await _store.isAvailable();
      _logStage(
        'store_availability',
        outcome: isStoreAvailable ? 'available' : 'unavailable',
      );

      if (!isStoreAvailable) {
        throw StateError('App Store or Google Play is unavailable');
      }

      await Future.wait(<Future<void>>[
        _loadProducts(),
        _recoverGooglePlayPurchases().then((_) => _refreshBalance()),
      ]);
    } catch (error) {
      _logStage('initialization', error: error);
      errorMessage = _messageFrom(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadProducts() async {
    _logStage('product_query', outcome: 'started ids=${productIds.join(',')}');
    final response = await _store.queryProductDetails(productIds);

    if (response.error != null) {
      _logStage('product_query', error: response.error);
      throw StateError(response.error!.message);
    }

    _products = response.productDetails.toList()
      ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

    missingProductIds = response.notFoundIDs.toSet();
    _logStage(
      'product_query',
      outcome:
          'success returned=${_products.length} not_found=${missingProductIds.join(',')}',
    );
    notifyListeners();
  }

  /// Credits Google Play purchases that were paid for but never credited, such
  /// as when the app closed before verification. The backend consumes a
  /// purchase once it credits it, so one still held here was not credited, and
  /// Play will not sell that product again until it is consumed.
  Future<void> _recoverGooglePlayPurchases() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final response = await _store
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .queryPastPurchases();

      if (response.error != null) {
        _logStage('purchase_recovery', error: response.error);
        return;
      }

      for (final purchase in response.pastPurchases) {
        if (purchase.status != PurchaseStatus.purchased ||
            !productIds.contains(purchase.productID)) {
          continue;
        }

        final key = _purchaseKey(purchase);
        if (!_processing.add(key)) {
          continue;
        }

        try {
          _logStage(
            'purchase_recovery',
            productId: purchase.productID,
            outcome: 'started',
          );
          await _creditOnBackend(purchase);
          _logStage(
            'purchase_recovery',
            productId: purchase.productID,
            outcome: 'credited',
          );
        } catch (error) {
          _logStage(
            'purchase_recovery',
            productId: purchase.productID,
            error: error,
          );
        } finally {
          _processing.remove(key);
        }
      }
    } catch (error) {
      _logStage('purchase_recovery', error: error);
    }
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
    final completion = Completer<void>();
    _purchaseCompletion = completion;
    _logStage('purchase_request', productId: productId, outcome: 'started');
    notifyListeners();

    try {
      final started = await _store.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
        // StoreKit requires true. On Google Play the backend consumes the
        // purchase once it credits it, and refuses one the app consumed.
        autoConsume: Platform.isIOS || Platform.isMacOS,
      );

      if (!started) {
        throw StateError('The purchase could not be started');
      }
      _logStage('purchase_request', productId: productId, outcome: 'accepted');

      await completion.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () =>
            throw TimeoutException('The purchase verification timed out'),
      );
    } catch (error) {
      _logStage('purchase_request', productId: productId, error: error);
      isPurchasing = false;
      errorMessage = _messageFrom(error);
      notifyListeners();
      rethrow;
    } finally {
      if (identical(_purchaseCompletion, completion)) {
        _purchaseCompletion = null;
      }
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
        _logStage(
          'purchase_stream',
          productId: purchase.productID,
          outcome: 'pending',
        );
        isPurchasing = true;
        errorMessage = null;
        notifyListeners();
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        _logStage(
          'purchase_stream',
          productId: purchase.productID,
          outcome: 'error',
          error: purchase.error,
        );
        isPurchasing = false;
        errorMessage = purchase.error?.message ?? 'Purchase failed';
        _completePurchaseWithError(StateError(errorMessage!));
        notifyListeners();
        continue;
      }

      if (purchase.status == PurchaseStatus.canceled) {
        _logStage(
          'purchase_stream',
          productId: purchase.productID,
          outcome: 'canceled',
        );
        isPurchasing = false;
        errorMessage = 'Purchase canceled';
        _completePurchaseWithError(StateError(errorMessage!));
        notifyListeners();
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _logStage(
          'purchase_stream',
          productId: purchase.productID,
          outcome: purchase.status.name,
        );
        await _verifyAndCredit(purchase);
      }
    }
  }

  String _purchaseKey(PurchaseDetails purchase) =>
      purchase.purchaseID ?? purchase.verificationData.serverVerificationData;

  /// Has the backend verify [purchase] and credit the balance, then updates
  /// [balance]. For Google Play the backend also consumes the purchase.
  Future<void> _creditOnBackend(PurchaseDetails purchase) async {
    final premiumService = await ref.read(premiumApiServiceProvider.future);
    final response = await premiumService.verifyAndCredit(purchase);

    final data = response.data;
    final value = data?['balance'];
    final verified = data?['success'] == true && value is num;
    _logStage(
      'backend_verification_response',
      productId: purchase.productID,
      outcome: 'http=${response.statusCode} verified=$verified',
    );

    if (!verified) {
      throw StateError('The store purchase could not be verified');
    }

    balance = value.toDouble();
  }

  Future<void> _verifyAndCredit(PurchaseDetails purchase) async {
    final key = _purchaseKey(purchase);

    if (!_processing.add(key)) {
      return;
    }

    var failureStage = 'backend_verification';
    try {
      _logStage(
        'backend_verification',
        productId: purchase.productID,
        outcome: 'started',
      );
      await _creditOnBackend(purchase);
      _logStage(
        'backend_verification',
        productId: purchase.productID,
        outcome: 'verified',
      );

      // Consuming a Google Play purchase acknowledges it, and the backend did
      // that while crediting, so only StoreKit transactions are finished here.
      if (purchase.pendingCompletePurchase && !Platform.isAndroid) {
        failureStage = 'transaction_completion';
        _logStage(
          failureStage,
          productId: purchase.productID,
          outcome: 'started',
        );
        await _store.completePurchase(purchase);
        _logStage(
          'transaction_completion',
          productId: purchase.productID,
          outcome: 'completed',
        );
      }

      isPurchasing = false;
      errorMessage = null;
      _purchaseCompletion?.complete();
      notifyListeners();
    } catch (error) {
      _logStage(failureStage, productId: purchase.productID, error: error);
      isPurchasing = false;
      errorMessage = _messageFrom(error);
      _completePurchaseWithError(error);
      notifyListeners();
    } finally {
      _processing.remove(key);
    }
  }

  void _handleStreamError(Object error) {
    _logStage('purchase_stream', outcome: 'stream_error', error: error);
    isPurchasing = false;
    errorMessage = _messageFrom(error);
    _completePurchaseWithError(error);
    notifyListeners();
  }

  void _completePurchaseWithError(Object error) {
    final completion = _purchaseCompletion;
    if (completion != null && !completion.isCompleted) {
      completion.completeError(error);
    }
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

  void _logStage(
    String stage, {
    String? productId,
    Object? error,
    String? outcome,
  }) {
    unawaited(_writeDiagnostic(stage, productId, error, outcome));
  }

  Future<void> _writeDiagnostic(
    String stage,
    String? productId,
    Object? error,
    String? outcome,
  ) async {
    var appVersion = 'unknown';
    var buildNumber = 'unknown';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
    } catch (_) {}

    final fields = <String>[
      'correlation_id=$_correlationId',
      'stage=$stage',
      'app_version=$appVersion',
      'build=$buildNumber',
      'os=${Platform.operatingSystem}',
      'os_version="${Platform.operatingSystemVersion}"',
      if (productId != null) 'product_id=$productId',
      if (outcome != null) 'outcome="$outcome"',
    ];

    if (error is IAPError) {
      fields.addAll(<String>[
        'error_source=${error.source}',
        'error_code=${error.code}',
        'error_message="${error.message}"',
        if (error.details != null) 'error_details="${error.details}"',
      ]);
    } else if (error is PlatformException) {
      fields.addAll(<String>[
        'error_code=${error.code}',
        if (error.message != null) 'error_message="${error.message}"',
        if (error.details != null) 'error_details="${error.details}"',
      ]);
    } else if (error is DioException) {
      fields.addAll(<String>[
        'backend_http_status=${error.response?.statusCode ?? 'none'}',
        'error_type=${error.type.name}',
      ]);
    } else if (error != null) {
      fields.add('error_type=${error.runtimeType}');
    }

    final message = '[IAP] ${fields.join(' ')}';
    final crashReporting = CrashReportingService();
    await crashReporting.log(message);
    if (error != null) {
      await crashReporting.recordError(
        StateError('IAP stage failed: $stage'),
        StackTrace.current,
        reason: message,
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
