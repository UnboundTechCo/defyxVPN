import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:defyx_vpn/modules/core/network.dart';
import 'package:defyx_vpn/shared/services/firebase_analytics_service.dart';
import 'package:defyx_vpn/shared/services/ad_analytics_service.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/providers/ad_readiness_coordinator.dart';
import 'package:defyx_vpn/shared/constants/ad_constants.dart';
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

  // Instance state
  bool _isLoading = false;
  bool _hasInitialized = false;
  bool _isPreloading = false;

  // Visual properties
  final Color backgroundColor;
  final double cornerRadius;

  GoogleAdStrategy({required this.backgroundColor, required this.cornerRadius});

  @override
  String get strategyName => 'Google AdMob';

  @override
  Future<void> initialize(Ref ref, {OnFallbackNeeded? onFallbackNeeded}) async {
    debugPrint('🚀 GoogleAdStrategy.initialize() called');

    if (_hasInitialized) {
      debugPrint('   ⚠️ Already initialized, skipping');
      return;
    }

    try {
      // Only supports mobile platforms (Android/iOS)
      if (!(Platform.isAndroid || Platform.isIOS)) {
        debugPrint('⚠️ Google Ads only supported on Android/iOS');
        return;
      }

      // Check if we need to load a new ad
      if (_nativeAd != null) {
        final adsState = ref.read(adsProvider);
        debugPrint(
          '🔍 Cached ad found. State: nativeAdIsLoaded=${adsState.nativeAdIsLoaded}',
        );
        if (adsState.nativeAdIsLoaded) {
          debugPrint('✅ Using existing valid ad');
          _hasInitialized = true;
          return;
        } else {
          debugPrint(
            '⚠️ Cached ad exists but state says not loaded - will reload',
          );
        }
      }

      // Mark as initialized
      _hasInitialized = true;

      // Register disposal callback for countdown expiry
      ref.read(adsProvider.notifier).setAdDisposalCallback(() {
        _disposeAd(ref);
      });
      debugPrint('✅ Registered ad disposal callback');

      // Register rotation callback for ad carousel
      ref.read(adsProvider.notifier).setAdRotationCallback(() {
        _rotateToNextAd(ref);
      });
      debugPrint('✅ Registered ad rotation callback');

      // DON'T load ad on initialization - let connection state changes handle it
      // This prevents race conditions and timing issues
      debugPrint(
        '✅ GoogleAdStrategy initialized (ad will load on connection state change)',
      );
    } catch (e) {
      debugPrint('Error initializing Google ads: $e');
      ref.read(adsProvider.notifier).setAdLoadFailed();
    }
  }

  /// Dispose the current ad instance and clear state
  void _disposeAd(Ref ref) {
    debugPrint('🗑️ Disposing AdMob ads due to countdown expiry');
    if (_nativeAd != null) {
      try {
        _nativeAd!.dispose();
        debugPrint('✅ Current NativeAd disposed successfully');
      } catch (e) {
        debugPrint('⚠️ Error disposing current NativeAd: $e');
      }
      _nativeAd = null;
    }
    
    // Also dispose pre-loaded ad if exists
    if (_nextAd != null) {
      try {
        _nextAd!.dispose();
        debugPrint('✅ Pre-loaded NativeAd disposed successfully');
      } catch (e) {
        debugPrint('⚠️ Error disposing pre-loaded NativeAd: $e');
      }
      _nextAd = null;
    }

    // Reset rotation count for next connection cycle
    ref.read(adsProvider.notifier).resetRotationCount();
  }

  /// Rotate to the next pre-loaded ad (carousel pattern)
  void _rotateToNextAd(Ref ref) {
    debugPrint('🔄 Rotating to next pre-loaded ad');
    
    if (_nextAd == null) {
      debugPrint('⚠️ No pre-loaded ad available for rotation');
      return;
    }

    // Dispose current ad
    if (_nativeAd != null) {
      try {
        _nativeAd!.dispose();
        debugPrint('✅ Disposed previous ad');
      } catch (e) {
        debugPrint('⚠️ Error disposing previous ad: $e');
      }
    }

    // Swap: next ad becomes current
    _nativeAd = _nextAd;
    _nextAd = null;

    // Update state
    ref.read(adsProvider.notifier).incrementRotationCount();
    ref.read(adsProvider.notifier).setNextAdReady(false);
    ref.read(adsProvider.notifier).setAdLoaded(true);

    // Restart countdown for the new ad
    ref.read(adsProvider.notifier).startCountdownTimer();

    debugPrint('✅ Rotation complete - restarted countdown');

    // Pre-load next ad if haven't reached max rotations
    final currentRotation = ref.read(adsProvider).rotationCount;
    if (currentRotation < AdConstants.maxAdsPerCycle) {
      debugPrint('📦 Pre-loading next ad for rotation ${currentRotation + 1}');
      _preloadNextAd(ref);
    } else {
      debugPrint('🏁 Max rotations reached - no more pre-loading');
    }
  }

  /// Pre-load the next ad in the background (for carousel)
  Future<void> _preloadNextAd(Ref ref) async {
    if (_isPreloading) {
      debugPrint('⏳ Pre-load already in progress');
      return;
    }

    _isPreloading = true;

    try {
      debugPrint('📦 Starting pre-load of next ad');
      final result = await _loadAdInstance(ref, isPreload: true);
      
      if (result.success && _nextAd != null) {
        ref.read(adsProvider.notifier).setNextAdReady(true);
        debugPrint('✅ Next ad pre-loaded successfully');
      } else {
        debugPrint('❌ Failed to pre-load next ad: ${result.errorMessage}');
      }
    } catch (e) {
      debugPrint('❌ Error pre-loading next ad: $e');
    } finally {
      _isPreloading = false;
    }
  }

  /// Load ad at a specific position in rotation cycle (for parallel loading)
  ///
  /// This method is used by AdRotationManager to load ads at specific positions.
  /// It returns the NativeAd instance for caching in the rotation manager.
  ///
  /// Parameters:
  /// - position: Ad position in cycle (1-5)
  /// - sessionId: Rotation session ID for analytics tracking
  /// - ref: Riverpod ref for accessing providers
  Future<NativeAd?> loadAdAtPosition({
    required int position,
    required String sessionId,
    required Ref ref,
  }) async {
    final firebaseAnalytics = FirebaseAnalyticsService();
    final adAnalytics = AdAnalyticsService(firebaseAnalytics: firebaseAnalytics);
    
    // Log position load started
    await adAnalytics.logAdPositionLoadStarted(
      position: position,
      sessionId: sessionId,
    );
    
    final loadStartTime = DateTime.now();
    
    // Use existing loadAd logic with force reload for rotation variety
    final result = await loadAd(ref: ref, forceReload: true);
    
    if (result.success && _nativeAd != null) {
      final loadDuration = DateTime.now().difference(loadStartTime);
      
      // Log position load success
      await adAnalytics.logAdPositionLoadSuccess(
        position: position,
        sessionId: sessionId,
        durationMs: loadDuration.inMilliseconds,
      );
      
      return _nativeAd;
    } else {
      // Log position load failure
      await adAnalytics.logAdPositionLoadFailure(
        position: position,
        sessionId: sessionId,
        errorCode: result.errorCode ?? 'UNKNOWN',
        errorMessage: result.errorMessage ?? 'Unknown error',
      );
      
      return null;
    }
  }

  @override
  Future<AdLoadResult> loadAd({required Ref ref, bool forceReload = false}) async {
    // Reset rotation count at start of new connection cycle
    ref.read(adsProvider.notifier).resetRotationCount();
    
    // Load the first ad
    final result = await _loadAdInstance(ref, isPreload: false, forceReload: forceReload);
    
    // If first ad loaded successfully, start pre-loading the next one
    if (result.success && _nativeAd != null) {
      final currentRotation = ref.read(adsProvider).rotationCount;
      if (currentRotation < AdConstants.maxAdsPerCycle) {
        debugPrint('📦 First ad loaded - scheduling pre-load of next ad');
        // Delay pre-load slightly to avoid concurrent requests
        Future.delayed(const Duration(milliseconds: 500), () {
          _preloadNextAd(ref);
        });
      }
    }
    
    return result;
  }

  /// Internal method to load a NativeAd instance (for current or pre-load)
  Future<AdLoadResult> _loadAdInstance(Ref ref, {required bool isPreload, bool forceReload = false}) async {
    final logPrefix = isPreload ? '📦 [PRELOAD]' : '📱 [LOAD]';
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
    // unless forceReload is requested
    if (!isPreload) {
      final adsState = ref.read(adsProvider);
      if (!forceReload &&
          _nativeAd != null &&
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
          ref.read(adsProvider.notifier).setAdLoadFailed(
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
          ref.read(adsProvider.notifier).setAdLoadFailed(
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
        parameters: {'rotation_position': ref.read(adsProvider).rotationCount.toString()},
      );

      // Create template style
      final templateStyle = NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: backgroundColor,
        cornerRadius: cornerRadius,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Colors.blue,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.grey,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.grey.shade700,
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
              // Store in pre-load slot
              _nextAd = ad as NativeAd;
              debugPrint('$logPrefix Stored in pre-load slot');
            } else {
              // Store in current slot
              _nativeAd = ad as NativeAd;
              ref.read(adsProvider.notifier).setAdLoaded(true);
              _isLoading = false;
            }

            // Log success
            analytics.logEvent(
              name: isPreload ? 'ad_preload_success' : 'ad_load_success',
              parameters: {'rotation_position': ref.read(adsProvider).rotationCount.toString()},
            );

            if (!completer.isCompleted) {
              completer.complete(AdLoadResult.success());
            }
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('$logPrefix Ad failed to load: ${error.code} - ${error.message}');
            ad.dispose();
            
            if (!isPreload) {
              _isLoading = false;
              ref.read(adsProvider.notifier).setAdLoadFailed(
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
                'rotation_position': ref.read(adsProvider).rotationCount.toString(),
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
            debugPrint('👆 NativeAd clicked (rotation $rotationPosition)');
            analytics.logEvent(
              name: 'ad_click',
              parameters: {
                'rotation_position': rotationPosition.toString(),
                'shown_on_disconnect': 'true',
              },
            );
          },
          onAdImpression: (ad) {
            final rotationPosition = ref.read(adsProvider).rotationCount;
            debugPrint('👁️ NativeAd impression (rotation $rotationPosition)');
            analytics.logEvent(
              name: 'ad_impression',
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
            
            debugPrint('💰 Ad revenue earned: \$$revenueUsd USD (eCPM: \$$eCPM, rotation: $rotationPosition)');
            
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
          nonPersonalizedAds: !ref
              .read(adReadinessCoordinatorProvider)
              .canUsePersonalizedAds,
          extras: {
            'app_category': 'utilities',
            'app_subcategory': 'vpn',
            'placement': 'main_screen_disconnected',
            ...ref
                .read(adReadinessCoordinatorProvider.notifier)
                .getAdRequestExtras(),
          },
        ),
        nativeTemplateStyle: templateStyle,
      );

      // Load ad
      debugPrint('🚀 Loading ad from AdMob...');
      ad.load();

      // Wait for result with timeout to prevent indefinite blocking
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('⏱️ Ad load timeout after 30 seconds');
          ad.dispose();
          _isLoading = false;
          ref.read(adsProvider.notifier).setAdLoadFailed(
            errorCode: 'TIMEOUT',
            errorMessage: 'Ad load timeout after 30 seconds',
          );
          return AdLoadResult.failure(
            errorCode: 'TIMEOUT',
            errorMessage: 'Ad load timeout after 30 seconds',
          );
        },
      );
    } catch (e) {
      debugPrint('❌ Error creating NativeAd: $e');
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
        debugPrint('❌ Error rendering AdWidget: $e');
        return const SizedBox.shrink();
      }
    }

    return const SizedBox.shrink();
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
      '🔌 GoogleAdStrategy - Connection: ${previous.name} → ${current.name} (hasAd: ${_nativeAd != null})',
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

      // Mark first connection when user connects (for analytics)
      // But don't gate ads on this - show ads immediately

      // Coming from connected state - load fresh ad
      if (previous == ConnectionStatus.connected) {
        debugPrint('🔌 Disconnected after connection - loading fresh AdMob ad');

        if (_isLoading) {
          debugPrint('⏳ Ad load already in progress...');
          return;
        }

        // Dispose old ad if exists (force fresh ad per disconnect cycle)
        if (_nativeAd != null) {
          debugPrint('🗑️ Disposing old AdMob ad to load fresh one');
          ref.read(adsProvider.notifier).setAdLoaded(false);
          try {
            _nativeAd!.dispose();
          } catch (e) {
            debugPrint('⚠️ Error disposing ad: $e');
          }
          _nativeAd = null;
        }

        // Load fresh AdMob ad with real IP
        debugPrint('📱 Loading fresh AdMob ad with real IP');
        loadAd(ref: ref).then((result) {
          if (result.success && _nativeAd != null) {
            debugPrint('⏰ Fresh AdMob ad loaded - starting countdown');
            ref.read(adsProvider.notifier).startCountdownTimer();
          }
        });
      }
      // Initial disconnected state or coming from other states
      else {
        debugPrint(
          '🔌 Disconnected (from other state) - loading AdMob ad if needed',
        );

        // Load ad if we don't have one or it's stale
        if (_nativeAd == null ||
            !adsState.nativeAdIsLoaded ||
            adsState.needsRefresh) {
          if (_isLoading) {
            debugPrint('⏳ Ad load already in progress...');
            return;
          }

          debugPrint('📱 Loading AdMob ad with real IP');
          loadAd(ref: ref).then((result) {
            if (result.success && _nativeAd != null) {
              debugPrint('⏰ AdMob ad loaded - starting countdown');
              ref.read(adsProvider.notifier).startCountdownTimer();
            }
          });
        } else {
          debugPrint('✅ Already have valid ad - starting countdown');
          ref.read(adsProvider.notifier).startCountdownTimer();
        }
      }
      return;
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
    debugPrint('🧹 GoogleAdStrategy disposed');
    // Keep static _nativeAd alive for reuse
  }
}
