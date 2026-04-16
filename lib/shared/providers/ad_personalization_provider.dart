import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ad personalization state based on ATT authorization
class AdPersonalizationState {
  final TrackingStatus attStatus;
  final bool canUsePersonalizedAds;
  final DateTime? lastChecked;
  final bool consentFlowComplete;
  final bool vpnProfileSetup;
  final bool adMobInitializationStarted;

  const AdPersonalizationState({
    required this.attStatus,
    required this.canUsePersonalizedAds,
    this.lastChecked,
    this.consentFlowComplete = false,
    this.vpnProfileSetup = false,
    this.adMobInitializationStarted = false,
  });

  AdPersonalizationState copyWith({
    TrackingStatus? attStatus,
    bool? canUsePersonalizedAds,
    DateTime? lastChecked,
    bool? consentFlowComplete,
    bool? vpnProfileSetup,
    bool? adMobInitializationStarted,
  }) {
    return AdPersonalizationState(
      attStatus: attStatus ?? this.attStatus,
      canUsePersonalizedAds:
          canUsePersonalizedAds ?? this.canUsePersonalizedAds,
      lastChecked: lastChecked ?? this.lastChecked,
      consentFlowComplete: consentFlowComplete ?? this.consentFlowComplete,
      vpnProfileSetup: vpnProfileSetup ?? this.vpnProfileSetup,
      adMobInitializationStarted:
          adMobInitializationStarted ?? this.adMobInitializationStarted,
    );
  }

  /// Initial state - not determined yet
  factory AdPersonalizationState.initial() {
    return const AdPersonalizationState(
      attStatus: TrackingStatus.notDetermined,
      canUsePersonalizedAds: false,
      lastChecked: null,
      consentFlowComplete: false,
      vpnProfileSetup: false,
      adMobInitializationStarted: false,
    );
  }
}

/// Notifier for managing ad personalization state
class AdPersonalizationNotifier extends StateNotifier<AdPersonalizationState> {
  AdPersonalizationNotifier() : super(AdPersonalizationState.initial()) {
    _loadPersistedState();
  }

  static const String _storageKey = 'ad_personalization_state';

  /// Load persisted ATT status on initialization
  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedStatus = prefs.getInt('${_storageKey}_att_status');

      if (storedStatus != null) {
        final status = TrackingStatus.values[storedStatus];
        final canPersonalize = status == TrackingStatus.authorized;

        state = state.copyWith(
          attStatus: status,
          canUsePersonalizedAds: canPersonalize,
          lastChecked: DateTime.now(),
        );

        debugPrint(
          '📦 Loaded persisted ATT status: ${status.name}, canPersonalize=$canPersonalize',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load persisted ATT state: $e');
    }
  }

  /// Check current ATT status (iOS only)
  Future<void> checkTrackingStatus() async {
    if (!Platform.isIOS) {
      // Android doesn't have ATT - always allow personalized ads
      state = state.copyWith(
        attStatus: TrackingStatus.authorized,
        canUsePersonalizedAds: true,
        lastChecked: DateTime.now(),
      );
      await _persistState();
      return;
    }

    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      final canPersonalize = status == TrackingStatus.authorized;

      state = state.copyWith(
        attStatus: status,
        canUsePersonalizedAds: canPersonalize,
        lastChecked: DateTime.now(),
      );

      await _persistState();
      debugPrint(
        '✅ ATT status checked: ${status.name}, canPersonalize=$canPersonalize',
      );
    } catch (e) {
      debugPrint('❌ Failed to check ATT status: $e');
    }
  }

  /// Request ATT authorization (iOS only)
  Future<TrackingStatus> requestATT() async {
    if (!Platform.isIOS) {
      debugPrint('📱 Skipping ATT request (not iOS)');
      return TrackingStatus.authorized;
    }

    try {
      final status =
          await AppTrackingTransparency.requestTrackingAuthorization();
      final canPersonalize = status == TrackingStatus.authorized;

      state = state.copyWith(
        attStatus: status,
        canUsePersonalizedAds: canPersonalize,
        lastChecked: DateTime.now(),
      );

      await _persistState();
      debugPrint(
        '📱 ATT Authorization: ${status.name}, canPersonalize=$canPersonalize',
      );

      return status;
    } catch (e) {
      debugPrint('❌ ATT request failed: $e');
      return TrackingStatus.notDetermined;
    }
  }

  /// Persist ATT state to SharedPreferences
  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${_storageKey}_att_status', state.attStatus.index);
      await prefs.setBool(
        '${_storageKey}_can_personalize',
        state.canUsePersonalizedAds,
      );
      debugPrint('💾 Persisted ATT state: ${state.attStatus.name}');
    } catch (e) {
      debugPrint('⚠️ Failed to persist ATT state: $e');
    }
  }

  /// Check if we should request UMP consent
  /// Returns false if ATT was denied (Apple compliance)
  bool get shouldRequestUMP {
    // Android - always request UMP (GDPR compliance)
    if (!Platform.isIOS) return true;

    // iOS - only request UMP if ATT authorized
    // This prevents "asking for tracking twice" (Apple guideline 5.1.2)
    final shouldRequest = state.attStatus == TrackingStatus.authorized;

    if (!shouldRequest) {
      debugPrint(
        '⏭️ Skipping UMP request (ATT not authorized: ${state.attStatus.name})',
      );
    }

    return shouldRequest;
  }

  /// Get extras for AdRequest
  Map<String, String> getAdRequestExtras() {
    return {
      'npa': state.canUsePersonalizedAds ? '0' : '1',
      'att_status': state.attStatus.name,
    };
  }

  /// Mark consent flow as complete (called after ATT/UMP finish)
  void markConsentFlowComplete() {
    state = state.copyWith(consentFlowComplete: true);
    debugPrint('✅ Consent flow marked as complete');
  }

  /// Mark VPN profile as setup (called after privacy notice accepted and VPN initialized)
  void markVpnProfileSetup() {
    state = state.copyWith(vpnProfileSetup: true);
    debugPrint('✅ VPN profile setup complete');
  }

  /// Mark AdMob initialization as started (prevents duplicate initialization)
  void markAdMobInitializationStarted() {
    state = state.copyWith(adMobInitializationStarted: true);
    debugPrint('🔒 AdMob initialization started');
  }
}

/// Provider for ad personalization state
final adPersonalizationProvider =
    StateNotifierProvider<AdPersonalizationNotifier, AdPersonalizationState>((
      ref,
    ) {
      return AdPersonalizationNotifier();
    });
