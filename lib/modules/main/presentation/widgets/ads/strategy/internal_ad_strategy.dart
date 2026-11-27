import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:defyx_vpn/app/advertise_director.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/providers/premium_provider.dart';
import 'package:defyx_vpn/shared/services/firebase_analytics_service.dart';
import '../ads_state.dart';
import '../internal_ad_view.dart';
import '../models/ad_load_result.dart';
import 'ad_loading_strategy.dart';

/// Strategy for loading and displaying internal/custom ads
///
/// This strategy handles ads served from the app's own backend.
/// Shows ads ONLY when VPN is connected (all users, including Iranian users).
///
/// Behavior:
/// - Connected state: Load and display internal ad with 60s countdown
/// - Disconnected state: Clear ad data (GoogleAdStrategy handles disconnected for non-Iranian users)
/// - Iranian users: Will see internal ads only when connected, nothing when disconnected
///
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
  Future<void> initialize(Ref ref, {OnFallbackNeeded? onFallbackNeeded}) async {
    // Internal ads don't need fallback callback (they are the fallback)

    // DON'T load ad on initialization - let connection state changes handle it
    // This prevents race conditions
  }

  @override
  Future<AdLoadResult> loadAd({required Ref ref}) async {
    // Premium users see no ads, in-house ones included.
    if (!ref.read(adsAllowedProvider)) {
      return const AdLoadResult.failure(
        errorCode: 'PREMIUM',
        errorMessage: 'No ads for premium users',
      );
    }

    try {
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
        await _analytics.logEvent(
          name: 'ads_internal_ad_load_failure',
          parameters: {'error_code': 'NO_AD'},
        );

        ref
            .read(adsProvider.notifier)
            .setAdLoadFailed(
              errorCode: 'NO_AD',
              errorMessage: 'No internal ads available',
            );
        return AdLoadResult.failure(
          errorCode: 'NO_AD',
          errorMessage: 'No internal ads available',
        );
      }

      // Validate URL format before using it (safety check for iOS network issue)
      if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
        await _analytics.logEvent(
          name: 'ads_internal_ad_load_failure',
          parameters: {'error_code': 'INVALID_URL', 'url': imageUrl},
        );

        ref
            .read(adsProvider.notifier)
            .setAdLoadFailed(
              errorCode: 'INVALID_URL',
              errorMessage: 'Invalid ad URL format',
            );
        return AdLoadResult.failure(
          errorCode: 'INVALID_URL',
          errorMessage: 'Invalid ad URL format: $imageUrl',
        );
      }

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
      debugPrint('Failed to load internal ad: $e');

      await _analytics.logEvent(
        name: 'ads_internal_ad_load_failure',
        parameters: {'error': e.toString()},
      );

      ref
          .read(adsProvider.notifier)
          .setAdLoadFailed(errorCode: 'LOAD_ERROR', errorMessage: e.toString());
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

    // Validate URL format before rendering (defensive check to prevent iOS file:/// error)
    // CRITICAL: Never pass empty or malformed URLs to Image.network on iOS
    // iOS incorrectly resolves empty strings as file:/// URIs causing crashes
    if (imageUrl.isEmpty ||
        (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://'))) {
      if (imageUrl.isNotEmpty) {
        debugPrint(
          'Invalid URL in buildAdWidget, refusing to render: $imageUrl',
        );
      }
      return const SizedBox.shrink();
    }

    return InternalAdView(
      imageUrl: imageUrl,
      backgroundColor: backgroundColor,
      onTap: () => _openClickUrl(clickUrl),
      onImageError: (error) => _handleImageError(context, imageUrl, error),
    );
  }

  Future<void> _openClickUrl(String clickUrl) async {
    if (clickUrl.isEmpty) {
      debugPrint('No click URL provided for internal ad');
      return;
    }

    try {
      final uri = Uri.parse(clickUrl);
      debugPrint('Opening internal ad URL: $clickUrl');

      await _analytics.logEvent(
        name: 'ads_internal_ad_clicked',
        parameters: {'click_url': clickUrl},
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('Internal ad URL opened successfully');
      } else {
        debugPrint('Cannot launch URL: $clickUrl');
      }
    } catch (e) {
      debugPrint('Error opening internal ad URL: $e');
    }
  }

  /// Hides the ad box when its picture cannot be loaded. Runs once per ad.
  void _handleImageError(BuildContext context, String imageUrl, Object error) {
    debugPrint('Failed to load internal ad image from: $imageUrl');
    debugPrint('   Error: $error');

    if (_internalAdImageFailed) return;
    _internalAdImageFailed = true;

    // Deferred: this runs while the image widget is building.
    Future(() {
      if (!context.mounted) return;
      final container = ProviderScope.containerOf(context, listen: false);
      _analytics.logEvent(
        name: 'ads_internal_ad_image_failure',
        parameters: {'image_url': imageUrl, 'error': error.toString()},
      );

      // Clear all ad data so the container disappears completely
      debugPrint('Clearing ad data due to image load failure');
      container.read(adsProvider.notifier).clearCustomAdData();
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
      'InternalAdStrategy connection: ${previous.name} -> ${current.name}',
    );

    // INTERNAL ADS: Show when connected (all users including Iranian)
    // When connected, load fresh internal ad and show it
    if (current == ConnectionStatus.connected &&
        previous != ConnectionStatus.connected) {
      debugPrint(
        'Connected - will load internal ad after network routing stabilizes',
      );

      // iOS FIX: Add delay to allow VPN network routing to fully establish
      // Without this delay, Image.network may incorrectly resolve HTTPS URLs as file:// URIs
      // causing "No host specified in URI file:///..." errors on first connection
      // Also allows time for VPN tunnel to stabilize (tun2socks, ping refresh, SSL/TLS)
      Future.delayed(const Duration(milliseconds: 2500), () {
        debugPrint(
          'Network routing delay complete (2.5s) - loading fresh internal ad',
        );

        // Load fresh internal ad
        loadAd(ref: ref).then((result) {
          if (result.success) {
            debugPrint('Fresh internal ad loaded - starting countdown');
            ref.read(adsProvider.notifier).startCountdownTimer();
          }
        });
      });
      return;
    }

    // When disconnecting, stop countdown and clear data (all users)
    // For non-Iranian users: GoogleAdStrategy will show AdMob ad
    // For Iranian users: Nothing will show (they don't have GoogleAdStrategy)
    if (current == ConnectionStatus.disconnected &&
        previous == ConnectionStatus.connected) {
      debugPrint('Disconnected - clearing internal ad');
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
