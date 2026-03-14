/// Custom exceptions for ad-related errors
/// Provides structured error handling and detailed debugging information

/// Base exception for all ad-related errors
class AdException implements Exception {
  final String message;
  final String? code;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? details;

  AdException(
    this.message, {
    this.code,
    this.stackTrace,
    this.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('AdException: $message');
    if (code != null) buffer.write(' (Code: $code)');
    if (details != null && details!.isNotEmpty) {
      buffer.write('\nDetails: $details');
    }
    return buffer.toString();
  }

  /// Get user-friendly error message
  String getUserMessage() {
    return message;
  }

  /// Check if error is recoverable (retry makes sense)
  bool get isRecoverable => true;
}

/// Network-related ad loading errors
class AdNetworkException extends AdException {
  AdNetworkException(
    super.message, {
    super.code,
    super.stackTrace,
    super.details,
  });

  @override
  String getUserMessage() {
    return 'Network error - check your internet connection';
  }

  @override
  bool get isRecoverable => true;
}

/// Ad load failed due to no inventory
class AdNoFillException extends AdException {
  AdNoFillException(
    super.message, {
    super.code,
    super.stackTrace,
    super.details,
  });

  @override
  String getUserMessage() {
    return 'No ads available - will retry shortly';
  }

  @override
  bool get isRecoverable => true;
}

/// Invalid ad configuration or request
class AdInvalidRequestException extends AdException {
  AdInvalidRequestException(
    super.message, {
    super.code,
    super.stackTrace,
    super.details,
  });

  @override
  String getUserMessage() {
    return 'Ad configuration error - check settings';
  }

  @override
  bool get isRecoverable => false; // Configuration errors need code fix
}

/// SDK internal errors
class AdInternalException extends AdException {
  AdInternalException(
    super.message, {
    super.code,
    super.stackTrace,
    super.details,
  });

  @override
  String getUserMessage() {
    return 'Internal ad system error - will retry automatically';
  }

  @override
  bool get isRecoverable => true;
}

/// Rate limit exceeded
class AdRateLimitException extends AdException {
  final Duration waitTime;

  AdRateLimitException(
    super.message, {
    required this.waitTime,
    super.code,
    super.stackTrace,
    super.details,
  });

  @override
  String getUserMessage() {
    final seconds = waitTime.inSeconds;
    return 'Too many ad requests - wait ${seconds}s';
  }

  @override
  bool get isRecoverable => false; // Can't retry immediately
}

/// Circuit breaker is open (too many failures)
class AdCircuitBreakerException extends AdException {
  final DateTime resetTime;

  AdCircuitBreakerException(
    super.message, {
    required this.resetTime,
    super.code,
    super.stackTrace,
    super.details,
  });

  @override
  String getUserMessage() {
    final now = DateTime.now();
    final remaining = resetTime.difference(now);
    if (remaining.isNegative) return 'Ad system recovering';
    return 'Ad system temporarily unavailable (${remaining.inSeconds}s)';
  }

  @override
  bool get isRecoverable => false;
}

/// Factory to create appropriate exception from error code
class AdExceptionFactory {
  static AdException fromErrorCode(
    int errorCode,
    String message, {
    StackTrace? stackTrace,
    Map<String, dynamic>? details,
  }) {
    final code = errorCode.toString();

    switch (errorCode) {
      case 0:
        return AdInternalException(
          message,
          code: code,
          stackTrace: stackTrace,
          details: details,
        );
      case 1:
        return AdInvalidRequestException(
          message,
          code: code,
          stackTrace: stackTrace,
          details: details,
        );
      case 2:
        return AdNetworkException(
          message,
          code: code,
          stackTrace: stackTrace,
          details: details,
        );
      case 3:
        return AdNoFillException(
          message,
          code: code,
          stackTrace: stackTrace,
          details: details,
        );
      default:
        return AdException(
          message,
          code: code,
          stackTrace: stackTrace,
          details: details,
        );
    }
  }
}
