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
/// typically used for restricted regions where Google AdMob is not available.
class InternalAdStrategy implements AdLoadingStrategy {
  bool _internalAdImageFailed = false;
  final FirebaseAnalyticsService _analytics = FirebaseAnalyticsService();
  
  @override
  String get strategyName => 'Internal Ads';
  
  @override
  Future<void> initialize(WidgetRef ref, {OnFallbackNeeded? onFallbackNeeded}) async {
    debugPrint('🎨 Internal ads strategy initialized');
    // Internal ads don't need fallback callback (they are the fallback)
    
    // Load the initial ad
    await loadAd(ref: ref);
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
      child: Container(
        child: Image.network(
          imageUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,  // Show full image without cropping
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.green,
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
    // Stop countdown when VPN disconnects (from any non-disconnected state)
    if (current == ConnectionStatus.disconnected && 
        previous != ConnectionStatus.disconnected) {
      debugPrint('⏸️ Stopping countdown for internal ad (disconnected)');
      ref.read(adsProvider.notifier).stopCountdownTimer();
    }
    
    // Start countdown when VPN connects
    if (current == ConnectionStatus.connected && 
        previous != ConnectionStatus.connected) {
      debugPrint('▶️ Starting countdown for internal ad');
      ref.read(adsProvider.notifier).startCountdownTimer();
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
