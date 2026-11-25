import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:defyx_vpn/modules/core/network.dart';
import 'package:defyx_vpn/modules/settings/providers/settings_provider.dart';
import 'package:defyx_vpn/shared/services/firebase_analytics_service.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/providers/ad_readiness_coordinator.dart';
import '../ads_state.dart';
import '../models/ad_load_result.dart';
import 'ad_loading_strategy.dart';

/// Helper class to get platform-specific ad unit IDs
class AdHelper {
  static String get adUnitId {
    if (Platform.isAndroid) {
      return dotenv.env['ANDROID_AD_UNIT_ID'] ?? '';
    } else if (Platform.isIOS) {
      return dotenv.env['IOS_AD_UNIT_ID'] ?? '';
    } else {
      return "";
    }
  }
}

/// Google AdMob implementation of AdLoadingStrategy
///
/// Optimized ad loading strategy with carousel/rotation:
/// - Loads ads only when VPN is disconnected (need real IP for targeting)
/// - Implements ad rotation: displays 2-3 ads per disconnect session (25s each)
/// - Pre-loads next ad while current ad is showing (no blank screens)
/// - Maximum 3 ad rotations per connection cycle (conservative UX)
/// - Shows ads only for non-Iranian users
/// - Basic analytics logging
class GoogleAdStrategy implements AdLoadingStrategy {
  // Static ad instances for carousel
  static NativeAd? _nativeAd; // Current ad being displayed
  static NativeAd? _nextAd; // Pre-loaded ad for rotation

  // When each ad loaded, and whether the current one has been seen (AdMob
  // reported an impression). An unseen ad is shown later instead of being
  // thrown away, within AdMob's one-hour limit.
  static DateTime? _nativeAdLoadedAt;
  static bool _nativeAdSeen = false;
  static DateTime? _nextAdLoadedAt;

  // When the last ad's time ran out; the box stays empty at least
  // [adMobDisplaySeconds] after that before [refill] loads another.
  static DateTime? _lastAdEndedAt;
  static const _unseenAdMaxAge = Duration(minutes: 50);

  // Instance state
  bool _isLoading = false;
  bool _hasInitialized = false;
  bool _isPreloading = false;
  bool _disposed = false;
  bool _loadInFlight = false; // one load at a time, whatever triggered it
  AdsNotifier? _adsNotifier;

  // A failed load is tried again while the user stays disconnected: after
  // 20s, then 60s. Only for errors that can pass (internal, network, no
  // fill, mediation no fill); an invalid request would fail the same way.
  static const _retryDelays = [Duration(seconds: 20), Duration(seconds: 60)];
  static const _retryableErrorCodes = {'0', '2', '3', '9'};
  Timer? _retryTimer;
  int _retryAttempt = 0;

  // Visual properties
  final Color backgroundColor;
  final double cornerRadius;

  GoogleAdStrategy({required this.backgroundColor, required this.cornerRadius});

  @override
  String get strategyName => 'Google AdMob';

  @override
  Future<void> initialize(Ref ref, {OnFallbackNeeded? onFallbackNeeded}) async {
    debugPrint('GoogleAdStrategy.initialize() called');

    if (_hasInitialized) {
      debugPrint('Already initialized, skipping');
      return;
    }

    try {
      // Only supports mobile platforms (Android/iOS)
      if (!(Platform.isAndroid || Platform.isIOS)) {
        debugPrint('Google Ads only supported on Android/iOS');
        return;
      }

      // Mark as initialized
      _hasInitialized = true;

      // Register the countdown callbacks, also when reusing a cached ad: this
      // instance may replace an earlier one after the AdMob decision changed.
      final adsNotifier = ref.read(adsProvider.notifier);
      _adsNotifier = adsNotifier;
      adsNotifier.setAdDisposalCallback(() => _disposeAd(ref));
      adsNotifier.setAdRotationCallback(() => _rotateToNextAd(ref));
      adsNotifier.setAdPreloadCallback(() => _preloadNextAd(ref));
      debugPrint('Registered ad disposal, rotation and preload callbacks');

      if (_nativeAd != null && ref.read(adsProvider).nativeAdIsLoaded) {
        debugPrint('Cached ad found and still valid - reusing it');
      }

      // DON'T load ad on initialization - let connection state changes handle it
      // This prevents race conditions and timing issues
      debugPrint(
        'GoogleAdStrategy initialized (ad will load on connection state change)',
      );
    } catch (e) {
      debugPrint('Error initializing Google ads: $e');
      ref.read(adsProvider.notifier).setAdLoadFailed();
    }
  }

