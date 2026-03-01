import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:defyx_vpn/modules/core/network.dart';
import 'package:defyx_vpn/shared/exceptions/ad_exceptions.dart';
import 'package:defyx_vpn/shared/services/ad_cache_service.dart';
import 'package:defyx_vpn/shared/services/ad_performance_metrics.dart';
import 'package:defyx_vpn/shared/services/firebase_analytics_service.dart';
import 'package:defyx_vpn/shared/utils/circuit_breaker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Configuration for ad retry strategy
class AdRetryConfig {
  final int maxAttempts;
  final Duration baseDelay;
  final double backoffMultiplier;
  final Duration maxDelay;

  const AdRetryConfig({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 2),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
  });

  /// Calculate delay for given attempt with exponential backoff and jitter
  Duration getDelay(int attempt) {
    if (attempt <= 0) return Duration.zero;
    
    // Exponential backoff: baseDelay * (multiplier ^ attempt)
    final exponentialDelay = baseDelay.inMilliseconds * 
        pow(backoffMultiplier, attempt - 1).toInt();
    
    // Cap at max delay
    final cappedDelay = min(exponentialDelay, maxDelay.inMilliseconds);
    
    // Add jitter (0-1000ms) to prevent thundering herd
    final jitter = Random().nextInt(1000);
    
    return Duration(milliseconds: cappedDelay + jitter);
  }
}

/// Result of ad load attempt
class AdLoadResult {
  final bool success;
  final String? errorCode;
  final String? errorMessage;
  final int attemptCount;
  final Duration loadDuration;

  const AdLoadResult({
    required this.success,
    this.errorCode,
    this.errorMessage,
    required this.attemptCount,
    required this.loadDuration,
  });

  String get errorSolution {
    if (errorCode == null) return '';
    switch (errorCode) {
      case '0':
        return 'Internal SDK error - will retry automatically';
      case '1':
        return 'Invalid ad request - check Ad Unit ID configuration';
      case '2':
        return 'Network error - check internet connection';
      case '3':
        return 'No ad inventory available - normal, will retry';
      default:
        return 'Unknown error - check logs for details';
    }
  }
}

/// Interface for Ad Service
abstract interface class IAdService {
  /// Check if ad can be loaded (network connectivity)
  Future<bool> canLoadAd();
  
  /// Load ad with retry logic
  Future<AdLoadResult> loadAdWithRetry({
    required String adUnitId,
    required NativeAdListener listener,
    required NativeTemplateStyle templateStyle,
    int? maxRetries,
  });
  
  /// Log ad event to analytics
  Future<void> logAdEvent(String eventName, Map<String, dynamic> parameters);
  
  /// Check rate limiting
  bool canMakeRequest();
  
  /// Get circuit breaker status
  Map<String, dynamic> getCircuitBreakerStatus();
  
  /// Get ad cache statistics
  Future<Map<String, dynamic>> getCacheStats();
  
  /// Reset circuit breaker (manual override)
  void resetCircuitBreaker();
  
  /// Set performance service for metrics tracking
  void setPerformanceService(AdPerformanceService? service);
  
  /// Get performance summary (debug)
  String getPerformanceSummary();
}

/// Implementation of Ad Service
class AdService implements IAdService {
  final AdCacheService? _cacheService;
  AdPerformanceService? _performanceService;
  
  AdService._internal([this._cacheService]);
  static AdService? _instance;
  factory AdService([AdCacheService? cacheService]) {
    _instance ??= AdService._internal(cacheService);
    return _instance!;
  }

  final AdRetryConfig _retryConfig = const AdRetryConfig();
  final FirebaseAnalyticsService _analytics = FirebaseAnalyticsService();
  final NetworkStatus _network = NetworkStatus();
  final CircuitBreaker _circuitBreaker = CircuitBreaker(
    config: const CircuitBreakerConfig(
      failureThreshold: 5,
      resetTimeout: Duration(minutes: 2),
      successThreshold: 2,
    ),
  );
  
  DateTime? _lastAdRequest;
  final List<DateTime> _recentRequests = [];
  static const int _maxRequestsPerMinute = 2;
  static const Duration _minRequestInterval = Duration(seconds: 60);
  
  @override
  void setPerformanceService(AdPerformanceService? service) {
    _performanceService = service;
    debugPrint('📊 Performance service ${service != null ? "enabled" : "disabled"}');
  }
  
  @override
  String getPerformanceSummary() {
    return _performanceService?.getPerformanceSummary() ?? 'Performance tracking disabled';
  }

