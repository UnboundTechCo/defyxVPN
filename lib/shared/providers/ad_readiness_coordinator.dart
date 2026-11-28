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
/// 3. Orchestrates ATT -> UMP -> AdMob initialization
/// 4. Handles state persistence atomically
/// 5. Provides error recovery mechanisms
class AdReadinessCoordinator extends StateNotifier<AdReadinessState> {
  static const String _storageKey = 'ad_readiness_state_v1';

  // ignore: unused_field
  final UmpConsentCacheService? _umpCache;

  // Sets the AdMob SDK up (MobileAds.initialize); replaceable in tests.
  final Future<void> Function() _initializeSdk;

  AdReadinessCoordinator([
    this._umpCache,
    Future<void> Function()? initializeSdk,
  ]) : _initializeSdk = initializeSdk ?? _initializeMobileAds,
       super(AdReadinessState.initial()) {
    _loadPersistedState();
  }

  static Future<void> _initializeMobileAds() async {
    await MobileAds.instance.initialize();
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

        // Android doesn't have ATT - always set to authorized
        if (!Platform.isIOS && state.attStatus != TrackingStatus.authorized) {
          state = state.copyWith(
            attStatus: TrackingStatus.authorized,
            canUsePersonalizedAds: true,
          );
          await _persistState();
        }
        return;
      }

      // Migration path: Check for old scattered keys
      final oldPrivacyShown = prefs.getBool('privacy_notice_shown') ?? false;
      final oldVpnSetup =
          prefs.getBool('ad_personalization_state_vpn_profile_setup') ?? false;
      final oldAttStatus = prefs.getInt('ad_personalization_state_att_status');

