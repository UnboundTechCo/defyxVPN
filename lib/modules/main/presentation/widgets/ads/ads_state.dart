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
        final startTime = DateTime.fromMillisecondsSinceEpoch(startTimeMillis);
        final elapsed = DateTime.now().difference(startTime).inSeconds;
        final remaining = countdownDuration - elapsed;
        
        if (remaining > 0) {
          // Resume countdown from where it left off
          debugPrint('⏱️ Resuming countdown: $remaining seconds remaining (elapsed: ${elapsed}s)');
          state = state.copyWith(
            countdown: remaining,
            showCountdown: true,
          );
          _startCountdownFromValue(remaining);
        } else {
          // Countdown already expired
          debugPrint('⏱️ Countdown already expired (elapsed: ${elapsed}s)');
          state = state.copyWith(
            countdown: 0,
            showCountdown: false,
          );
          await _clearPersistedCountdown();
        }
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
  void startCountdownTimer() async {
    if (_countdownTimer != null && _countdownTimer!.isActive) {
      debugPrint('⏱️ Countdown already running, ignoring duplicate start');
      return;
    }

    debugPrint('▶️ Starting new countdown timer');
    _countdownTimer?.cancel();
    
    // Clear any old persisted countdown before starting new one
    await _clearPersistedCountdown();
    
    state = state.copyWith(
      countdown: countdownDuration,
      showCountdown: true,
    );
    
    // Save start time for persistence
    await _saveCountdownStartTime();
    
    _startCountdownFromValue(countdownDuration);
  }
  
  /// Start countdown from a specific value (used for both new and resumed timers)
  void _startCountdownFromValue(int startValue) {
    _countdownTimer?.cancel();
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.countdown > 0) {
        state = state.copyWith(countdown: state.countdown - 1);
      } else {
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
    _countdownTimer?.cancel();
    // Don't clear persisted countdown on dispose - allow it to persist across app restarts
    super.dispose();
  }
}

/// Provider for ads state management
final adsProvider =
    StateNotifierProvider<AdsNotifier, AdsState>((ref) {
  return AdsNotifier();
});
