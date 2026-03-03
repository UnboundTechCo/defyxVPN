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
  Future<void> initialize(WidgetRef ref) async {
    if (_hasInitialized) return;

    try {
      // Only supports mobile platforms (Android/iOS)
      if (!(Platform.isAndroid || Platform.isIOS)) {
        debugPrint('⚠️ Google Ads only supported on Android/iOS');
        return;
      }

      // Check if we need to load a new ad
      if (_nativeAd != null) {
        final adsState = ref.read(adsProvider);
        if (adsState.nativeAdIsLoaded) {
          debugPrint('✅ Using existing valid ad');
          _hasInitialized = true;
          return;
        }
      }
      
      // Mark as initialized before starting load process
      _hasInitialized = true;
      await loadAd(ref: ref);
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
    
    // Reset ad loaded state BEFORE disposing to prevent showing disposed ad
    if (_nativeAd != null) {
      ref.read(adsProvider.notifier).setAdLoaded(false);
    }

    _isLoading = true;

    // Dispose previous ad if exists
    if (_nativeAd != null) {
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
        ref.read(adsProvider.notifier).setAdLoadFailed();
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
            analytics.logEvent(name: 'ad_impression', parameters: {});
          },
        ),
        request: const AdRequest(),
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
    // Check _nativeAd directly, not state (avoid race condition on restart)
    if (_nativeAd != null) {
      // Wrap in try-catch to prevent red error screens from disposed ads
      try {
        return AdWidget(ad: _nativeAd!);
      } catch (e) {
        // Log error but don't show technical details to users
        debugPrint('❌ Error rendering AdWidget: $e');
        return const SizedBox.shrink();
      }
    } else {
      // No ad available - parent widget will hide the container
      return const SizedBox.shrink();
    }
  }
  
  @override
  void onConnectionStateChanged({
    required WidgetRef ref,
    required ConnectionStatus previous,
    required ConnectionStatus current,
    required bool hasInitialized,
    required Function() onRefreshNeeded,
  }) {
    debugPrint('🔌 Connection: ${previous.name} → ${current.name} (hasAd: ${_nativeAd != null})');
    
    // When disconnected, load ad if we don't have one
    if (current == ConnectionStatus.disconnected && 
        previous == ConnectionStatus.connected) {
      debugPrint('🔌 Disconnected');
      
      final adsState = ref.read(adsProvider);
      
      // Load ad if we don't have one or previous load failed
      if (_nativeAd == null || !adsState.nativeAdIsLoaded) {
        if (_isLoading) {
          debugPrint('⏳ Ad load already in progress...');
          return;
        }
        
        debugPrint('📱 Loading ad with real IP');
        _hasInitialized = false;
        initialize(ref);
      }
      return;
    }
    
    // When connecting, start countdown if we have an ad
    if (current == ConnectionStatus.connected && 
        previous != ConnectionStatus.connected) {
      
      final adsState = ref.read(adsProvider);
      
      if (_isLoading) {
        debugPrint('⏳ Ad is loading...');
        return;
      }
      
      if (!adsState.nativeAdIsLoaded) {
        debugPrint('⚠️ No ad available');
        return;
      }
      
      // Start countdown
      debugPrint('⏰ Starting countdown');
      ref.read(adsProvider.notifier).startCountdownTimer();
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
