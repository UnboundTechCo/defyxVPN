import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'http_client_interface.dart';

/// Provider for the HTTP client instance
final httpClientProvider = Provider<IHttpClient>((ref) {
  return HttpClient();
});

/// HTTP client implementation using Dio
final class HttpClient implements IHttpClient {
  late final Dio _dio;

  HttpClient({
    String? baseUrl,
    Map<String, dynamic>? headers,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        headers: headers ?? _defaultHeaders,
        connectTimeout: connectTimeout ?? const Duration(seconds: 30),
        receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
        sendTimeout: sendTimeout ?? const Duration(seconds: 30),
        responseType: ResponseType.json,
        contentType: Headers.jsonContentType,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    _setupInterceptors();
  }

  /// Default headers for all requests
  static Map<String, dynamic> get _defaultHeaders => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  /// Setup interceptors for logging and error handling
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _logRequest(options);
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _logResponse(response);
          return handler.next(response);
        },
        onError: (error, handler) {
          _logError(error);
          return handler.next(error);
        },
      ),
    );
  }

  /// Log request details (only in debug mode)
  void _logRequest(RequestOptions options) {
    if (kDebugMode) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🌐 REQUEST [${options.method}] => ${options.uri}');
      debugPrint('Headers: ${options.headers}');
      if (options.data != null) {
        debugPrint('Body: ${options.data}');
      }
      if (options.queryParameters.isNotEmpty) {
        debugPrint('Query Parameters: ${options.queryParameters}');
      }
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  /// Log response details (only in debug mode)
  void _logResponse(Response response) {
    if (kDebugMode) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint(
          '✅ RESPONSE [${response.statusCode}] => ${response.requestOptions.uri}');
      debugPrint('Data: ${response.data}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  /// Log error details (only in debug mode)
  void _logError(DioException error) {
    if (kDebugMode) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint(
          '❌ ERROR [${error.response?.statusCode}] => ${error.requestOptions.uri}');
      debugPrint('Type: ${error.type}');
      debugPrint('Message: ${error.message}');
      if (error.response != null) {
        debugPrint('Response: ${error.response?.data}');
      }
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Response> download(
    String urlPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    Options? options,
  }) async {
    try {
      return await _dio.download(
        urlPath,
        savePath,
        onReceiveProgress: onReceiveProgress,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        deleteOnError: deleteOnError,
        lengthHeader: lengthHeader,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<bool> checkConnectivity() async {
    try {
      final response = await _dio.get(
        'https://www.google.com/generate_204',
        options: Options(
          responseType: ResponseType.bytes,
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          validateStatus: (status) => status == 204 || status == 200,
        ),
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Network connectivity check failed: $e');
      return false;
    }
  }

  /// Handle Dio errors and convert them to meaningful exceptions
  Exception _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return NetworkException(
            'Connection timeout. Please check your internet connection.');

      case DioExceptionType.sendTimeout:
        return NetworkException(
            'Send timeout. The request took too long to send.');

      case DioExceptionType.receiveTimeout:
        return NetworkException(
            'Receive timeout. The server took too long to respond.');

      case DioExceptionType.badResponse:
        return _handleBadResponse(error);

      case DioExceptionType.cancel:
        return NetworkException('Request was cancelled.');

      case DioExceptionType.connectionError:
        return NetworkException(
            'Connection error. Please check your internet connection.');

      case DioExceptionType.unknown:
        return NetworkException('An unknown error occurred: ${error.message}');

      default:
        return NetworkException('An unexpected error occurred.');
    }
  }

  /// Handle bad response errors (4xx, 5xx status codes)
  Exception _handleBadResponse(DioException error) {
    final statusCode = error.response?.statusCode;
    final message = error.response?.data?['message'] ?? error.message;

    switch (statusCode) {
      case 400:
        return BadRequestException('Bad request: $message');
      case 401:
        return UnauthorizedException('Unauthorized: $message');
      case 403:
        return ForbiddenException('Forbidden: $message');
      case 404:
        return NotFoundException('Not found: $message');
      case 500:
        return ServerException('Server error: $message');
      case 503:
        return ServerException('Service unavailable: $message');
      default:
        return NetworkException('HTTP Error $statusCode: $message');
    }
  }

  /// Get the underlying Dio instance for advanced usage
  Dio get dio => _dio;
}

/// Base exception for network errors
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => message;
}

/// Exception for 400 Bad Request
class BadRequestException extends NetworkException {
  BadRequestException(super.message);
}

/// Exception for 401 Unauthorized
class UnauthorizedException extends NetworkException {
  UnauthorizedException(super.message);
}

/// Exception for 403 Forbidden
class ForbiddenException extends NetworkException {
  ForbiddenException(super.message);
}

/// Exception for 404 Not Found
class NotFoundException extends NetworkException {
  NotFoundException(super.message);
}

/// Exception for 500+ Server Errors
class ServerException extends NetworkException {
  ServerException(super.message);
}