      if (oldPrivacyShown || oldVpnSetup || oldAttStatus != null) {
        debugPrint('Migrating old ad state to new format...');

        // Merge old state into new format
        state = AdReadinessState(
          privacyAccepted: oldPrivacyShown || oldVpnSetup,
          attStatus: _parseOldAttStatus(oldAttStatus),
          canUsePersonalizedAds:
              oldAttStatus == TrackingStatus.authorized.index,
          // consentComplete and adMobInitialized stay false - will reinit
        );

        // Persist migrated state
        await _persistState();

        // Clean up old keys
        await prefs.remove('privacy_notice_shown');
        await prefs.remove('ad_personalization_state_vpn_profile_setup');
        await prefs.remove('ad_personalization_state_att_status');
        await prefs.remove('ad_personalization_state_can_personalize');

        debugPrint('Migration complete: $state');
      } else {
        // Fresh install - Android defaults to authorized
        if (!Platform.isIOS) {
          state = state.copyWith(
            attStatus: TrackingStatus.authorized,
            canUsePersonalizedAds: true,
          );
          await _persistState();
        }
      }
    } catch (e, stack) {
      debugPrint('Failed to load ad readiness state: $e');
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
    return Platform.isIOS
        ? TrackingStatus.notDetermined
        : TrackingStatus.authorized;
  }

  /// Persist current state to SharedPreferences
  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, state.toJsonString());
    } catch (e) {
      debugPrint('Failed to persist ad readiness state: $e');
    }
  }

  // === Privacy Flow ===

  /// Mark that user has accepted privacy notice and completed VPN profile setup
  /// This is the entry point after privacy dialog acceptance
  Future<void> markPrivacyAccepted() async {
    state = state.copyWith(
      privacyAccepted: true,
      lastError: null, // Clear any previous errors
    );

    await _persistState();

    debugPrint('Privacy gate unlocked - can now initialize AdMob');
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
      debugPrint('ATT status checked: ${status.name}');
    } catch (e) {
      debugPrint('Failed to check ATT status: $e');
    }
  }

  /// Request ATT authorization (iOS only)
  Future<void> requestATTAuthorization() async {
    if (!Platform.isIOS) return;

    if (state.attStatus != TrackingStatus.notDetermined) {
      debugPrint('ℹ ATT already determined: ${state.attStatus.name}');
      return;
    }

    try {
      debugPrint('Requesting ATT authorization...');
      final status =
          await AppTrackingTransparency.requestTrackingAuthorization();

      state = state.copyWith(
        attStatus: status,
        canUsePersonalizedAds: status == TrackingStatus.authorized,
      );

      await _persistState();
      debugPrint('ATT authorization result: ${status.name}');
    } catch (e) {
      debugPrint('Failed to request ATT authorization: $e');
      state = state.copyWith(lastError: 'ATT request failed: $e');
      await _persistState();
    }
  }

  // === Consent & AdMob Initialization Flow ===

  Future<void>? _adFlow;

  /// Main initialization flow: UMP -> ATT -> AdMob, once per launch.
  /// Called when canInitializeAdMob becomes true, or when the AdMob decision
  /// arrives; a call while the flow is running joins it.
  ///
  /// [onRunUMP] runs the consent refresh and returns whether a consent form
  /// was shown.
  Future<void> initializeAdFlow({
    required Future<bool> Function(bool shouldRequestUMP) onRunUMP,
  }) {
    return _adFlow ??= _runAdFlow(onRunUMP).whenComplete(() => _adFlow = null);
  }

  Future<void> _runAdFlow(
    Future<bool> Function(bool shouldRequestUMP) onRunUMP,
  ) async {
    if (!state.canInitializeAdMob) {
      debugPrint('Cannot initialize AdMob yet: $state');
      return;
    }

    if (state.adMobInitialized) {
      debugPrint('ℹ AdMob already initialized');
      return;
    }

    debugPrint('Starting ad initialization flow...');

    state = state.copyWith(
      initAttempts: state.initAttempts + 1,
      lastError: null,
    );
    await _persistState();

    try {
      // Step 1: Determine if UMP should run and run UMP flow FIRST (GDPR prompt)
      final shouldRequestUMP = _shouldRequestUMP();
      debugPrint(
        '🔍 Should request UMP: $shouldRequestUMP (ATT: ${state.attStatus.name})',
      );

      // Consent the user gave in an earlier session, as UMP itself reports
      // it, already allows ad requests: set AdMob up now, so the first ad
      // loads while the consent refresh below runs (Google's recommended
      // start). Never on a fresh install (UMP has no answer yet) and never
      // before the iOS tracking prompt was answered. If the refresh
      // withdraws the permission or shows a form, whatever loaded meanwhile
      // is dropped below.
      Future<void>? earlyStart;
      if (shouldRequestUMP && await _consentFromEarlierSession()) {
        debugPrint('UMP: consent from an earlier session - AdMob starts now');
        earlyStart = markConsentComplete();
      }

      final formShown = await onRunUMP(shouldRequestUMP);

      // Google's rule: request ads only when UMP says so. False when consent
      // is required but was not collected (e.g. the form failed to load);
      // the next launch asks again.
      if (shouldRequestUMP &&
          !await ConsentInformation.instance.canRequestAds()) {
        debugPrint('UMP: ads may not be requested yet - AdMob stays off');
        if (earlyStart != null) {
          await earlyStart;
          _revokeConsent();
        }
        state = state.copyWith(lastError: 'UMP consent not obtained');
        await _persistState();
        return;
      }

      // A form was shown, so the user's new answer governs: ads loaded with
      // the earlier one are dropped and loaded again with this one.
      if (earlyStart != null && formShown) {
        await earlyStart;
        debugPrint('UMP: consent answered again - reloading AdMob ads');
        _revokeConsent();
      }

      // Step 2: iOS shows the tracking prompt next; let the consent form's
      // dismiss animation finish first.
      if (Platform.isIOS && formShown) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Step 3: ATT permission request SECOND (iOS only)
      if (Platform.isIOS) {
        await checkATTStatus();

        if (state.attStatus == TrackingStatus.notDetermined) {
          await requestATTAuthorization();
        }
      }

      // Step 4: Mark consent flow complete & initialize AdMob SDK
      await markConsentComplete();
    } catch (e, stack) {
      debugPrint('Ad initialization flow failed: $e');
      debugPrint(stack.toString());

      state = state.copyWith(lastError: e.toString());
      await _persistState();

      // Don't throw - allow retry
    }
  }

  /// UMP's own answer from an earlier session, before this launch's refresh:
  /// whether it allows ad requests (consent obtained, or not required where
  /// the user is). On iOS also the tracking prompt must have been answered.
  Future<bool> _consentFromEarlierSession() async {
    if (Platform.isIOS && state.attStatus == TrackingStatus.notDetermined) {
      return false;
    }
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      debugPrint('UMP: earlier consent unknown ($e)');
      return false;
    }
  }

  /// Ads may no longer be requested on the consent they started with: ad
  /// loading stops until the flow completes again, and the App drops the
  /// ads loaded so far.
  void _revokeConsent() {
    state = state.copyWith(consentComplete: false, adMobInitialized: false);
  }

  Future<void>? _completing;

  /// Mark consent flow as complete and initialize AdMob SDK. Calls while
  /// one runs join it.
  Future<void> markConsentComplete() =>
      _completing ??= _completeConsent().whenComplete(() => _completing = null);

  Future<void> _completeConsent() async {
    if (state.consentComplete) {
      debugPrint('ℹ Consent already marked complete');
      return;
    }

    try {
      debugPrint('Marking consent complete - Initializing AdMob SDK...');

      // Initialize AdMob SDK
      await _initializeSdk();

      state = state.copyWith(
        consentComplete: true,
        adMobInitialized: true,
        lastError: null,
        initAttempts: 0, // Reset on success
      );

      await _persistState();

      debugPrint('AdMob initialized successfully - ads can now load');
    } catch (e, stack) {
      debugPrint('Failed to initialize AdMob: $e');
      debugPrint(stack.toString());

      state = state.copyWith(lastError: 'AdMob init failed: $e');
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

  /// Get ad request extras for AdMob. No 'npa': personalization follows the
  /// UMP consent, and the SDK applies the iOS tracking answer itself.
  Map<String, String> getAdRequestExtras() {
    return {'att_status': state.attStatus.name};
  }

  // === Error Recovery ===

  /// Reset initialization state to allow retry
  /// Used when initialization is stuck or failed multiple times
  Future<void> resetInitializationState() async {
    debugPrint('Resetting initialization state...');

    state = state.copyWith(
      consentComplete: false,
      adMobInitialized: false,
      initAttempts: 0,
      lastError: null,
    );

    await _persistState();

    debugPrint('Initialization state reset - ready to retry');
  }

  /// Full reset (for debugging/testing)
  Future<void> resetAll() async {
    debugPrint('FULL RESET - clearing all ad state...');

    state = AdReadinessState.initial();

    if (!Platform.isIOS) {
      state = state.copyWith(
        attStatus: TrackingStatus.authorized,
        canUsePersonalizedAds: true,
      );
    }

    await _persistState();

    debugPrint('Full reset complete');
  }
}

/// Provider for ad readiness coordinator
final adReadinessCoordinatorProvider =
    StateNotifierProvider<AdReadinessCoordinator, AdReadinessState>((ref) {
      final umpCache = ref.watch(umpConsentCacheServiceProvider);
      return AdReadinessCoordinator(umpCache);
    });
