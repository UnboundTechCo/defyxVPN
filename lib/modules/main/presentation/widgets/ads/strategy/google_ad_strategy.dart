import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:defyx_vpn/modules/core/network.dart';
import 'package:defyx_vpn/shared/services/firebase_analytics_service.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
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
/// Simple, direct ad loading strategy:
/// - Loads ads only when VPN is disconnected (need real IP for targeting)
/// - No retries (fail fast)
/// - No caching (fresh ad on each load)
/// - No rate limiting (AdMob SDK handles it)
/// - Basic analytics logging
class GoogleAdStrategy implements AdLoadingStrategy {
  // Static ad instance for cross-widget reuse
  static NativeAd? _nativeAd;
  
  // Instance state
  bool _isLoading = false;
  bool _hasInitialized = false;
  OnFallbackNeeded? _onFallbackNeeded;
  
  // Visual properties
  final Color backgroundColor;
  final double cornerRadius;
  
  GoogleAdStrategy({
    required this.backgroundColor,
    required this.cornerRadius,
  });
  
  @override
  String get strategyName => 'Google AdMob';
  
  @override
  Future<void> initialize(WidgetRef ref, {OnFallbackNeeded? onFallbackNeeded}) async {
    debugPrint('🚀 GoogleAdStrategy.initialize() called');
    _onFallbackNeeded = onFallbackNeeded;
    
    if (_hasInitialized) {
      debugPrint('   ⚠️ Already initialized, skipping');
      return;
    }

    try {
      // Only supports mobile platforms (Android/iOS)
      if (!(Platform.isAndroid || Platform.isIOS)) {
        debugPrint('⚠️ Google Ads only supported on Android/iOS - triggering fallback');
        _onFallbackNeeded?.call();
        return;
      }

      // Check if we need to load a new ad
      if (_nativeAd != null) {
        final adsState = ref.read(adsProvider);
        debugPrint('🔍 Cached ad found. State: nativeAdIsLoaded=${adsState.nativeAdIsLoaded}');
        if (adsState.nativeAdIsLoaded) {
          debugPrint('✅ Using existing valid ad');
          _hasInitialized = true;
          return;
        } else {
          debugPrint('⚠️ Cached ad exists but state says not loaded - will reload');
        }
      }
      
      // Mark as initialized
      _hasInitialized = true;
      
      // DON'T load ad on initialization - let connection state changes handle it
      // This prevents race conditions and timing issues
      debugPrint('✅ GoogleAdStrategy initialized (ad will load on connection state change)');
    } catch (e) {
      debugPrint('Error initializing Google ads: $e');
      ref.read(adsProvider.notifier).setAdLoadFailed();
    }
  }
  
