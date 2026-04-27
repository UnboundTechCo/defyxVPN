/// Shared state management for all ad loading strategies.
///
/// This file contains the core state model and notifier that will be used
/// by different ad loading strategies (Google AdMob, Internal Ads, etc.).
///
/// The state is centralized here to ensure consistent behavior across
/// all ad types while allowing the loading logic to vary via Strategy Pattern.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:defyx_vpn/shared/constants/ad_constants.dart';

/// Shared ad state model used by both GoogleAdStrategy and InternalAdStrategy.
///
/// **State Flag Ownership:**
///
/// GoogleAdStrategy (AdMob ads, disconnected state):
/// - `nativeAdIsLoaded` - True when AdMob NativeAd is loaded and ready (EXCLUSIVE OWNERSHIP)
/// - Uses shared: `adLoadedAt`, `showCountdown`, `countdown`
/// - Sets via: setNativeAd() method ONLY
///
/// InternalAdStrategy  (Internal ads, connected state):
/// - `customImageUrl` - URL of internal ad image to display (EXCLUSIVE OWNERSHIP)
/// - `customClickUrl` - URL to open when internal ad is clicked
/// - `customImageLoadFailed` - True if image failed to load
/// - Uses shared: `showCountdown`, `countdown`
/// - Sets via: setCustomAdData() method (NOTE: does NOT set nativeAdIsLoaded)
///
/// Shared by both strategies:
/// - `adLoadFailed` - True if any ad load failed
/// - `lastErrorCode`, `lastErrorMessage` - Last error info
/// - `countdown`, `showCountdown` - Countdown timer state
/// - `retryCount` - Number of retry attempts
/// - `adLoadedAt` - Timestamp when ad was loaded
///
class AdsState {
  // GoogleAdStrategy state (AdMob)
  final bool nativeAdIsLoaded;

  // Shared error tracking
  final bool adLoadFailed;
  final String? lastErrorCode;
  final String? lastErrorMessage;

  // Shared countdown state
  final int countdown;
  final bool showCountdown;

  // Shared metadata
  final DateTime? adLoadedAt;
  final int retryCount;

  // InternalAdStrategy state (Internal ads)
  final String? customImageUrl;
  final String? customClickUrl;
  final bool customImageLoadFailed;

  // Ad Rotation state (for rotation manager)
  final int currentAdPosition;
  final String? rotationSessionId;
  final bool isRotating;
  final bool isPreloading;

  const AdsState({
    this.nativeAdIsLoaded = false,
    this.adLoadFailed = false,
    this.countdown = AdConstants.cycleTimeoutSeconds,
    this.showCountdown = false,
    this.adLoadedAt,
    this.retryCount = 0,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.customImageUrl,
    this.customClickUrl,
    this.customImageLoadFailed = false,
    this.currentAdPosition = 0,
    this.rotationSessionId,
    this.isRotating = false,
    this.isPreloading = false,
  });

  AdsState copyWith({
    bool? nativeAdIsLoaded,
    bool? adLoadFailed,
    int? countdown,
    bool? showCountdown,
    DateTime? adLoadedAt,
    int? retryCount,
    String? lastErrorCode,
    String? lastErrorMessage,
    String? customImageUrl,
    String? customClickUrl,
    bool? customImageLoadFailed,
    int? currentAdPosition,
    String? rotationSessionId,
    bool? isRotating,
    bool? isPreloading,
  }) {
    return AdsState(
      adLoadFailed: adLoadFailed ?? this.adLoadFailed,
      countdown: countdown ?? this.countdown,
      showCountdown: showCountdown ?? this.showCountdown,
      adLoadedAt: adLoadedAt ?? this.adLoadedAt,
      retryCount: retryCount ?? this.retryCount,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      customImageUrl:
          customImageUrl ??
          this.customImageUrl, // Preserve existing value if not provided
      customClickUrl:
          customClickUrl ??
          this.customClickUrl, // Preserve existing value if not provided
      customImageLoadFailed:
          customImageLoadFailed ?? this.customImageLoadFailed,
      nativeAdIsLoaded: nativeAdIsLoaded ?? this.nativeAdIsLoaded,
      currentAdPosition: currentAdPosition ?? this.currentAdPosition,
      rotationSessionId: rotationSessionId ?? this.rotationSessionId,
      isRotating: isRotating ?? this.isRotating,
      isPreloading: isPreloading ?? this.isPreloading,
    );
  }

  /// Check if ad needs refresh (older than threshold)
  bool get needsRefresh {
    if (adLoadedAt == null) return true;
    final age = DateTime.now().difference(adLoadedAt!);
    return age.inMinutes >= AdConstants.adRefreshAgeMinutes;
  }

