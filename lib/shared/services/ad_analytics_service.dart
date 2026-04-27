import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:defyx_vpn/shared/services/firebase_analytics_service.dart';

/// Ad-specific analytics service for tracking rotation performance.
///
/// Tracks 20+ event types including:
/// - Rotation cycle events (started, stopped)
/// - Position-specific events (load, impression, click)
/// - Parallel loading events (preload, cache hit/miss)
/// - Performance metrics (show rate, rotation efficiency)
///
/// All events are sent to Firebase Analytics for aggregation.
class AdAnalyticsService {
  AdAnalyticsService({required FirebaseAnalyticsService firebaseAnalytics})
    : _firebase = firebaseAnalytics;

  final FirebaseAnalyticsService _firebase;

  // ===== Rotation Cycle Events =====

  /// Log when a rotation cycle starts
  Future<void> logRotationCycleStarted({required String sessionId}) async {
    await _firebase.logEvent(
      name: 'ad_rotation_cycle_started',
      parameters: {
        'session_id': sessionId,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
  }

  /// Log when a rotation cycle stops
  Future<void> logRotationCycleStopped({
    required String sessionId,
    required int adsShown,
    required int durationSeconds,
  }) async {
    await _firebase.logEvent(
      name: 'ad_rotation_cycle_stopped',
      parameters: {
        'session_id': sessionId,
        'ads_shown': adsShown.toString(),
        'duration_seconds': durationSeconds.toString(),
        'completion_rate': (adsShown / 5 * 100).toStringAsFixed(1),
      },
    );
  }

  // ===== Position-Specific Load Events =====

  /// Log when ad loading starts for a specific position
  Future<void> logAdPositionLoadStarted({
    required int position,
    required String sessionId,
  }) async {
    await _firebase.logEvent(
      name: 'ad_position_load_started',
      parameters: {
        'position': position.toString(),
        'session_id': sessionId,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
  }

  /// Log successful ad load for a position
  Future<void> logAdPositionLoadSuccess({
    required int position,
    required String sessionId,
    required int durationMs,
  }) async {
    await _firebase.logEvent(
      name: 'ad_position_load_success',
      parameters: {
        'position': position.toString(),
        'session_id': sessionId,
        'duration_ms': durationMs.toString(),
        'load_speed': durationMs < 5000
            ? 'fast'
            : (durationMs < 9000 ? 'normal' : 'slow'),
      },
    );
  }

  /// Log failed ad load for a position
  Future<void> logAdPositionLoadFailure({
    required int position,
    required String sessionId,
    required String errorCode,
    required String errorMessage,
  }) async {
    await _firebase.logEvent(
      name: 'ad_position_load_failure',
      parameters: {
        'position': position.toString(),
        'session_id': sessionId,
        'error_code': errorCode,
        'error_message': errorMessage,
      },
    );
  }

  /// Log ad impression (ad shown to user)
  Future<void> logAdPositionImpression({
    required int position,
    required String sessionId,
  }) async {
    await _firebase.logEvent(
      name: 'ad_position_impression',
      parameters: {
        'position': position.toString(),
        'session_id': sessionId,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
  }

  /// Log ad click
  Future<void> logAdPositionClicked({
    required int position,
    required String sessionId,
  }) async {
    await _firebase.logEvent(
      name: 'ad_position_clicked',
      parameters: {'position': position.toString(), 'session_id': sessionId},
    );
  }

  // ===== Parallel Loading Events =====

  /// Log when preloading starts for next ad
  Future<void> logAdPreloadStarted({
    required int position,
    required String sessionId,
  }) async {
    await _firebase.logEvent(
      name: 'ad_preload_started',
      parameters: {
        'next_position': position.toString(),
        'session_id': sessionId,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
  }

  /// Log successful preload
  Future<void> logAdPreloadSuccess({
    required int position,
    required String sessionId,
    required int durationMs,
  }) async {
    await _firebase.logEvent(
      name: 'ad_preload_success',
      parameters: {
        'position': position.toString(),
        'session_id': sessionId,
        'duration_ms': durationMs.toString(),
      },
    );
  }

  /// Log failed preload
  Future<void> logAdPreloadFailure({
    required int position,
    required String sessionId,
    required String reason,
  }) async {
    await _firebase.logEvent(
      name: 'ad_preload_failure',
      parameters: {
        'position': position.toString(),
        'session_id': sessionId,
        'failure_reason': reason,
      },
    );
  }

  /// Log cache hit (preloaded ad used)
  Future<void> logAdCacheHit({
    required int position,
    required String sessionId,
  }) async {
    await _firebase.logEvent(
      name: 'ad_cache_hit',
      parameters: {'position': position.toString(), 'session_id': sessionId},
    );
  }

  /// Log cache miss (had to load on demand)
  Future<void> logAdCacheMiss({
    required int position,
    required String sessionId,
    required String reason,
  }) async {
    await _firebase.logEvent(
      name: 'ad_cache_miss',
      parameters: {
        'position': position.toString(),
        'session_id': sessionId,
        'miss_reason': reason,
      },
    );
  }

  // ===== Performance Metrics =====

  /// Log show rate metrics (requests vs impressions)
  Future<void> logShowRateMetrics({
    required int periodHours,
    required int totalRequests,
    required int totalImpressions,
  }) async {
    final showRate = totalRequests > 0
        ? (totalImpressions / totalRequests * 100)
        : 0.0;

    await _firebase.logEvent(
      name: 'ad_show_rate_metrics',
      parameters: {
        'period_hours': periodHours.toString(),
        'show_rate_percent': showRate.toStringAsFixed(1),
        'total_requests': totalRequests.toString(),
        'total_impressions': totalImpressions.toString(),
      },
    );
  }

  /// Log rotation performance summary
  Future<void> logRotationPerformance({
    required int periodHours,
    required double avgAdsPerCycle,
    required double avgCycleDuration,
    required int totalCycles,
  }) async {
    await _firebase.logEvent(
      name: 'ad_rotation_performance',
      parameters: {
        'period_hours': periodHours.toString(),
        'avg_ads_per_cycle': avgAdsPerCycle.toStringAsFixed(2),
        'avg_cycle_duration_seconds': avgCycleDuration.toStringAsFixed(1),
        'total_cycles': totalCycles.toString(),
      },
    );
  }

  // ===== User Properties =====

  /// Set user's ad consent type
  Future<void> setUserAdConsent(String consentType) async {
    await _firebase.setUserProperty(
      'ad_consent_type',
      consentType, // 'personalized' or 'non_personalized'
    );
  }

  /// Increment user's lifetime ad view count
  Future<void> incrementUserAdViews() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt('total_ad_views_lifetime') ?? 0;
    await prefs.setInt('total_ad_views_lifetime', currentCount + 1);

    await _firebase.setUserProperty(
      'total_ad_views_lifetime',
      (currentCount + 1).toString(),
    );
  }
}

/// Provider for AdAnalyticsService
final adAnalyticsServiceProvider = Provider<AdAnalyticsService>((ref) {
  final firebaseAnalytics = FirebaseAnalyticsService();
  return AdAnalyticsService(firebaseAnalytics: firebaseAnalytics);
});