  @override
  Future<AdLoadResult> loadAd({
    required WidgetRef ref,
  }) async {
    // CRITICAL: Never load ads while VPN is connected (need real IP for targeting)
    final connectionState = ref.read(connectionStateProvider).status;
    if (connectionState == ConnectionStatus.connected) {
      debugPrint('⚠️ Skipping ad load - VPN is connected (need real IP)');
      return AdLoadResult.failure(
        errorCode: 'CONNECTED',
        errorMessage: 'Cannot load ads while VPN is connected',
      );
    }
    
    // Check if we already have a valid cached ad
    final adsState = ref.read(adsProvider);
    if (_nativeAd != null && adsState.nativeAdIsLoaded && !adsState.needsRefresh) {
      debugPrint('✅ Reusing cached ad (still fresh)');
      return AdLoadResult.success();
    }

    _isLoading = true;

    // Only dispose if we're reloading (ad is stale or failed)
    if (_nativeAd != null) {
      debugPrint('🔄 Disposing stale/failed ad before reload');
      ref.read(adsProvider.notifier).setAdLoaded(false);
      try {
        _nativeAd!.dispose();
        debugPrint('🗑️ Disposed previous ad');
      } catch (e) {
        debugPrint('⚠️ Error disposing previous ad: $e');
      }
      _nativeAd = null;
    }

    try {
      final adUnitId = AdHelper.adUnitId;
      
      if (adUnitId.isEmpty) {
        debugPrint('❌ No ad unit ID configured for this platform');
        _isLoading = false;
        ref.read(adsProvider.notifier).setAdLoadFailed(
          errorCode: 'NO_AD_UNIT_ID',
          errorMessage: 'No ad unit ID configured',
        );
        
        // Trigger fallback - this is an unrecoverable configuration error
        debugPrint('🔄 No ad unit ID - triggering fallback to internal ads');
        _onFallbackNeeded?.call();
        
        return AdLoadResult.failure(
          errorCode: 'NO_AD_UNIT_ID',
          errorMessage: 'No ad unit ID configured',
        );
      }

      // Check network connectivity
      final network = NetworkStatus();
      final hasNetwork = await network.checkConnectivity();
      if (!hasNetwork) {
        debugPrint('🔴 No network connectivity');
        _isLoading = false;
        ref.read(adsProvider.notifier).setAdLoadFailed(
          errorCode: '2',
          errorMessage: 'Network unavailable',
        );
        // Don't trigger fallback for temporary network issues
        // User can reconnect and try again
        debugPrint('⏳ Network issue - will retry when connection restored (no fallback)');
        return AdLoadResult.failure(
          errorCode: '2',
          errorMessage: 'Network unavailable',
        );
      }
      
      // Analytics
      final analytics = FirebaseAnalyticsService();
      await analytics.logEvent(name: 'ad_load_attempt', parameters: {});
      
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
            debugPrint('✅ Ad loaded successfully');
            _isLoading = false;
            _nativeAd = ad as NativeAd;
            ref.read(adsProvider.notifier).setAdLoaded(true);
            
            // Log success
            analytics.logEvent(name: 'ad_load_success', parameters: {});
            
            if (!completer.isCompleted) {
              completer.complete(AdLoadResult.success());
            }
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('❌ Ad failed to load: ${error.code} - ${error.message}');
            ad.dispose();
            _isLoading = false;
            
            ref.read(adsProvider.notifier).setAdLoadFailed(
              errorCode: error.code.toString(),
              errorMessage: error.message,
            );
            
            // Log failure
            analytics.logEvent(
              name: 'ad_load_failure',
              parameters: {
                'error_code': error.code.toString(),
                'error_message': error.message,
              },
            );
            
            // Trigger fallback to internal ads for actual AdMob serving failures
            // This is when AdMob SDK tried but couldn't serve an ad
            debugPrint('🔄 AdMob failed to serve ad (error ${error.code}) - triggering fallback to internal ads');
            _onFallbackNeeded?.call();
            
            if (!completer.isCompleted) {
              completer.complete(AdLoadResult.failure(
                errorCode: error.code.toString(),
                errorMessage: error.message,
              ));
            }
          },
          onAdClicked: (ad) {
            debugPrint('👆 NativeAd clicked');
          },
          onAdImpression: (ad) {
            debugPrint('👁️ NativeAd impression');
            analytics.logEvent(name: 'ad_impression', parameters: {
              'shown_on_disconnect': 'true',
              'ip_consistent': 'true',
            });
          },
        ),
        request: const AdRequest(
          keywords: ['privacy', 'security', 'technology', 'mobile', 'internet safety', 'data protection'],
          contentUrl: 'defyxvpn://home',
        ),
        nativeTemplateStyle: templateStyle,
      );
      
      // Load ad
      debugPrint('🚀 Loading ad from AdMob...');
      ad.load();
      
      // Wait for result
      return await completer.future;
    } catch (e) {
      debugPrint('❌ Error creating NativeAd: $e');
      _isLoading = false;
      ref.read(adsProvider.notifier).setAdLoadFailed(
        errorCode: '0',
        errorMessage: e.toString(),
      );
      return AdLoadResult.failure(
        errorCode: '0',
        errorMessage: e.toString(),
      );
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
    required WidgetRef ref,
    required ConnectionStatus previous,
    required ConnectionStatus current,
    required bool hasInitialized,
    required Function() onRefreshNeeded,
  }) {
    debugPrint('🔌 GoogleAdStrategy - Connection: ${previous.name} → ${current.name} (hasAd: ${_nativeAd != null})');
    
    // Mark first connection complete when user connects (track for UX)
    if (current == ConnectionStatus.connected && previous != ConnectionStatus.connected) {
      ref.read(adsProvider.notifier).markFirstConnectionComplete();
      debugPrint('✅ First connection marked - AdMob ads will show on disconnect');
      // GoogleAdStrategy does nothing when connected (InternalAdStrategy handles it)
      return;
    }
    
    // ADMOB ADS: Show when disconnected (after VPN use) with real IP
    // Only load ads AFTER user has completed first connection
    if (current == ConnectionStatus.disconnected) {
      final adsState = ref.read(adsProvider);
      
      // Don't show ads before first connection (better UX)
      if (!adsState.hasCompletedFirstConnection) {
        debugPrint('🔌 Disconnected but no first connection yet - showing tips only');
        return;
      }
      
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
        debugPrint('🔌 Disconnected (from other state) - loading AdMob ad if needed');
        
        // Load ad if we don't have one or it's stale
        if (_nativeAd == null || !adsState.nativeAdIsLoaded || adsState.needsRefresh) {
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