  /// Get user-friendly error solution based on error code
  String get errorSolution {
    if (lastErrorCode == null) return '';
    switch (lastErrorCode) {
      case '0':
        return 'Internal SDK error - will retry automatically';
      case '1':
        return 'Invalid ad request - check Ad Unit ID configuration';
      case '2':
        return 'Network error - check internet connection';
      case '3':
        return 'No ad inventory available - normal occurrence';
      default:
        return 'Unknown error - check logs for details';
    }
  }
}

/// State notifier for managing ad state and countdown timer
class AdsNotifier extends StateNotifier<AdsState> {
  AdsNotifier() : super(const AdsState()) {
    _loadPersistedCountdown();
  }

  Timer? _countdownTimer;
  static const String _countdownStartKey = 'ad_countdown_start_time';

  /// Callback for notifying strategies when ads should be disposed
  VoidCallback? _onAdShouldDispose;

  /// Load persisted countdown state on initialization
  Future<void> _loadPersistedCountdown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startTimeMillis = prefs.getInt(_countdownStartKey);

      if (startTimeMillis != null) {
        // Simply clear any persisted countdown on app start
        // Countdown should only start when VPN connects (handled by strategies)
        debugPrint('🗑️ Clearing persisted countdown from previous session');
        await _clearPersistedCountdown();
      }
    } catch (e) {
      debugPrint('⚠️ Error loading persisted countdown: $e');
    }
  }

  /// Save countdown start time to SharedPreferences
  Future<void> _saveCountdownStartTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _countdownStartKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('💾 Saved countdown start time');
    } catch (e) {
      debugPrint('⚠️ Error saving countdown start time: $e');
    }
  }

  /// Clear persisted countdown from SharedPreferences
  Future<void> _clearPersistedCountdown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_countdownStartKey);
      debugPrint('🗑️ Cleared persisted countdown');
    } catch (e) {
      debugPrint('⚠️ Error clearing countdown: $e');
    }
  }

  /// Start the countdown timer after ad is loaded and VPN connects
  /// Always restarts to cycle timeout duration
  void startCountdownTimer() {
    debugPrint(
      '▶️ Starting new countdown timer (${AdConstants.cycleTimeoutSeconds} seconds)',
    );
    debugPrint(
      '   📊 State BEFORE: nativeAdIsLoaded=${state.nativeAdIsLoaded}, showCountdown=${state.showCountdown}',
    );
    _countdownTimer?.cancel();

    // Update state immediately (synchronous)
    state = state.copyWith(
      countdown: AdConstants.cycleTimeoutSeconds,
      showCountdown: true,
    );
    debugPrint(
      '   📊 State AFTER: nativeAdIsLoaded=${state.nativeAdIsLoaded}, showCountdown=${state.showCountdown}',
    );

    // Clear old and save new start time in background (async)
    _clearPersistedCountdown().then((_) {
      _saveCountdownStartTime();
    });

    _startCountdownFromValue(AdConstants.cycleTimeoutSeconds);
  }

  /// Stop the countdown timer and clear persisted state
  /// Called when VPN disconnects
  void stopCountdownTimer() {
    debugPrint('⏸️ Stopping countdown timer');
    debugPrint(
      '   📊 State BEFORE: nativeAdIsLoaded=${state.nativeAdIsLoaded}, showCountdown=${state.showCountdown}',
    );
    _countdownTimer?.cancel();

    // Update state immediately (synchronous)
    state = state.copyWith(
      showCountdown: false,
      countdown: AdConstants.cycleTimeoutSeconds,
    );
    debugPrint(
      '   📊 State AFTER: nativeAdIsLoaded=${state.nativeAdIsLoaded}, showCountdown=${state.showCountdown}',
    );

    // Clear persisted data in background (async)
    _clearPersistedCountdown();
  }

  /// Start countdown from a specific value (used for both new and resumed timers)
  void _startCountdownFromValue(int startValue) {
    _countdownTimer?.cancel();

    debugPrint('⏱️ Timer starting from $startValue seconds');
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.countdown > 0) {
        final newCount = state.countdown - 1;
        debugPrint('⏱️ Countdown: $newCount');
        state = state.copyWith(countdown: newCount);
      } else {
        debugPrint('⏱️ Countdown finished - disposing ad and clearing state');

        // Clear all ad flags to hide the ad box completely
        state = state.copyWith(
          showCountdown: false,
          nativeAdIsLoaded: false,
          customImageUrl: '',
          customClickUrl: '',
        );

        // Notify strategies to dispose their ad instances
        _onAdShouldDispose?.call();
        debugPrint('🗑️ Ad disposal callback triggered');

        timer.cancel();
        _clearPersistedCountdown();
      }
    });
  }

  /// Set ad as loaded (for Google AdMob ads)
  void setAdLoaded(bool isLoaded) {
    debugPrint('✅ Ad loaded: $isLoaded');
    debugPrint(
      '   📊 State BEFORE: nativeAdIsLoaded=${state.nativeAdIsLoaded}, showCountdown=${state.showCountdown}',
    );
    state = state.copyWith(
      nativeAdIsLoaded: isLoaded,
      adLoadFailed: false,
      adLoadedAt: isLoaded ? DateTime.now() : null,
    );
    debugPrint(
      '   📊 State AFTER: nativeAdIsLoaded=${state.nativeAdIsLoaded}, showCountdown=${state.showCountdown}',
    );
  }

  /// Set ad with rotation information (for rotation manager)
  void setNativeAd({
    required ad,
    required int position,
    required String sessionId,
  }) {
    debugPrint('✅ Ad loaded at position $position (session: $sessionId)');
    state = state.copyWith(
      nativeAdIsLoaded: true,
      adLoadFailed: false,
      adLoadedAt: DateTime.now(),
      currentAdPosition: position,
      rotationSessionId: sessionId,
    );
  }

  /// Update rotation state
  void setRotationState({
    required bool isRotating,
    bool? isPreloading,
    String? sessionId,
  }) {
    state = state.copyWith(
      isRotating: isRotating,
      isPreloading: isPreloading ?? state.isPreloading,
      rotationSessionId: sessionId ?? state.rotationSessionId,
    );
  }

  /// Set custom ad data (for internal/custom ads ONLY)
  ///
  /// OWNERSHIP: This method is EXCLUSIVELY for InternalAdStrategy.
  /// GoogleAdStrategy must NOT call this method.
  ///
  /// NOTE: This does NOT set nativeAdIsLoaded flag. That flag belongs to GoogleAdStrategy.
  void setCustomAdData(String imageUrl, String clickUrl) {
    debugPrint('✅ Custom ad loaded: $imageUrl');
    debugPrint(
      '   📊 State BEFORE: customImageUrl=${state.customImageUrl}, nativeAdIsLoaded=${state.nativeAdIsLoaded}',
    );
    state = state.copyWith(
      customImageUrl: imageUrl,
      customClickUrl: clickUrl,
      // NOTE: nativeAdIsLoaded is NOT set here - it belongs ONLY to GoogleAdStrategy
      adLoadFailed: false,
      adLoadedAt: DateTime.now(),
      customImageLoadFailed: false,
    );
    debugPrint(
      '   📊 State AFTER: customImageUrl set, nativeAdIsLoaded=${state.nativeAdIsLoaded} (unchanged)',
    );
  }

  /// Mark custom image load as failed
  void setCustomImageLoadFailed() {
    debugPrint('❌ Custom ad image failed to load');
    state = state.copyWith(customImageLoadFailed: true, adLoadFailed: true);
  }

  /// Clear internal/custom ad data (for switching to AdMob ads)
  void clearCustomAdData() {
    debugPrint('🗑️ Clearing internal ad data');
    debugPrint(
      '   📊 State BEFORE: customImageUrl=${state.customImageUrl != null && state.customImageUrl!.isNotEmpty ? "set" : "null"}, nativeAdIsLoaded=${state.nativeAdIsLoaded}',
    );
    state = state.copyWith(
      customImageUrl: '',
      customClickUrl: '',
      customImageLoadFailed: false,
      nativeAdIsLoaded:
          false, // Clear this flag to prevent showing empty ad container
    );
    debugPrint(
      '   📊 State AFTER: customImageUrl cleared, nativeAdIsLoaded=false',
    );
  }

  /// Register a callback to be notified when ads should be disposed
  /// This allows strategies to clean up their ad instances (e.g., dispose NativeAd)
  void setAdDisposalCallback(VoidCallback callback) {
    debugPrint('📌 Registered ad disposal callback');
    _onAdShouldDispose = callback;
  }

  /// Unregister the ad disposal callback
  void clearAdDisposalCallback() {
    debugPrint('📌 Cleared ad disposal callback');
    _onAdShouldDispose = null;
  }

  /// Set ad loading as failed with error details
  void setAdLoadFailed({
    String? errorCode,
    String? errorMessage,
    int? retryCount,
  }) {
    state = state.copyWith(
      adLoadFailed: true,
      nativeAdIsLoaded: false,
      lastErrorCode: errorCode,
      lastErrorMessage: errorMessage,
      retryCount: retryCount ?? state.retryCount,
    );
  }

  /// Reset state to initial values
  void resetState() async {
    state = const AdsState();
    await _clearPersistedCountdown();
  }

  @override
  void dispose() {
    debugPrint('🧹 AdsNotifier disposing - stopping countdown timer');
    _countdownTimer?.cancel();
    _countdownTimer = null;
    // Clear disposal callback
    _onAdShouldDispose = null;
    // Clear persisted countdown on dispose to prevent zombie timers
    _clearPersistedCountdown();
    super.dispose();
  }
}

/// Provider for ads state management
final adsProvider = StateNotifierProvider<AdsNotifier, AdsState>((ref) {
  return AdsNotifier();
});
