import 'dart:io';

import 'package:defyx_vpn/common/dtos/balance_dto.dart';
import 'package:defyx_vpn/common/dtos/plans_dto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Provider for the Telegram API service
final premiumApiServiceProvider =
    AsyncNotifierProvider<PremiumApiServiceNotifier, PremiumApiService>(
      PremiumApiServiceNotifier.new,
    );

/// Notifier that manages the PremiumApiService instance
class PremiumApiServiceNotifier extends AsyncNotifier<PremiumApiService> {
  @override
  Future<PremiumApiService> build() async {
    final storage = ref.read(secureStorageProvider);
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final token = await storage.read(premiumTokenKey);

    return PremiumApiService(baseUrl: baseUrl, token: token);
  }
}

/// Premium backend API service using Dio
class PremiumApiService {
  static const accountDeletionPath = '/customer/delete/';

  late final Dio _dio;
  final String baseUrl;
  final String? token;

  PremiumApiService({required this.baseUrl, this.token}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (token != null && token!.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    );

    _setupInterceptors();
  }

  /// Setup interceptors for error handling
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          // Handle 401 - token expired
          // This can be handled at the calling layer
          return handler.next(error);
        },
      ),
    );
  }

  /// Get user balance
  Future<BalanceResponse> getBalance() async {
    try {
      final response = await _dio.get('/customer/telegram-balance/');
      return BalanceResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get available VPN configs
  Future<List<PlansResponse>> getConfigs() async {
    try {
      final response = await _dio.get('/subscription-plan/featured');
      final data = response.data["data"];

      if (data is List) {
        return data
            .map((item) => PlansResponse.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> subscribeToPlan(int planId) async {
    try {
      final response = await _dio.post(
        '/subscription/subscribe-app-with-balance/',
        data: {'subscription_plan_id': planId},
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to subscribe to the plan.');
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _dio.post("/customer/delete-account");
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response<Map<String, dynamic>>> verifyAndCredit(
    PurchaseDetails purchase,
  ) async {
    final proof = purchase.verificationData.serverVerificationData;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/iap/verify',
        data: <String, dynamic>{
          'platform': Platform.isIOS ? 'ios' : 'android',
          'product_id': purchase.productID,
          'verification_data': proof,
        },
      );

      return response;
    } catch (error) {
      rethrow;
    }
  }

  Exception _handleError(DioException error) {
    if (error.response?.statusCode == 401) {
      return Exception('Token expired. Please log in again.');
    } else if (error.response?.statusCode == 404) {
      return Exception('Resource not found.');
    } else if (error.response?.statusCode == 500) {
    } else if (error.response?.statusCode == 403) {
      return Exception(error.response?.data['message'] ?? 'Access denied.');
    } else if (error.response?.statusCode == 500) {
      return Exception('Server error. Please try again later.');
    } else if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return Exception('Connection timeout. Please check your connection.');
    } else if (error.type == DioExceptionType.connectionError) {
      return Exception('Connection error. Please check your network.');
    }
    return Exception('An error occurred: ${error.response}');
  }
}