  bool get _isMobilePlatform {
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  Future<bool> canLoadAd() async {
    if (!_isMobilePlatform) {
      debugPrint('📱 Ad load skipped - not mobile platform');
      return false;
    }

    try {
      // Check basic connectivity
      final hasConnectivity = await _network.checkConnectivity();
      if (!hasConnectivity) {
        debugPrint('🔴 No network connectivity');
        await logAdEvent('ad_network_unavailable', {});
        return false;
      }

      debugPrint('✅ Network connectivity available');
      return true;
    } catch (e) {
      debugPrint('❌ Error checking network: $e');
      return false;
    }
  }

  @override
  bool canMakeRequest() {
    final now = DateTime.now();
    
    // Check circuit breaker first
    if (!_circuitBreaker.isCallAllowed) {
      final resetTime = _circuitBreaker.resetTime;
      debugPrint('🚨 Circuit breaker is open - resets at ${resetTime?.toIso8601String()}');
      throw AdCircuitBreakerException(
        'Too many consecutive failures',
        resetTime: resetTime ?? now.add(const Duration(minutes: 2)),
      );
    }
    
    // Check minimum interval since last request (60s)
    if (_lastAdRequest != null) {
      final timeSinceLastRequest = now.difference(_lastAdRequest!);
      if (timeSinceLastRequest < _minRequestInterval) {
        debugPrint('⏱️ Rate limit: only ${timeSinceLastRequest.inSeconds}s since last request (need 60s)');
        final waitTime = _minRequestInterval - timeSinceLastRequest;
        throw AdRateLimitException(
          'Rate limit exceeded',
          waitTime: waitTime,
        );
      }
    }
    
    // Check requests per minute (max 2)
    _recentRequests.removeWhere((time) => 
      now.difference(time) > const Duration(minutes: 1));
    
    if (_recentRequests.length >= _maxRequestsPerMinute) {
      debugPrint('⏱️ Rate limit: ${_recentRequests.length} requests in last minute (max $_maxRequestsPerMinute)');
      throw AdRateLimitException(
        'Too many requests per minute',
        waitTime: const Duration(seconds: 30),
      );
    }
    
    return true;
  }
  
  @override
  Map<String, dynamic> getCircuitBreakerStatus() {
    return _circuitBreaker.getStatus();
  }
  
  @override
  Future<Map<String, dynamic>> getCacheStats() async {
    if (_cacheService == null) {
      return {'enabled': false};
    }
    return await _cacheService.getStats();
  }
  
  @override
  void resetCircuitBreaker() {
    _circuitBreaker.reset();
  }

  @override
  Future<AdLoadResult> loadAdWithRetry({
    required String adUnitId,
    required NativeAdListener listener,
    required NativeTemplateStyle templateStyle,
    int? maxRetries,
  }) async {
    final maxAttempts = maxRetries ?? _retryConfig.maxAttempts;
    final startTime = DateTime.now();
    
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      debugPrint('🔄 Ad load attempt $attempt/$maxAttempts');
      
      // Track load attempt
      _performanceService?.recordLoadAttempt();
      
      // Check network before each attempt
      final canLoad = await canLoadAd();
      if (!canLoad) {
        await logAdEvent('ad_load_attempt_failed', {
          'attempt': attempt,
          'reason': 'network_unavailable',
        });
        
        if (attempt < maxAttempts) {
          final delay = _retryConfig.getDelay(attempt);
          debugPrint('⏳ Waiting ${delay.inSeconds}s before retry...');
          await Future.delayed(delay);
          continue;
        } else {
          final duration = DateTime.now().difference(startTime);
          return AdLoadResult(
            success: false,
            errorCode: '2',
            errorMessage: 'Network unavailable after $maxAttempts attempts',
            attemptCount: attempt,
            loadDuration: duration,
          );
        }
      }
      
      // Check rate limiting and circuit breaker
      try {
        canMakeRequest();
      } on AdRateLimitException catch (e) {
        _performanceService?.recordRateLimitHit();
        
        await logAdEvent('ad_load_attempt_failed', {
          'attempt': attempt,
          'reason': 'rate_limited',
        });
        
        if (attempt < maxAttempts) {
          await Future.delayed(e.waitTime);
          continue;
        } else {
          final duration = DateTime.now().difference(startTime);
          return AdLoadResult(
            success: false,
            errorCode: '1',
            errorMessage: e.message,
            attemptCount: attempt,
            loadDuration: duration,
          );
        }
      } on AdCircuitBreakerException catch (e) {
        _performanceService?.recordCircuitBreakerTrip();
        
        await logAdEvent('ad_load_attempt_failed', {
          'attempt': attempt,
          'reason': 'circuit_breaker_open',
        });
        
        final duration = DateTime.now().difference(startTime);
        return AdLoadResult(
          success: false,
          errorCode: 'CB',
          errorMessage: e.message,
          attemptCount: attempt,
          loadDuration: duration,
        );
      }
      
      // Log attempt
      await logAdEvent('ad_load_attempt', {'attempt': attempt});
      
      // Track request
      final now = DateTime.now();
      _lastAdRequest = now;
      _recentRequests.add(now);
      
      // Create completer for async ad load
      final completer = Completer<AdLoadResult>();
      
      // Create ad with modified listener
      final ad = NativeAd(
        adUnitId: adUnitId,
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            final duration = DateTime.now().difference(startTime);
            debugPrint('✅ Ad loaded successfully in ${duration.inMilliseconds}ms');
            
            // Record success for circuit breaker
            _circuitBreaker.onSuccess();
            
            // Record success for performance metrics
            _performanceService?.recordLoadSuccess(duration);
            
            logAdEvent('ad_load_success', {
              'attempt': attempt,
              'duration_ms': duration.inMilliseconds,
            });
            
            // Cache ad metadata
            if (_cacheService != null) {
              _cacheService.saveMetadata(AdMetadata(
                adUnitId: adUnitId,
                loadedAt: DateTime.now(),
                loadAttempts: attempt,
              ));
            }
            
            if (!completer.isCompleted) {
              completer.complete(AdLoadResult(
                success: true,
                attemptCount: attempt,
                loadDuration: duration,
              ));
            }
            
            // Call original listener
            listener.onAdLoaded?.call(ad);
          },
          onAdFailedToLoad: (ad, error) {
            final duration = DateTime.now().difference(startTime);
            debugPrint('❌ Ad failed to load: ${error.code} - ${error.message}');
            
            // Record failure for circuit breaker
            _circuitBreaker.onFailure();
            
            // Record failure for performance metrics
            _performanceService?.recordLoadFailure(error.code.toString());
            
            logAdEvent('ad_load_failure', {
              'attempt': attempt,
              'error_code': error.code.toString(),
              'error_message': error.message,
              'duration_ms': duration.inMilliseconds,
              'circuit_breaker_state': _circuitBreaker.state.name,
            });
            
            // Cache error
            if (_cacheService != null) {
              _cacheService.recordError(
                error.code.toString(),
                error.message,
              );
            }
            
            if (!completer.isCompleted) {
              completer.complete(AdLoadResult(
                success: false,
                errorCode: error.code.toString(),
                errorMessage: error.message,
                attemptCount: attempt,
                loadDuration: duration,
              ));
            }
            
            // Call original listener
            listener.onAdFailedToLoad?.call(ad, error);
          },
          onAdClicked: (ad) {
            _performanceService?.recordClick();
            listener.onAdClicked?.call(ad);
          },
          onAdImpression: (ad) {
            _performanceService?.recordImpression();
            
            logAdEvent('ad_impression', {});
            
            // Record impression in cache
            if (_cacheService != null) {
              _cacheService.recordImpression();
            }
            
            listener.onAdImpression?.call(ad);
          },
        ),
        request: const AdRequest(),
        nativeTemplateStyle: templateStyle,
      );
      
