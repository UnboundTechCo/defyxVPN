import 'dart:io';
import 'package:defyx_vpn/shared/models/ad_readiness_state.dart';
import 'package:defyx_vpn/shared/services/ump_consent_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

/// Single source of truth for ad readiness and consent flow
/// 
/// Replaces fragmented state management across:
/// - AdPersonalizationProvider
/// - MainScreenLogic privacy_notice_shown
/// - Volatile consent flags
/// 
/// This coordinator:
/// 1. Loads persisted state on creation
/// 2. Provides computed properties for flow control
/// 3. Orchestrates ATT → UMP → AdMob initialization
/// 4. Handles state persistence atomically
/// 5. Provides error recovery mechanisms
class AdReadinessCoordinator extends StateNotifier<AdReadinessState> {
  static const String _storageKey = 'ad_readiness_state_v1';
  
  // ignore: unused_field
  final UmpConsentCacheService? _umpCache; // Reserved for future UMP cache optimization
  
  AdReadinessCoordinator([this._umpCache]) : super(AdReadinessState.initial()) {
    _loadPersistedState();
  }

  // === State Loading & Persistence ===

  /// Load persisted state and migrate from old keys if needed
  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Try loading new state format first
      final stateJson = prefs.getString(_storageKey);
      
      if (stateJson != null) {
        state = AdReadinessState.fromJsonString(stateJson);
        debugPrint('📦 Loaded ad readiness state: $state');
        
        // Android doesn't have ATT - always set to authorized
        if (!Platform.isIOS && state.attStatus != TrackingStatus.authorized) {
          state = state.copyWith(
            attStatus: TrackingStatus.authorized,
            canUsePersonalizedAds: true,
          );
          await _persistState();
          debugPrint('📦 Android: Set ATT to authorized');
        }
        return;
      }

      // Migration path: Check for old scattered keys
      final oldPrivacyShown = prefs.getBool('privacy_notice_shown') ?? false;
      final oldVpnSetup = prefs.getBool('ad_personalization_state_vpn_profile_setup') ?? false;
      final oldAttStatus = prefs.getInt('ad_personalization_state_att_status');
      
