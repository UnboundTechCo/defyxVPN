import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

/// Consolidated state for ad readiness and consent flow
/// 
/// This replaces the fragmented state across:
/// - privacy_notice_shown (MainScreenLogic)
/// - vpnProfileSetup (AdPersonalizationProvider)
/// - attStatus (AdPersonalizationProvider)
/// - consentFlowComplete (volatile, AdPersonalizationProvider)
/// - adMobInitializationStarted (volatile, AdPersonalizationProvider)
@immutable
class AdReadinessState {
  /// Whether user has accepted privacy notice and completed VPN profile setup
  /// Replaces: privacy_notice_shown + vpnProfileSetup
  final bool privacyAccepted;
  
  /// App Tracking Transparency status (iOS only, always authorized on Android)
  final TrackingStatus attStatus;
  
  /// Whether consent flow (ATT + UMP) has completed successfully
  /// NOW PERSISTED (was volatile before)
  final bool consentComplete;
  
  /// Whether AdMob SDK has been initialized
  /// NOW PERSISTED (was volatile before)
  final bool adMobInitialized;
  
  /// Whether user can use personalized ads (based on ATT status)
  final bool canUsePersonalizedAds;
  
  /// Last time consent was checked (for UMP cache coordination)
  final DateTime? lastConsentCheck;
  
  /// Number of initialization attempts (for exponential backoff)
  final int initAttempts;
  
  /// Last error message if initialization failed
  final String? lastError;

  const AdReadinessState({
    this.privacyAccepted = false,
    this.attStatus = TrackingStatus.notDetermined,
    this.consentComplete = false,
    this.adMobInitialized = false,
    this.canUsePersonalizedAds = false,
    this.lastConsentCheck,
    this.initAttempts = 0,
    this.lastError,
  });

  /// Default initial state
  factory AdReadinessState.initial() => const AdReadinessState();

  // Computed properties for flow control

  /// Whether privacy dialog should be shown
  bool get canShowPrivacyDialog => !privacyAccepted;

  /// Whether AdMob initialization can proceed
  bool get canInitializeAdMob =>
      privacyAccepted && !adMobInitialized && !consentComplete;

  /// Whether ads can be loaded
  bool get canLoadAds =>
      privacyAccepted && consentComplete && adMobInitialized;

  /// Whether ATT permission can be requested (iOS only)
  bool get canRequestATT =>
      privacyAccepted && attStatus == TrackingStatus.notDetermined;

  /// Whether initialization is in a failed state and needs reset
  bool get needsReset => lastError != null && initAttempts >= 3;

  // State mutations

  AdReadinessState copyWith({
    bool? privacyAccepted,
    TrackingStatus? attStatus,
    bool? consentComplete,
    bool? adMobInitialized,
    bool? canUsePersonalizedAds,
    DateTime? lastConsentCheck,
    int? initAttempts,
    String? lastError,
  }) {
    return AdReadinessState(
      privacyAccepted: privacyAccepted ?? this.privacyAccepted,
      attStatus: attStatus ?? this.attStatus,
      consentComplete: consentComplete ?? this.consentComplete,
      adMobInitialized: adMobInitialized ?? this.adMobInitialized,
      canUsePersonalizedAds:
          canUsePersonalizedAds ?? this.canUsePersonalizedAds,
      lastConsentCheck: lastConsentCheck ?? this.lastConsentCheck,
      initAttempts: initAttempts ?? this.initAttempts,
      lastError: lastError,
    );
  }

  // Persistence

  Map<String, dynamic> toJson() {
    return {
      'privacyAccepted': privacyAccepted,
      'attStatus': attStatus.index,
      'consentComplete': consentComplete,
      'adMobInitialized': adMobInitialized,
      'canUsePersonalizedAds': canUsePersonalizedAds,
      'lastConsentCheck': lastConsentCheck?.toIso8601String(),
      'initAttempts': initAttempts,
      'lastError': lastError,
      'version': 1, // For future migrations
    };
  }

  factory AdReadinessState.fromJson(Map<String, dynamic> json) {
    try {
      return AdReadinessState(
        privacyAccepted: json['privacyAccepted'] as bool? ?? false,
        attStatus: _parseTrackingStatus(json['attStatus'] as int? ?? 0),
        consentComplete: json['consentComplete'] as bool? ?? false,
        adMobInitialized: json['adMobInitialized'] as bool? ?? false,
        canUsePersonalizedAds: json['canUsePersonalizedAds'] as bool? ?? false,
        lastConsentCheck: json['lastConsentCheck'] != null
            ? DateTime.tryParse(json['lastConsentCheck'] as String)
            : null,
        initAttempts: json['initAttempts'] as int? ?? 0,
        lastError: json['lastError'] as String?,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to parse AdReadinessState: $e');
      return AdReadinessState.initial();
    }
  }

  static TrackingStatus _parseTrackingStatus(int index) {
    if (index >= 0 && index < TrackingStatus.values.length) {
      return TrackingStatus.values[index];
    }
    return TrackingStatus.notDetermined;
  }

  String toJsonString() => jsonEncode(toJson());

  factory AdReadinessState.fromJsonString(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return AdReadinessState.fromJson(json);
    } catch (e) {
      debugPrint('⚠️ Failed to decode AdReadinessState JSON: $e');
      return AdReadinessState.initial();
    }
  }

  @override
  String toString() {
    return 'AdReadinessState('
        'privacyAccepted: $privacyAccepted, '
        'attStatus: ${attStatus.name}, '
        'consentComplete: $consentComplete, '
        'adMobInitialized: $adMobInitialized, '
        'canLoadAds: $canLoadAds'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AdReadinessState &&
        other.privacyAccepted == privacyAccepted &&
        other.attStatus == attStatus &&
        other.consentComplete == consentComplete &&
        other.adMobInitialized == adMobInitialized &&
        other.canUsePersonalizedAds == canUsePersonalizedAds &&
        other.lastConsentCheck == lastConsentCheck &&
        other.initAttempts == initAttempts &&
        other.lastError == lastError;
  }

  @override
  int get hashCode {
    return Object.hash(
      privacyAccepted,
      attStatus,
      consentComplete,
      adMobInitialized,
      canUsePersonalizedAds,
      lastConsentCheck,
      initAttempts,
      lastError,
    );
  }
}
