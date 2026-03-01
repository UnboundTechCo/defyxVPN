import 'package:flutter/foundation.dart';

/// Circuit breaker states
enum CircuitBreakerState {
  closed, // Normal operation
  open, // Too many failures, blocking requests
  halfOpen, // Testing if service recovered
}

/// Configuration for circuit breaker
class CircuitBreakerConfig {
  /// Number of consecutive failures before opening circuit
  final int failureThreshold;

  /// Time to wait before trying again (half-open state)
  final Duration resetTimeout;

  /// Number of successful calls to close circuit from half-open
  final int successThreshold;

  const CircuitBreakerConfig({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(minutes: 2),
    this.successThreshold = 2,
  });
}

/// Circuit breaker implementation to prevent cascading failures
class CircuitBreaker {
  final CircuitBreakerConfig config;

  CircuitBreakerState _state = CircuitBreakerState.closed;
  int _failureCount = 0;
  int _successCount = 0;
  DateTime? _openedAt;

  CircuitBreaker({
    CircuitBreakerConfig? config,
  }) : config = config ?? const CircuitBreakerConfig();

  /// Current state of the circuit breaker
  CircuitBreakerState get state => _state;

  /// Number of consecutive failures
  int get failureCount => _failureCount;

  /// Time when circuit was opened (if open)
  DateTime? get openedAt => _openedAt;

  /// Time when circuit will try to recover
  DateTime? get resetTime {
    if (_openedAt == null) return null;
    return _openedAt!.add(config.resetTimeout);
  }

  /// Check if operation is allowed
  bool get isCallAllowed {
    switch (_state) {
      case CircuitBreakerState.closed:
        return true;

      case CircuitBreakerState.open:
        // Check if timeout elapsed, transition to half-open
        if (_shouldAttemptReset()) {
          _transitionToHalfOpen();
          return true;
        }
        return false;

      case CircuitBreakerState.halfOpen:
        return true;
    }
  }

  /// Execute operation with circuit breaker protection
  Future<T> execute<T>(Future<T> Function() operation) async {
    if (!isCallAllowed) {
      throw Exception(
        'Circuit breaker is open. Reset at: ${resetTime?.toIso8601String()}',
      );
    }

    try {
      final result = await operation();
      onSuccess();
      return result;
    } catch (e) {
      onFailure();
      rethrow;
    }
  }

  /// Record successful operation
  void onSuccess() {
    switch (_state) {
      case CircuitBreakerState.closed:
        _failureCount = 0;
        break;

      case CircuitBreakerState.halfOpen:
        _successCount++;
        debugPrint(
          '🔄 Circuit breaker half-open: $_successCount/${config.successThreshold} successes',
        );
        if (_successCount >= config.successThreshold) {
          _transitionToClosed();
        }
        break;

      case CircuitBreakerState.open:
        // Should not happen, but handle gracefully
        _transitionToHalfOpen();
        break;
    }
  }

  /// Record failed operation
  void onFailure() {
    switch (_state) {
      case CircuitBreakerState.closed:
        _failureCount++;
        debugPrint(
          '⚠️ Circuit breaker failure: $_failureCount/${config.failureThreshold}',
        );
        if (_failureCount >= config.failureThreshold) {
          _transitionToOpen();
        }
        break;

      case CircuitBreakerState.halfOpen:
        // Failed during test, back to open
        debugPrint('❌ Circuit breaker test failed, reopening');
        _transitionToOpen();
        break;

      case CircuitBreakerState.open:
        // Already open, just track
        _failureCount++;
        break;
    }
  }

  /// Check if enough time has passed to attempt reset
  bool _shouldAttemptReset() {
    if (_openedAt == null) return false;
    final elapsed = DateTime.now().difference(_openedAt!);
    return elapsed >= config.resetTimeout;
  }

  /// Transition to closed state
  void _transitionToClosed() {
    debugPrint('✅ Circuit breaker closed - normal operation');
    _state = CircuitBreakerState.closed;
    _failureCount = 0;
    _successCount = 0;
    _openedAt = null;
  }

  /// Transition to open state
  void _transitionToOpen() {
    debugPrint(
      '🚨 Circuit breaker OPEN - blocking requests for ${config.resetTimeout.inSeconds}s',
    );
    _state = CircuitBreakerState.open;
    _openedAt = DateTime.now();
    _successCount = 0;
  }

  /// Transition to half-open state
  void _transitionToHalfOpen() {
    debugPrint('🔄 Circuit breaker half-open - testing recovery');
    _state = CircuitBreakerState.halfOpen;
    _successCount = 0;
  }

  /// Reset circuit breaker to closed state (manual override)
  void reset() {
    debugPrint('🔧 Circuit breaker manually reset');
    _transitionToClosed();
  }

  /// Get status information
  Map<String, dynamic> getStatus() {
    return {
      'state': _state.name,
      'failureCount': _failureCount,
      'successCount': _successCount,
      'openedAt': _openedAt?.toIso8601String(),
      'resetTime': resetTime?.toIso8601String(),
      'isCallAllowed': isCallAllowed,
    };
  }
}
