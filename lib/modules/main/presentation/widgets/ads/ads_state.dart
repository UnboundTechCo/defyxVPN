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

/// Countdown duration in seconds before ad is hidden
const int countdownDuration = 60;

class AdsState {
  final bool nativeAdIsLoaded;
  final bool adLoadFailed;
  final int countdown;
  final bool showCountdown;
  final DateTime? adLoadedAt;
  final int retryCount;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  // Internal ads properties
  final String? customImageUrl;
  final String? customClickUrl;
  final bool customImageLoadFailed;
  // Fallback tracking
  final bool hasFallenBackToInternal;

  const AdsState({
    this.nativeAdIsLoaded = false,
    this.adLoadFailed = false,
    this.countdown = countdownDuration,
    this.showCountdown = true,
    this.adLoadedAt,
    this.retryCount = 0,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.customImageUrl,
    this.customClickUrl,
    this.customImageLoadFailed = false,
    this.hasFallenBackToInternal = false,
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
    bool? hasFallenBackToInternal,
  }) {
    return AdsState(
      nativeAdIsLoaded: nativeAdIsLoaded ?? this.nativeAdIsLoaded,
      adLoadFailed: adLoadFailed ?? this.adLoadFailed,
      countdown: countdown ?? this.countdown,
      showCountdown: showCountdown ?? this.showCountdown,
      adLoadedAt: adLoadedAt ?? this.adLoadedAt,
      retryCount: retryCount ?? this.retryCount,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      customImageUrl: customImageUrl ?? this.customImageUrl,
      customClickUrl: customClickUrl ?? this.customClickUrl,
      customImageLoadFailed: customImageLoadFailed ?? this.customImageLoadFailed,
      hasFallenBackToInternal: hasFallenBackToInternal ?? this.hasFallenBackToInternal,
    );
  }

  /// Check if ad needs refresh (older than 15 minutes)
  bool get needsRefresh {
    if (adLoadedAt == null) return true;
    final age = DateTime.now().difference(adLoadedAt!);
    return age.inMinutes >= 15;
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
      await prefs.setInt(_countdownStartKey, DateTime.now().millisecondsSinceEpoch);
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
  /// Always restarts to 60 seconds on each connection
  void startCountdownTimer() {
    debugPrint('▶️ Starting new countdown timer (60 seconds)');
    _countdownTimer?.cancel();
    
    // Update state immediately (synchronous)
    state = state.copyWith(
      countdown: countdownDuration,
      showCountdown: true,
    );
    
    // Clear old and save new start time in background (async)
    _clearPersistedCountdown().then((_) {
      _saveCountdownStartTime();
    });
    
    _startCountdownFromValue(countdownDuration);
  }
  
  /// Stop the countdown timer and clear persisted state
  /// Called when VPN disconnects
  void stopCountdownTimer() {
    debugPrint('⏸️ Stopping countdown timer');
    _countdownTimer?.cancel();
    
    // Update state immediately (synchronous)
    state = state.copyWith(
      showCountdown: false,
      countdown: countdownDuration,
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
        debugPrint('⏱️ Countdown finished - hiding ad');
        state = state.copyWith(
          showCountdown: false,
          // Keep ad loaded - just hide it until next connection
        );
        timer.cancel();
        _clearPersistedCountdown();
      }
    });
  }

  /// Set ad as loaded (for Google AdMob ads)
  void setAdLoaded(bool isLoaded) {
    debugPrint('✅ Ad loaded: $isLoaded');
    state = state.copyWith(
      nativeAdIsLoaded: isLoaded,
      adLoadFailed: false,
      adLoadedAt: isLoaded ? DateTime.now() : null,
    );
  }

  /// Set custom ad data (for internal/custom ads)
  void setCustomAdData(String imageUrl, String clickUrl) {
    debugPrint('✅ Custom ad loaded: $imageUrl');
    state = state.copyWith(
      customImageUrl: imageUrl,
      customClickUrl: clickUrl,
      nativeAdIsLoaded: true,
      adLoadFailed: false,
      adLoadedAt: DateTime.now(),
      customImageLoadFailed: false,
    );
  }

  /// Mark custom image load as failed
  void setCustomImageLoadFailed() {
    debugPrint('❌ Custom ad image failed to load');
    state = state.copyWith(
      customImageLoadFailed: true,
      adLoadFailed: true,
    );
  }

  /// Set fallback status to internal ads
  void setFallenBackToInternal(bool hasFallenBack) {
    debugPrint('🔄 Fallen back to internal ads: $hasFallenBack');
    state = state.copyWith(
      hasFallenBackToInternal: hasFallenBack,
    );
  }

  /// Set ad loading as failed with error details
  void setAdLoadFailed({String? errorCode, String? errorMessage, int? retryCount}) {
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
    // Clear persisted countdown on dispose to prevent zombie timers
    _clearPersistedCountdown();
    super.dispose();
  }
}

/// Provider for ads state management
final adsProvider =
    StateNotifierProvider<AdsNotifier, AdsState>((ref) {
  return AdsNotifier();
});
