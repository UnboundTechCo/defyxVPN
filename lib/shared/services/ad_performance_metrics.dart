import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Performance metrics for ad loading and display
class AdPerformanceMetrics {
  final int totalLoadAttempts;
  final int successfulLoads;
  final int failedLoads;
  final int totalImpressions;
  final int totalClicks;
  final Duration averageLoadDuration;
  final DateTime? lastLoadTime;
  final DateTime? lastImpressionTime;
  final Map<String, int> errorCodeCounts;
  final double fillRate;
  final double clickThroughRate;
  final int circuitBreakerTrips;
  final int rateLimitHits;

  const AdPerformanceMetrics({
    this.totalLoadAttempts = 0,
    this.successfulLoads = 0,
    this.failedLoads = 0,
    this.totalImpressions = 0,
    this.totalClicks = 0,
    this.averageLoadDuration = Duration.zero,
    this.lastLoadTime,
    this.lastImpressionTime,
    this.errorCodeCounts = const {},
    this.fillRate = 0.0,
    this.clickThroughRate = 0.0,
    this.circuitBreakerTrips = 0,
    this.rateLimitHits = 0,
  });

  AdPerformanceMetrics copyWith({
    int? totalLoadAttempts,
    int? successfulLoads,
    int? failedLoads,
    int? totalImpressions,
    int? totalClicks,
    Duration? averageLoadDuration,
    DateTime? lastLoadTime,
    DateTime? lastImpressionTime,
    Map<String, int>? errorCodeCounts,
    double? fillRate,
    double? clickThroughRate,
    int? circuitBreakerTrips,
    int? rateLimitHits,
  }) {
    return AdPerformanceMetrics(
      totalLoadAttempts: totalLoadAttempts ?? this.totalLoadAttempts,
      successfulLoads: successfulLoads ?? this.successfulLoads,
      failedLoads: failedLoads ?? this.failedLoads,
      totalImpressions: totalImpressions ?? this.totalImpressions,
      totalClicks: totalClicks ?? this.totalClicks,
      averageLoadDuration: averageLoadDuration ?? this.averageLoadDuration,
      lastLoadTime: lastLoadTime ?? this.lastLoadTime,
      lastImpressionTime: lastImpressionTime ?? this.lastImpressionTime,
      errorCodeCounts: errorCodeCounts ?? this.errorCodeCounts,
      fillRate: fillRate ?? this.fillRate,
      clickThroughRate: clickThroughRate ?? this.clickThroughRate,
      circuitBreakerTrips: circuitBreakerTrips ?? this.circuitBreakerTrips,
      rateLimitHits: rateLimitHits ?? this.rateLimitHits,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalLoadAttempts': totalLoadAttempts,
      'successfulLoads': successfulLoads,
      'failedLoads': failedLoads,
      'totalImpressions': totalImpressions,
      'totalClicks': totalClicks,
      'averageLoadDurationMs': averageLoadDuration.inMilliseconds,
      'lastLoadTime': lastLoadTime?.toIso8601String(),
      'lastImpressionTime': lastImpressionTime?.toIso8601String(),
      'errorCodeCounts': errorCodeCounts,
      'fillRate': fillRate,
      'clickThroughRate': clickThroughRate,
      'circuitBreakerTrips': circuitBreakerTrips,
      'rateLimitHits': rateLimitHits,
    };
  }
}

/// Service to track ad performance metrics
class AdPerformanceService extends StateNotifier<AdPerformanceMetrics> {
  AdPerformanceService() : super(const AdPerformanceMetrics());

  /// Record ad load attempt
  void recordLoadAttempt() {
    state = state.copyWith(
      totalLoadAttempts: state.totalLoadAttempts + 1,
    );
    _updateFillRate();
  }