      if (oldPrivacyShown || oldVpnSetup || oldAttStatus != null) {
        debugPrint('🔄 Migrating old ad state to new format...');
        
        // Merge old state into new format
        state = AdReadinessState(
          privacyAccepted: oldPrivacyShown || oldVpnSetup,
          attStatus: _parseOldAttStatus(oldAttStatus),
          canUsePersonalizedAds: oldAttStatus == TrackingStatus.authorized.index,
          // consentComplete and adMobInitialized stay false - will reinit
        );
        
        // Persist migrated state
        await _persistState();
        
        // Clean up old keys
        await prefs.remove('privacy_notice_shown');
        await prefs.remove('ad_personalization_state_vpn_profile_setup');
        await prefs.remove('ad_personalization_state_att_status');
        await prefs.remove('ad_personalization_state_can_personalize');
        
        debugPrint('✅ Migration complete: $state');
      } else {
        // Fresh install - Android defaults to authorized
        if (!Platform.isIOS) {
          state = state.copyWith(
            attStatus: TrackingStatus.authorized,
            canUsePersonalizedAds: true,
          );
          await _persistState();
          debugPrint('📦 Fresh install (Android): ATT authorized');
        } else {
          debugPrint('📦 Fresh install (iOS): Awaiting privacy acceptance');
        }
      }
    } catch (e, stack) {
      debugPrint('⚠️ Failed to load ad readiness state: $e');
      debugPrint(stack.toString());
    }
  }

  /// Parse old ATT status from integer index
  TrackingStatus _parseOldAttStatus(int? oldAttStatus) {
    if (oldAttStatus != null && 
        oldAttStatus >= 0 && 
        oldAttStatus < TrackingStatus.values.length) {
      return TrackingStatus.values[oldAttStatus];
    }
    return Platform.isIOS ? TrackingStatus.notDetermined : TrackingStatus.authorized;
  }

  /// Persist current state to SharedPreferences
  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, state.toJsonString());
      debugPrint('💾 Persisted ad readiness state');
    } catch (e) {
      debugPrint('⚠️ Failed to persist ad readiness state: $e');
    }
  }

  // === Privacy Flow ===

  /// Mark that user has accepted privacy notice and completed VPN profile setup
  /// This is the entry point after privacy dialog acceptance
  Future<void> markPrivacyAccepted() async {
    debugPrint('✅ Privacy accepted - marking VPN profile ready');
    
    state = state.copyWith(
      privacyAccepted: true,
      lastError: null, // Clear any previous errors
    );
    
    await _persistState();
    
    debugPrint('🔓 Privacy gate unlocked - can now initialize AdMob');
  }

  // === ATT Flow (iOS) ===

  /// Check ATT authorization status
  Future<void> checkATTStatus() async {
    if (!Platform.isIOS) {
      // Android doesn't have ATT - already set in load
      return;
    }

    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      
      state = state.copyWith(
        attStatus: status,
        canUsePersonalizedAds: status == TrackingStatus.authorized,
      );
      
      await _persistState();
      debugPrint('📱 ATT status checked: ${status.name}');
    } catch (e) {
      debugPrint('⚠️ Failed to check ATT status: $e');
    }
  }

  /// Request ATT authorization (iOS only)
  Future<void> requestATTAuthorization() async {
    if (!Platform.isIOS) return;
    
    if (state.attStatus != TrackingStatus.notDetermined) {
      debugPrint('ℹ️ ATT already determined: ${state.attStatus.name}');
      return;
    }

    try {
      debugPrint('📱 Requesting ATT authorization...');
      final status = await AppTrackingTransparency.requestTrackingAuthorization();
      
      state = state.copyWith(
        attStatus: status,
        canUsePersonalizedAds: status == TrackingStatus.authorized,
      );
      
      await _persistState();
      debugPrint('✅ ATT authorization result: ${status.name}');
    } catch (e) {
      debugPrint('⚠️ Failed to request ATT authorization: $e');
      state = state.copyWith(lastError: 'ATT request failed: $e');
      await _persistState();
    }
  }

  // === Consent & AdMob Initialization Flow ===

  /// Main initialization flow: ATT → UMP → AdMob
  /// Called when canInitializeAdMob becomes true
  Future<void> initializeAdFlow({
    required Future<void> Function(bool shouldRequestUMP) onRunUMP,
  }) async {
    if (!state.canInitializeAdMob) {
      debugPrint('⏸️ Cannot initialize AdMob yet: $state');
      return;
    }

    if (state.adMobInitialized) {
      debugPrint('ℹ️ AdMob already initialized');
      return;
    }

    debugPrint('🚀 Starting ad initialization flow...');
    
    state = state.copyWith(
      initAttempts: state.initAttempts + 1,
      lastError: null,
    );
    await _persistState();

    try {
      // Step 1: ATT (iOS only)
      if (Platform.isIOS) {
        await Future.delayed(const Duration(milliseconds: 500)); // Apple requirement
        await checkATTStatus();
        
        if (state.attStatus == TrackingStatus.notDetermined) {
          await requestATTAuthorization();
        }
      }

      // Step 2: Determine if UMP should run
      final shouldRequestUMP = _shouldRequestUMP();
      debugPrint('🔍 Should request UMP: $shouldRequestUMP (ATT: ${state.attStatus.name})');

      // Step 3: Run UMP flow (external - handled by caller)
      await onRunUMP(shouldRequestUMP);
      
      // onRunUMP will call markConsentComplete when done
      
    } catch (e, stack) {
      debugPrint('❌ Ad initialization flow failed: $e');
      debugPrint(stack.toString());
      
      state = state.copyWith(
        lastError: e.toString(),
      );
      await _persistState();
      
      // Don't throw - allow retry
    }
  }

  /// Mark consent flow as complete and initialize AdMob SDK
  Future<void> markConsentComplete() async {
    if (state.consentComplete) {
      debugPrint('ℹ️ Consent already marked complete');
      return;
    }

    try {
      debugPrint('🎉 Marking consent complete - Initializing AdMob SDK...');
      
      // Initialize AdMob SDK
      await MobileAds.instance.initialize();
      
      state = state.copyWith(
        consentComplete: true,
        adMobInitialized: true,
        lastError: null,
        initAttempts: 0, // Reset on success
      );
      
      await _persistState();
      
      debugPrint('✅ AdMob initialized successfully - ads can now load');
    } catch (e, stack) {
      debugPrint('❌ Failed to initialize AdMob: $e');
      debugPrint(stack.toString());
      
      state = state.copyWith(
        lastError: 'AdMob init failed: $e',
      );
      await _persistState();
    }
  }

  /// Determine if UMP consent should be requested based on ATT status
  bool _shouldRequestUMP() {
    if (!Platform.isIOS) {
      return true; // Android always shows UMP
    }

    // iOS: Don't show UMP if ATT was denied/restricted (Apple compliance)
    // User already declined tracking - respect that choice
    if (state.attStatus == TrackingStatus.denied ||
        state.attStatus == TrackingStatus.restricted) {
      return false;
    }

    // If ATT notDetermined on iOS, we still want to show UMP
    // (ATT dialog may have been dismissed or failed to show)
    return true;
  }

  /// Get ad request extras for AdMob
  Map<String, String> getAdRequestExtras() {
    return {
      'npa': state.canUsePersonalizedAds ? '0' : '1',
      'att_status': state.attStatus.name,
    };
  }

  // === Error Recovery ===

  /// Reset initialization state to allow retry
  /// Used when initialization is stuck or failed multiple times
  Future<void> resetInitializationState() async {
    debugPrint('🔄 Resetting initialization state...');
    
    state = state.copyWith(
      consentComplete: false,
      adMobInitialized: false,
      initAttempts: 0,
      lastError: null,
    );
    
    await _persistState();
    
    debugPrint('✅ Initialization state reset - ready to retry');
  }

  /// Full reset (for debugging/testing)
  Future<void> resetAll() async {
    debugPrint('🔄 FULL RESET - clearing all ad state...');
    
    state = AdReadinessState.initial();
    
    if (!Platform.isIOS) {
      state = state.copyWith(
        attStatus: TrackingStatus.authorized,
        canUsePersonalizedAds: true,
      );
    }
    
    await _persistState();
    
    debugPrint('✅ Full reset complete');
  }
}

/// Provider for ad readiness coordinator
final adReadinessCoordinatorProvider =
    StateNotifierProvider<AdReadinessCoordinator, AdReadinessState>((ref) {
  final umpCache = ref.watch(umpConsentCacheServiceProvider);
  return AdReadinessCoordinator(umpCache);
});
