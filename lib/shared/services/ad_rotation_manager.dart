import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:uuid/uuid.dart';

import 'package:defyx_vpn/shared/constants/ad_constants.dart';
import 'package:defyx_vpn/shared/services/ad_analytics_service.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/ads_state.dart';
import 'package:defyx_vpn/app/ad_director_provider.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/strategy/google_ad_strategy.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';

/// Manages ad rotation cycles with parallel loading.
///
/// Coordinates the sequential display of multiple ads during a single
/// disconnect cycle, with intelligent preloading to minimize wait times.
///
/// **Lifecycle:**
/// 1. User disconnects → `startRotationCycle()` called
/// 2. Load Ad #1 → Show Ad #1 → Preload Ad #2 in parallel
/// 3. Show Ad #2 → Preload Ad #3 in parallel
/// 4. Continue until max ads reached or user reconnects
/// 5. User reconnects → `stopRotation()` called → Cleanup
///
/// **Thread Safety:** All public methods are async and safe to call from UI thread
class AdRotationManager {
  AdRotationManager({required AdAnalyticsService analytics, required Ref ref})
    : _analytics = analytics,
      _ref = ref;

  // === Dependencies (injected) ===
  final AdAnalyticsService _analytics;
  final Ref _ref;

  // === State ===
  int _currentPosition = 0;
  bool _isRotating = false;
  String? _sessionId;
  DateTime? _cycleStartTime;

  NativeAd? _currentAd;
  NativeAd? _nextAd; // Preloaded
  bool _isLoadingNext = false;

  // === Getters (read-only access to state) ===

  int get currentPosition => _currentPosition;
  bool get isRotating => _isRotating;
  String? get sessionId => _sessionId;
  DateTime? get cycleStartTime => _cycleStartTime;
  bool get isLoadingNext => _isLoadingNext;
  int? get nextAdPosition => _isLoadingNext ? _currentPosition + 1 : null;

  // === Public API ===

  /// Starts a new rotation cycle.
  ///
  /// Called when user disconnects from VPN. Loads and displays
  /// ads sequentially with parallel preloading.
  ///
  /// Throws [StateError] if rotation is already active.
  Future<void> startRotationCycle() async {
    if (_isRotating) {
      debugPrint('⚠️ Rotation cycle already active');
      return;
    }

    _isRotating = true;
    _currentPosition = 1;
    _sessionId = _generateSessionId();
    _cycleStartTime = DateTime.now();

    debugPrint('🔄 Starting rotation cycle: $_sessionId');

    // Analytics
    await _analytics.logRotationCycleStarted(sessionId: _sessionId!);

    // Load and show first ad
    await _loadAndShowAd(position: 1);
  }

  /// Stops the current rotation cycle.
  ///
  /// Called when user reconnects to VPN or cycle completes.
  /// Cleans up all ad instances and resets state.
  void stopRotation() {
    if (!_isRotating) {
      return; // Already stopped
    }

    debugPrint('⏹️ Stopping rotation cycle: $_sessionId');

    _isRotating = false;

    // Analytics
    if (_sessionId != null && _cycleStartTime != null) {
      final durationSeconds = DateTime.now()
          .difference(_cycleStartTime!)
          .inSeconds;

      _analytics.logRotationCycleStopped(
        sessionId: _sessionId!,
        adsShown: _currentPosition,
        durationSeconds: durationSeconds,
      );
    }

    // Cleanup
    _disposeAds();
    _resetState();
  }

  // === Private Methods ===

  /// Loads and displays ad at specified position.
  ///
  /// Handles both fresh loads and cached (preloaded) ads.
  /// Automatically starts preloading the next ad.
  Future<void> _loadAndShowAd({required int position}) async {
    if (!_isRotating) {
      return; // Rotation stopped during async operation
    }

    NativeAd? adToShow;

    // Check if next ad was preloaded
    if (_nextAd != null) {
      debugPrint('✅ Using preloaded ad for position $position');
      adToShow = _nextAd;
      _nextAd = null;

      _analytics.logAdCacheHit(position: position, sessionId: _sessionId!);
    } else {
      // Load on demand (first ad or preload failed)
      debugPrint('⏳ Loading ad on demand for position $position');
      adToShow = await _loadAdAtPosition(position);

      if (adToShow == null) {
        _analytics.logAdCacheMiss(
          position: position,
          sessionId: _sessionId!,
          reason: 'on_demand_load_failed',
        );
      }
    }

    if (adToShow == null) {
      debugPrint('❌ No ad available for position $position');
      // Continue to next position (don't stop rotation)
      _scheduleNextAd(position + 1);
      return;
    }

    // Show ad
    _currentAd = adToShow;
    _currentPosition = position;

    // Update state to show ad
    _ref
        .read(adsProvider.notifier)
        .setNativeAd(ad: adToShow, position: position, sessionId: _sessionId!);

    debugPrint('👁️ Showing ad at position $position');

    // Start preloading next ad (parallel)
    if (position < AdConstants.maxAdsPerCycle) {
      _startPreloadingNext(position + 1);
    }

    // Schedule next ad display
    _scheduleNextAd(position + 1);
  }