  /// Record successful ad load
  void recordLoadSuccess(Duration loadDuration) {
    final newSuccessCount = state.successfulLoads + 1;
    
    // Calculate new average load duration
    final totalDuration = state.averageLoadDuration.inMilliseconds * state.successfulLoads;
    final newAverageDuration = Duration(
      milliseconds: (totalDuration + loadDuration.inMilliseconds) ~/ newSuccessCount,
    );

    state = state.copyWith(
      successfulLoads: newSuccessCount,
      lastLoadTime: DateTime.now(),
      averageLoadDuration: newAverageDuration,
    );
    _updateFillRate();
    
    debugPrint('📊 Ad Load Success: ${state.successfulLoads}/${state.totalLoadAttempts} (${state.fillRate.toStringAsFixed(1)}% fill rate)');
  }

  /// Record failed ad load
  void recordLoadFailure(String errorCode) {
    final errorCounts = Map<String, int>.from(state.errorCodeCounts);
    errorCounts[errorCode] = (errorCounts[errorCode] ?? 0) + 1;

    state = state.copyWith(
      failedLoads: state.failedLoads + 1,
      errorCodeCounts: errorCounts,
    );
    _updateFillRate();
    
    debugPrint('📊 Ad Load Failure: Error $errorCode (${state.failedLoads} total failures)');
  }

  /// Record ad impression
  void recordImpression() {
    state = state.copyWith(
      totalImpressions: state.totalImpressions + 1,
      lastImpressionTime: DateTime.now(),
    );
    _updateClickThroughRate();
    
    debugPrint('📊 Ad Impression: ${state.totalImpressions} total');
  }

  /// Record ad click
  void recordClick() {
    state = state.copyWith(
      totalClicks: state.totalClicks + 1,
    );
    _updateClickThroughRate();
    
    debugPrint('📊 Ad Click: ${state.totalClicks}/${state.totalImpressions} (${state.clickThroughRate.toStringAsFixed(2)}% CTR)');
  }

  /// Record circuit breaker trip
  void recordCircuitBreakerTrip() {
    state = state.copyWith(
      circuitBreakerTrips: state.circuitBreakerTrips + 1,
    );
    
    debugPrint('📊 Circuit Breaker Tripped: ${state.circuitBreakerTrips} times');
  }

  /// Record rate limit hit
  void recordRateLimitHit() {
    state = state.copyWith(
      rateLimitHits: state.rateLimitHits + 1,
    );
    
    debugPrint('📊 Rate Limit Hit: ${state.rateLimitHits} times');
  }

  /// Update fill rate calculation
  void _updateFillRate() {
    if (state.totalLoadAttempts > 0) {
      final fillRate = (state.successfulLoads / state.totalLoadAttempts) * 100;
      state = state.copyWith(fillRate: fillRate);
    }
  }

  /// Update click-through rate calculation
  void _updateClickThroughRate() {
    if (state.totalImpressions > 0) {
      final ctr = (state.totalClicks / state.totalImpressions) * 100;
      state = state.copyWith(clickThroughRate: ctr);
    }
  }

  /// Get performance summary for debugging
  String getPerformanceSummary() {
    return '''
📊 Ad Performance Metrics:
  • Load Attempts: ${state.totalLoadAttempts}
  • Successful Loads: ${state.successfulLoads}
  • Failed Loads: ${state.failedLoads}
  • Fill Rate: ${state.fillRate.toStringAsFixed(1)}%
  • Avg Load Time: ${state.averageLoadDuration.inMilliseconds}ms
  • Total Impressions: ${state.totalImpressions}
  • Total Clicks: ${state.totalClicks}
  • Click-Through Rate: ${state.clickThroughRate.toStringAsFixed(2)}%
  • Circuit Breaker Trips: ${state.circuitBreakerTrips}
  • Rate Limit Hits: ${state.rateLimitHits}
  • Error Codes: ${state.errorCodeCounts}
''';
  }

  /// Reset metrics (for testing)
  void reset() {
    state = const AdPerformanceMetrics();
    debugPrint('📊 Performance metrics reset');
  }
}

/// Provider for ad performance service
final adPerformanceServiceProvider = StateNotifierProvider<AdPerformanceService, AdPerformanceMetrics>((ref) {
  return AdPerformanceService();
});