      // Load ad
      ad.load();
      
      // Wait for result
      final result = await completer.future;
      
      if (result.success) {
        return result;
      }
      
      // If failed and not last attempt, wait and retry
      if (attempt < maxAttempts) {
        final delay = _retryConfig.getDelay(attempt);
        debugPrint('⏳ Waiting ${delay.inSeconds}s before retry (attempt ${attempt + 1}/$maxAttempts)...');
        await Future.delayed(delay);
      } else {
        return result;
      }
    }
    
    // Should never reach here
    final duration = DateTime.now().difference(startTime);
    return AdLoadResult(
      success: false,
      errorCode: '0',
      errorMessage: 'Unknown error after $maxAttempts attempts',
      attemptCount: maxAttempts,
      loadDuration: duration,
    );
  }

  @override
  Future<void> logAdEvent(String eventName, Map<String, dynamic> parameters) async {
    try {
      await _analytics.logEvent(
        name: 'ad_$eventName',
        parameters: parameters.map((key, value) => MapEntry(key, value.toString())),
      );
    } catch (e) {
      debugPrint('Analytics error logging ad event: $e');
    }
  }
}

/// Provider for Ad Service
final adServiceProvider = Provider<IAdService>((ref) {
  final cacheService = ref.watch(adCacheServiceProvider);
  final adService = AdService(cacheService);
  
  // Inject performance service (watch to get StateNotifier instance)
  final performanceNotifier = ref.read(adPerformanceServiceProvider.notifier);
  adService.setPerformanceService(performanceNotifier);
  
  return adService;
});