  /// Loads ad at specified position with analytics tracking.
  ///
  /// Returns null if load fails.
  Future<NativeAd?> _loadAdAtPosition(int position) async {
    try {
      // Get the strategy manager to access GoogleAdStrategy
      final manager = _ref.read(adStrategyManagerProvider);
      
      if (manager == null) {
        debugPrint('❌ No strategy manager available');
        return null;
      }
      
      // Get the active strategy
      final connectionState = _ref.read(connectionStateProvider);
      final activeStrategy = manager.getActiveStrategy(connectionState.status);
      
      // Verify it's GoogleAdStrategy
      if (activeStrategy is! GoogleAdStrategy) {
        debugPrint('❌ Active strategy is not GoogleAdStrategy');
        return null;
      }
      
      debugPrint('📞 Calling GoogleAdStrategy.loadAdAtPosition(position: $position)');
      
      // Call the actual loading method
      final ad = await activeStrategy.loadAdAtPosition(
        position: position,
        sessionId: _sessionId!,
        ref: _ref,
      );
      
      return ad;
    } catch (e) {
      _analytics.logAdPositionLoadFailure(
        position: position,
        sessionId: _sessionId!,
        errorCode: 'EXCEPTION',
        errorMessage: e.toString(),
      );

      return null;
    }
  }

  /// Starts preloading the next ad in background.
  ///
  /// Runs in parallel with current ad display to minimize wait time.
  Future<void> _startPreloadingNext(int nextPosition) async {
    if (_isLoadingNext) {
      return; // Already loading
    }

    if (!_isRotating) {
      return; // Rotation stopped
    }

    _isLoadingNext = true;

    debugPrint('⏬ Preloading ad for position $nextPosition');

    _analytics.logAdPreloadStarted(
      position: nextPosition,
      sessionId: _sessionId!,
    );

    final preloadStartTime = DateTime.now();

    try {
      _nextAd = await _loadAdAtPosition(nextPosition);

      if (_nextAd != null) {
        final preloadDuration = DateTime.now()
            .difference(preloadStartTime)
            .inMilliseconds;

        _analytics.logAdPreloadSuccess(
          position: nextPosition,
          sessionId: _sessionId!,
          durationMs: preloadDuration,
        );

        debugPrint('✅ Preloaded ad for position $nextPosition');
      } else {
        _analytics.logAdPreloadFailure(
          position: nextPosition,
          sessionId: _sessionId!,
          reason: 'load_returned_null',
        );
      }
    } catch (e) {
      _analytics.logAdPreloadFailure(
        position: nextPosition,
        sessionId: _sessionId!,
        reason: e.toString(),
      );
    } finally {
      _isLoadingNext = false;
    }
  }

  /// Schedules the next ad to display after current one finishes.
  void _scheduleNextAd(int nextPosition) {
    if (nextPosition > AdConstants.maxAdsPerCycle) {
      debugPrint('✅ Reached max ads per cycle');
      stopRotation();
      return;
    }

    if (!_isRotating) {
      return; // Rotation stopped
    }

    // Schedule next ad after display duration
    Future.delayed(Duration(seconds: AdConstants.adDisplayDurationSeconds), () {
      if (_isRotating) {
        _loadAndShowAd(position: nextPosition);
      }
    });
  }

  /// Disposes all ad instances.
  void _disposeAds() {
    try {
      _currentAd?.dispose();
      _nextAd?.dispose();
    } catch (e) {
      debugPrint('⚠️ Error disposing ads: $e');
    }

    _currentAd = null;
    _nextAd = null;
  }

  /// Resets internal state.
  void _resetState() {
    _currentPosition = 0;
    _sessionId = null;
    _cycleStartTime = null;
    _isLoadingNext = false;
  }

  /// Generates unique session ID.
  String _generateSessionId() {
    const uuid = Uuid();
    return '${AdConstants.sessionIdPrefix}${uuid.v4().substring(0, 8)}';
  }
}

/// Provider for AdRotationManager
final adRotationManagerProvider = Provider<AdRotationManager>((ref) {
  final analytics = ref.watch(adAnalyticsServiceProvider);
  return AdRotationManager(analytics: analytics, ref: ref);
});