  /// Dispose the current ad instance and clear state
  void _disposeAd(Ref ref) {
    _lastAdEndedAt = DateTime.now();
    debugPrint('Disposing AdMob ads due to countdown expiry');
    if (_nativeAd != null) {
      try {
        _nativeAd!.dispose();
        debugPrint('Current NativeAd disposed successfully');
      } catch (e) {
        debugPrint('Error disposing current NativeAd: $e');
      }
      _nativeAd = null;
      _nativeAdLoadedAt = null;
      _nativeAdSeen = false;
    }

    // Also dispose pre-loaded ad if exists
    _disposeNextAd();

    // Reset rotation count for next connection cycle
    ref.read(adsProvider.notifier).resetRotationCount();
  }

  /// Rotate to the next pre-loaded ad (carousel pattern)
  void _rotateToNextAd(Ref ref) {
    debugPrint('Rotating to next pre-loaded ad');

    if (_nextAd == null) {
      debugPrint('No pre-loaded ad available for rotation');
      return;
    }

    // Dispose the previous ad once the box's cross-fade (300ms) has run:
    // disposing it at once left the fading-out half blank.
    final previous = _nativeAd;
    if (previous != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          previous.dispose();
          debugPrint('Disposed previous ad');
        } catch (e) {
          debugPrint('Error disposing previous ad: $e');
        }
      });
    }

    // Swap: next ad becomes current
    _nativeAd = _nextAd;
    _nativeAdLoadedAt = _nextAdLoadedAt;
    _nativeAdSeen = false;
    _nextAd = null;
    _nextAdLoadedAt = null;

    // Update state
    ref.read(adsProvider.notifier).incrementRotationCount();
    ref.read(adsProvider.notifier).setNextAdReady(false);
    ref.read(adsProvider.notifier).setAdLoaded(true);

    // Restart countdown for the new ad. The next one is requested by the
    // countdown shortly before this one's time is up.
    ref
        .read(adsProvider.notifier)
        .startCountdownTimer(seconds: adMobDisplaySeconds);

    debugPrint('Rotation complete - restarted countdown');
  }

  void _disposeNextAd() {
    if (_nextAd == null) return;
    try {
      _nextAd!.dispose();
      debugPrint('Pre-loaded NativeAd disposed successfully');
    } catch (e) {
      debugPrint('Error disposing pre-loaded NativeAd: $e');
    }
    _nextAd = null;
    _nextAdLoadedAt = null;
  }

  /// Shows an ad that loaded but was never seen (the user connected first),
  /// instead of requesting a new one: no wasted request, and an ad on screen
  /// at once. Returns false when there is none still fresh enough.
  bool _showUnseenAd(Ref ref) {
    final now = DateTime.now();
    bool fresh(DateTime? loadedAt) =>
        loadedAt != null && now.difference(loadedAt) < _unseenAdMaxAge;

    final notifier = ref.read(adsProvider.notifier);
    if (_nativeAd != null && !_nativeAdSeen && fresh(_nativeAdLoadedAt)) {
      debugPrint('Showing the unseen AdMob ad loaded earlier');
    } else if (_nextAd != null && fresh(_nextAdLoadedAt)) {
      debugPrint('Showing the unseen pre-loaded AdMob ad');
      try {
        _nativeAd?.dispose();
      } catch (e) {
        debugPrint('Error disposing previous ad: $e');
      }
      _nativeAd = _nextAd;
      _nativeAdLoadedAt = _nextAdLoadedAt;
      _nativeAdSeen = false;
      _nextAd = null;
      _nextAdLoadedAt = null;
    } else {
      return false;
    }

    notifier.resetRotationCount();
    if (_nextAd != null) notifier.setNextAdReady(true);
    notifier.setAdLoaded(true);
    notifier.startCountdownTimer(seconds: adMobDisplaySeconds);
    return true;
  }

  /// Pre-load the next ad in the background (for carousel)
  Future<void> _preloadNextAd(Ref ref) async {
    if (_isPreloading) {
      debugPrint('Pre-load already in progress');
      return;
    }

    _isPreloading = true;

    try {
      debugPrint('Starting pre-load of next ad');
      final result = await _loadAdInstance(ref, isPreload: true);

      if (result.success && _nextAd != null) {
        ref.read(adsProvider.notifier).setNextAdReady(true);
        debugPrint('Next ad pre-loaded successfully');
      } else {
        debugPrint('Failed to pre-load next ad: ${result.errorMessage}');
      }
    } catch (e) {
      debugPrint('Error pre-loading next ad: $e');
    } finally {
      _isPreloading = false;
    }
  }

  @override
  Future<AdLoadResult> loadAd({required Ref ref}) async {
    // Reset rotation count at start of new connection cycle
    ref.read(adsProvider.notifier).resetRotationCount();

    // Load the first ad. The next one is requested by the countdown shortly
    // before rotation, so users who connect right away cost no extra request.
    return _loadAdInstance(ref, isPreload: false);
  }

  /// Internal method to load a NativeAd instance (for current or pre-load)
  Future<AdLoadResult> _loadAdInstance(
    Ref ref, {
    required bool isPreload,
  }) async {
    final logPrefix = isPreload ? '[PRELOAD]' : '[LOAD]';

    // Premium users never see ads; a request would only be thrown away.
    if (ref.read(settingsProvider.notifier).isPremiumCustomer()) {
      debugPrint('$logPrefix Premium user - no ad request');
      return AdLoadResult.failure(
        errorCode: 'PREMIUM',
        errorMessage: 'Premium users see no ads',
      );
    }

    // CRITICAL: Wait for AdMob SDK to be initialized first
    try {
      final versionString = await MobileAds.instance.getVersionString();
      if (versionString.isEmpty) {
        debugPrint('$logPrefix AdMob SDK not initialized yet - skipping');
        return AdLoadResult.failure(
          errorCode: 'SDK_NOT_READY',
          errorMessage: 'AdMob SDK not initialized',
        );
      }
      debugPrint('$logPrefix AdMob SDK ready (version: $versionString)');
    } catch (e) {
      debugPrint('$logPrefix AdMob SDK check failed: $e');
      return AdLoadResult.failure(
        errorCode: 'SDK_NOT_READY',
        errorMessage: 'AdMob SDK not ready: $e',
      );
    }

    // CRITICAL: Check ad readiness (privacy accepted + consent complete + AdMob initialized)
    final adReadiness = ref.read(adReadinessCoordinatorProvider);
    if (!adReadiness.canLoadAds) {
      debugPrint('$logPrefix Ads not ready yet: $adReadiness');
      return AdLoadResult.failure(
        errorCode: 'AD_READINESS_PENDING',
        errorMessage: 'Privacy/consent/initialization not complete',
      );
    }
    debugPrint('$logPrefix Ad readiness verified');

    // CRITICAL: Never load ads while VPN is connected (need real IP for targeting)
    final connectionState = ref.read(connectionStateProvider).status;
    if (connectionState == ConnectionStatus.connected) {
      debugPrint('$logPrefix Skipping - VPN is connected (need real IP)');
      return AdLoadResult.failure(
        errorCode: 'CONNECTED',
        errorMessage: 'Cannot load ads while VPN is connected',
      );
    }

    // For regular load (not preload), check if we already have a valid cached ad
    if (!isPreload) {
      final adsState = ref.read(adsProvider);
      if (_nativeAd != null &&
          adsState.nativeAdIsLoaded &&
          !adsState.needsRefresh) {
        debugPrint('$logPrefix Reusing cached ad (still fresh)');
        return AdLoadResult.success();
      }

      _isLoading = true;

      // Only dispose if we're reloading (ad is stale or failed)
      if (_nativeAd != null) {
        debugPrint('$logPrefix Disposing stale/failed ad before reload');
        ref.read(adsProvider.notifier).setAdLoaded(false);
        try {
          _nativeAd!.dispose();
          debugPrint('$logPrefix Disposed previous ad');
        } catch (e) {
          debugPrint('$logPrefix Error disposing previous ad: $e');
        }
        _nativeAd = null;
      }
    }

    try {
      final adUnitId = AdHelper.adUnitId;

      if (adUnitId.isEmpty) {
        debugPrint('$logPrefix No ad unit ID configured for this platform');
        if (!isPreload) _isLoading = false;

        if (!isPreload) {
          ref
              .read(adsProvider.notifier)
              .setAdLoadFailed(
                errorCode: 'NO_AD_UNIT_ID',
                errorMessage: 'No ad unit ID configured',
              );
        }

        return AdLoadResult.failure(
          errorCode: 'NO_AD_UNIT_ID',
          errorMessage: 'No ad unit ID configured',
        );
      }

      // Check network connectivity
      final network = NetworkStatus();
      final hasNetwork = await network.checkConnectivity();
      if (!hasNetwork) {
        debugPrint('$logPrefix No network connectivity');
        if (!isPreload) {
          _isLoading = false;
          ref
              .read(adsProvider.notifier)
              .setAdLoadFailed(
                errorCode: '2',
                errorMessage: 'Network unavailable',
              );
        }
        return AdLoadResult.failure(
          errorCode: '2',
          errorMessage: 'Network unavailable',
        );
      }

      // Analytics
      final analytics = FirebaseAnalyticsService();
      await analytics.logEvent(
        name: isPreload ? 'ad_preload_attempt' : 'ad_load_attempt',
        parameters: {
          'rotation_position': ref.read(adsProvider).rotationCount.toString(),
        },
      );

      // Create template style
      final templateStyle = NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: backgroundColor,
        cornerRadius: cornerRadius,
        // The card is dark: light text, and the brand yellow for the button
        // so it stands out. (Black and dark grey text were near invisible.)
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF19312F),
          backgroundColor: const Color(0xFFFFC927),
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white70,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white60,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.normal,
          size: 12.0,
        ),
      );

      // Create ad with listener
      final completer = Completer<AdLoadResult>();

      final ad = NativeAd(
        adUnitId: adUnitId,
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            debugPrint('$logPrefix Ad loaded successfully');

            if (isPreload) {
              // Store in pre-load slot, freeing any older pre-loaded ad
              _disposeNextAd();
              _nextAd = ad as NativeAd;
              _nextAdLoadedAt = DateTime.now();
              debugPrint('$logPrefix Stored in pre-load slot');
            } else {
              // Store in current slot
              _nativeAd = ad as NativeAd;
              _nativeAdLoadedAt = DateTime.now();
              _nativeAdSeen = false;
              ref.read(adsProvider.notifier).setAdLoaded(true);
              _isLoading = false;
            }

            // Log success
            analytics.logEvent(
              name: isPreload ? 'ad_preload_success' : 'ad_load_success',
              parameters: {
                'rotation_position': ref
                    .read(adsProvider)
                    .rotationCount
                    .toString(),
              },
            );

            if (!completer.isCompleted) {
              completer.complete(AdLoadResult.success());
            }
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint(
              '$logPrefix Ad failed to load: ${error.code} - ${error.message}',
            );
            ad.dispose();

            if (!isPreload) {
              _isLoading = false;
              ref
                  .read(adsProvider.notifier)
                  .setAdLoadFailed(
                    errorCode: error.code.toString(),
                    errorMessage: error.message,
                  );
            }

            // Log failure
            analytics.logEvent(
              name: isPreload ? 'ad_preload_failure' : 'ad_load_failure',
              parameters: {
                'error_code': error.code.toString(),
                'error_message': error.message,
                'rotation_position': ref
                    .read(adsProvider)
                    .rotationCount
                    .toString(),
              },
            );

            if (!completer.isCompleted) {
              completer.complete(
                AdLoadResult.failure(
                  errorCode: error.code.toString(),
                  errorMessage: error.message,
                ),
              );
            }
          },
          onAdClicked: (ad) {
            final rotationPosition = ref.read(adsProvider).rotationCount;
            debugPrint('NativeAd clicked (rotation $rotationPosition)');
            analytics.logEvent(
              // Not 'ad_click': AdMob logs that itself when linked to Firebase.
              name: 'admob_ad_click',
              parameters: {
                'rotation_position': rotationPosition.toString(),
                'shown_on_disconnect': 'true',
              },
            );
          },
          onAdImpression: (ad) {
            if (identical(ad, _nativeAd)) _nativeAdSeen = true;
            final rotationPosition = ref.read(adsProvider).rotationCount;
            debugPrint('NativeAd impression (rotation $rotationPosition)');
            analytics.logEvent(
              // Not 'ad_impression': AdMob logs that itself (with revenue)
              // when linked to Firebase; the same name would double count.
              name: 'admob_ad_impression',
              parameters: {
                'rotation_position': rotationPosition.toString(),
                'shown_on_disconnect': 'true',
                'ip_consistent': 'true',
              },
            );
          },
          onPaidEvent: (ad, valueMicros, precision, currencyCode) {
            final rotationPosition = ref.read(adsProvider).rotationCount;
            final revenueUsd = valueMicros / 1000000.0;
            final eCPM = revenueUsd * 1000;

            debugPrint(
              'Ad revenue earned: \$$revenueUsd USD (eCPM: \$$eCPM, rotation: $rotationPosition)',
            );

            analytics.logEvent(
              name: 'ad_revenue',
              parameters: {
                'value': revenueUsd.toString(),
                'currency': currencyCode,
                'precision': precision.toString(),
                'ecpm': eCPM.toStringAsFixed(2),
                'rotation_position': rotationPosition.toString(),
                'ad_unit_id': AdHelper.adUnitId,
              },
            );
          },
        ),
        request: AdRequest(
          keywords: [
            // High-value VPN keywords
            'vpn', 'vpn service', 'secure vpn', 'privacy vpn',
            // Security & privacy (high CPM category)
            'online privacy', 'internet security', 'data protection',
            'cybersecurity', 'encryption', 'anonymous browsing',
            // Mobile-specific
            'mobile security', 'smartphone privacy', 'mobile vpn',
            'ios security', 'android security',
            // User intent keywords
            'protect identity', 'hide ip address', 'secure connection',
            'private internet', 'safe browsing',
          ],
          contentUrl: 'https://defyxvpn.com',
          // Personalization follows the UMP consent (the SDK reads it) and,
          // on iOS, the SDK applies the tracking prompt's answer itself.
          // Forcing non-personalized ads on top of that lowered earnings.
          extras: {
            'app_category': 'utilities',
            'app_subcategory': 'vpn',
            'placement': 'main_screen_disconnected',
            ...ref
                .read(adReadinessCoordinatorProvider.notifier)
                .getAdRequestExtras(),
          },
        ),
        // iOS: our own layout (DefyxNativeAdFactory in AppDelegate.swift),
        // since Google's medium template is too tall for the box. Android:
        // the medium template, its layout overridden to fit the box
        // (android/app/src/main/res/layout/gnt_medium_template_view.xml).
        factoryId: Platform.isIOS ? 'defyxNative' : null,
        nativeTemplateStyle: Platform.isIOS ? null : templateStyle,
      );

      // Load ad
      debugPrint('Loading ad from AdMob...');
      ad.load();

      // Wait for result
      return await completer.future;
    } catch (e) {
      debugPrint('Error creating NativeAd: $e');
      _isLoading = false;
      ref
          .read(adsProvider.notifier)
          .setAdLoadFailed(errorCode: '0', errorMessage: e.toString());
      return AdLoadResult.failure(errorCode: '0', errorMessage: e.toString());
    }
  }

  @override
  Widget buildAdWidget({
    required BuildContext context,
    required AdsState state,
    required double cornerRadius,
  }) {
    // Only show AdMob ads (disconnected state only)
    if (_nativeAd != null) {
      try {
        return AdWidget(ad: _nativeAd!);
      } catch (e) {
        debugPrint('Error rendering AdWidget: $e');
        return const SizedBox.shrink();
      }
    }

    return const SizedBox.shrink();
  }

  /// Loads an ad and starts its countdown; on a failure that can pass, tries
  /// again later while the user stays disconnected.
  void _loadAndShow(Ref ref) {
    if (_loadInFlight) return;
    _loadInFlight = true;
    _retryTimer?.cancel();
    loadAd(ref: ref).whenComplete(() => _loadInFlight = false).then((result) {
      if (_disposed) return;
      if (result.success && _nativeAd != null) {
        _retryAttempt = 0;
        debugPrint('AdMob ad loaded - starting countdown');
        ref
            .read(adsProvider.notifier)
            .startCountdownTimer(seconds: adMobDisplaySeconds);
        return;
      }
      _scheduleRetry(ref, result);
    });
  }

  /// Puts an ad in the box when the user comes back to it (app resumed, or
  /// back on the main screen) and it is empty. Ads otherwise load only when
  /// the VPN disconnects, so users returning later saw an empty box. Waits
  /// at least [adMobDisplaySeconds] after the last ad ended, like a rotation.
  void refill(Ref ref) {
    if (_disposed || _isLoading || _loadInFlight) return;
    final adsState = ref.read(adsProvider);
    if (adsState.nativeAdIsLoaded && adsState.showCountdown) return;
    final endedAt = _lastAdEndedAt;
    if (endedAt != null &&
        DateTime.now().difference(endedAt) <
            const Duration(seconds: adMobDisplaySeconds)) {
      return;
    }
    if (!ref.read(adReadinessCoordinatorProvider).canLoadAds) return;

    debugPrint('Ad box empty on return - showing an AdMob ad');
    onConnectionStateChanged(
      ref: ref,
      previous: ConnectionStatus.disconnected,
      current: ConnectionStatus.disconnected,
      hasInitialized: true,
      onRefreshNeeded: () {},
    );
  }

  void _scheduleRetry(Ref ref, AdLoadResult result) {
    if (!_retryableErrorCodes.contains(result.errorCode)) return;
    if (_retryAttempt >= _retryDelays.length) {
      debugPrint('AdMob load failed (${result.errorCode}) - no retries left');
      return;
    }
    final delay = _retryDelays[_retryAttempt++];
    debugPrint(
      'AdMob load failed (${result.errorCode}: ${result.errorMessage}) - '
      'retrying in ${delay.inSeconds}s',
    );
    _retryTimer = Timer(delay, () {
      if (_disposed || _isLoading || _nativeAd != null) return;
      if (ref.read(connectionStateProvider).status !=
          ConnectionStatus.disconnected) {
        return;
      }
      _loadAndShow(ref);
    });
  }

  @override
  void onConnectionStateChanged({
    required Ref ref,
    required ConnectionStatus previous,
    required ConnectionStatus current,
    required bool hasInitialized,
    required Function() onRefreshNeeded,
  }) {
    debugPrint(
      'GoogleAdStrategy connection: ${previous.name} -> ${current.name} (hasAd: ${_nativeAd != null})',
    );

    // When user connects - do nothing (internal ads handle connected state)
    if (current == ConnectionStatus.connected &&
        previous != ConnectionStatus.connected) {
      // GoogleAdStrategy does nothing when connected (InternalAdStrategy handles it)
      return;
    }

    // ADMOB ADS: Show when disconnected with real IP
    // Show ads immediately when disconnected (user has real IP)
    if (current == ConnectionStatus.disconnected) {
      final adsState = ref.read(adsProvider);

      // A new disconnected period gets its own retries.
      _retryTimer?.cancel();
      _retryAttempt = 0;

      if (_isLoading) {
        debugPrint('Ad load already in progress...');
        return;
      }

      // Already on screen (e.g. the ad manager was rebuilt): let it run.
      if (_nativeAd != null &&
          adsState.nativeAdIsLoaded &&
          adsState.showCountdown) {
        debugPrint('AdMob ad already showing');
        return;
      }

      // An ad that loaded but was never seen: show it rather than wasting it.
      if (_showUnseenAd(ref)) return;

      // Otherwise a fresh ad: a seen one earns nothing when shown again.
      if (_nativeAd != null) {
        debugPrint('Disposing the seen AdMob ad to load a fresh one');
        ref.read(adsProvider.notifier).setAdLoaded(false);
        try {
          _nativeAd!.dispose();
        } catch (e) {
          debugPrint('Error disposing ad: $e');
        }
        _nativeAd = null;
        _nativeAdLoadedAt = null;
        _nativeAdSeen = false;
      }

      debugPrint('Loading AdMob ad with real IP');
      _loadAndShow(ref);
    }
  }

  @override
  bool shouldLoadNewAd(AdsState state) {
    // No ad = need to load
    if (_nativeAd == null) return true;

    // Ad not marked as loaded = need to load
    if (!state.nativeAdIsLoaded) return true;

    // Ad exists and loaded = don't load
    return false;
  }

  @override
  void dispose() {
    debugPrint('GoogleAdStrategy disposed');
    _disposed = true;
    _retryTimer?.cancel();
    // The callbacks hold this instance's Ref, which is dead from here on. A
    // replacement strategy registers its own.
    _adsNotifier?.clearAdDisposalCallback();
    _adsNotifier?.clearAdRotationCallback();
    _adsNotifier?.clearAdPreloadCallback();
    // Keep static _nativeAd alive for reuse
  }
}
