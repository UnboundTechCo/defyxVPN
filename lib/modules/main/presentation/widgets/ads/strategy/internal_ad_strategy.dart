import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:defyx_vpn/app/advertise_director.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/services/firebase_analytics_service.dart';
import '../ads_state.dart';
import '../models/ad_load_result.dart';
import 'ad_loading_strategy.dart';

/// Strategy for loading and displaying internal/custom ads
/// 
/// This strategy handles ads served from the app's own backend,
/// shown during VPN connection (connected state only).
/// Handles internal ads ONLY - does not manage AdMob ads.
class InternalAdStrategy implements AdLoadingStrategy {
  bool _internalAdImageFailed = false;
  final FirebaseAnalyticsService _analytics = FirebaseAnalyticsService();
  
  // Visual properties
  final Color backgroundColor;
  final double cornerRadius;
  
  InternalAdStrategy({
    this.backgroundColor = const Color(0xFF19312F),
    this.cornerRadius = 10.0,
  });
  
  @override
  String get strategyName => 'Internal Ads';
  
  @override
  Future<void> initialize(WidgetRef ref, {OnFallbackNeeded? onFallbackNeeded}) async {
    debugPrint('🚀 InternalAdStrategy.initialize() called');
    debugPrint('🎨 Internal ads strategy initialized');
    // Internal ads don't need fallback callback (they are the fallback)
    
    // DON'T load ad on initialization - let connection state changes handle it
    // This prevents race conditions
    debugPrint('✅ InternalAdStrategy initialized (ad will load on connection state change)');
  }
  
  @override
  Future<AdLoadResult> loadAd({
    required WidgetRef ref,
  }) async {
    try {
      debugPrint('🎨 Loading internal ad for restricted region');
      
      // Track load attempt
      await _analytics.logEvent(
        name: 'ads_internal_ad_load_attempt',
        parameters: {},
      );
      
      // Load ad data from backend
      final adData = await AdvertiseDirector.getRandomCustomAd(ref);
      final imageUrl = adData['imageUrl'] ?? '';
      final clickUrl = adData['clickUrl'] ?? '';
      
      if (imageUrl.isEmpty) {
        debugPrint('⚠️ No internal ad available');
        await _analytics.logEvent(
          name: 'ads_internal_ad_load_failure',
          parameters: {'error_code': 'NO_AD'},
        );
        
        ref.read(adsProvider.notifier).setAdLoadFailed(
          errorCode: 'NO_AD',
          errorMessage: 'No internal ads available',
        );
        return AdLoadResult.failure(
          errorCode: 'NO_AD',
          errorMessage: 'No internal ads available',
        );
      }
      
      debugPrint('✅ Internal ad loaded:');
      debugPrint('   Image: $imageUrl');
      debugPrint('   Click: $clickUrl');
      
      // Track success
      await _analytics.logEvent(
        name: 'ads_internal_ad_load_success',
        parameters: {},
      );
      
      // Reset failure flag for new ad attempt
      _internalAdImageFailed = false;
      ref.read(adsProvider.notifier).setCustomAdData(imageUrl, clickUrl);
      
      return const AdLoadResult.success();
    } catch (e) {
      debugPrint('❌ Failed to load internal ad: $e');
      
      await _analytics.logEvent(
        name: 'ads_internal_ad_load_failure',
        parameters: {'error': e.toString()},
      );
      
      ref.read(adsProvider.notifier).setAdLoadFailed(
        errorCode: 'LOAD_ERROR',
        errorMessage: e.toString(),
      );
      return AdLoadResult.failure(
        errorCode: 'LOAD_ERROR',
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
    final imageUrl = state.customImageUrl ?? '';
    final clickUrl = state.customClickUrl ?? '';
    
    return GestureDetector(
      onTap: () async {
        if (clickUrl.isEmpty) {
          debugPrint('⚠️ No click URL provided for internal ad');
          return;
        }

        try {
          final uri = Uri.parse(clickUrl);
          debugPrint('🔗 Opening internal ad URL: $clickUrl');
          
          // Track click
          final analytics = FirebaseAnalyticsService();
          await analytics.logEvent(
            name: 'ads_internal_ad_clicked',
            parameters: {'click_url': clickUrl},
          );
          
          final canLaunch = await canLaunchUrl(uri);
          if (canLaunch) {
            await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            debugPrint('✅ Internal ad URL opened successfully');
          } else {
            debugPrint('❌ Cannot launch URL: $clickUrl');
          }
        } catch (e) {
          debugPrint('❌ Error opening internal ad URL: $e');
        }
      },
      child: Image.network(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,  // Fill entire space like AdMob ads do
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          
          // Show loading spinner on dark background (same as ad container) to prevent blink
          return Container(
            color: backgroundColor,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.green,
                strokeWidth: 2.0,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ Failed to load internal ad image from: $imageUrl');
          debugPrint('   Error: $error');
          
          // Set local flag and trigger state update to hide widget
          if (!_internalAdImageFailed) {
            _internalAdImageFailed = true;
            
            // Track error
            Future(() {
              final container = ProviderScope.containerOf(context, listen: false);
              final analytics = FirebaseAnalyticsService();
              analytics.logEvent(
                name: 'ads_internal_ad_image_failure',
                parameters: {
                  'image_url': imageUrl,
                  'error': error.toString(),
                },
              );
              
              // Trigger state update to hide the entire widget
              container.read(adsProvider.notifier).setCustomImageLoadFailed();
            });
          }
          
          // Return empty widget - parent will be hidden on next rebuild
          return const SizedBox.shrink();
        },
      ),
    );
  }
  
  @override
  void onConnectionStateChanged({
    required WidgetRef ref,
    required ConnectionStatus previous,
    required ConnectionStatus current,
    required bool hasInitialized,
    required Function() onRefreshNeeded,
  }) {
    debugPrint('📍 InternalAdStrategy - Connection: ${previous.name} → ${current.name}');
    
    // INTERNAL ADS: Show when connected (during VPN use) with VPN IP
    // When connected, load fresh internal ad and show it
    if (current == ConnectionStatus.connected && previous != ConnectionStatus.connected) {
      debugPrint('▶️ Connected - loading fresh internal ad to show during VPN session');
      
      // Mark first connection complete
      ref.read(adsProvider.notifier).markFirstConnectionComplete();
      
      // Load fresh internal ad
      loadAd(ref: ref).then((result) {
        if (result.success) {
          debugPrint('⏰ Fresh internal ad loaded - starting countdown');
          ref.read(adsProvider.notifier).startCountdownTimer();
        }
      });
      return;
    }
    
    // When disconnecting, stop countdown and clear data
    // (GoogleAdStrategy will take over and show AdMob ad)
    if (current == ConnectionStatus.disconnected && 
        previous == ConnectionStatus.connected) {
      debugPrint('⏸️ Disconnected - clearing internal ad (GoogleAdStrategy will show AdMob ad)');
      ref.read(adsProvider.notifier).stopCountdownTimer();
      ref.read(adsProvider.notifier).clearCustomAdData();
    }
  }
  
  @override
  bool shouldLoadNewAd(AdsState state) {
    // Internal ads don't auto-refresh
    return false;
  }
  
  @override
  void dispose() {
    // Nothing to dispose for internal ads
  }
}
