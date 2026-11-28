import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:defyx_vpn/modules/core/network.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/shared/services/firebase_analytics_service.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/providers/ad_readiness_coordinator.dart';
import 'package:defyx_vpn/shared/providers/premium_provider.dart';
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
/// AdMob ads show from the moment the user taps connect:
/// - While the tunnel is down (app start, after a disconnect, back in the
///   app) one ad is loaded and held, unseen: the request goes out with the
///   real IP.
/// - The tap (disconnected / error / no internet -> loading) shows it. The
///   impression fires before the tunnel is up, so with the real IP too.
/// - It stays through connecting and connected for [adMobDisplaySeconds], so
///   a fast connection doesn't cut it short, then hides.
/// - No requests after the tap: once the tunnel is up AdMob's traffic leaves
///   through the VPN (AppProxy on Android, the tunnel on iOS). So no
///   rotation either.
/// - Disconnecting removes it and loads the next one.
///
/// Only where AdMob is on; see AdStrategyManager.
class GoogleAdStrategy implements AdLoadingStrategy {
  // The held (or shown) ad. Static, so it survives a strategy rebuild.
  static NativeAd? _nativeAd;
  static DateTime? _nativeAdLoadedAt;
  static bool _nativeAdSeen = false; // AdMob reported an impression
  // Whether the ad is on screen now, and whether one was shown since the
  // tunnel was last down (the manager shows an in-house ad when not).
  static bool _shownNow = false;
  static bool _shownThisConnection = false;
  // AdMob: show an ad within an hour of loading it.
  static const _maxHeldAge = Duration(minutes: 50);

  bool _hasInitialized = false;
  bool _disposed = false;
  bool _loadInFlight = false; // one load at a time, whatever triggered it
  AdsNotifier? _adsNotifier;

  // A failed load is tried again while the tunnel stays down: after 20s,
  // then 60s. Only for errors that can pass (internal, network, no fill,
  // mediation no fill); an invalid request would fail the same way.
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

  /// States in which the tunnel carries no traffic, so a request goes out
  /// with the real IP.
  static bool _tunnelDown(ConnectionStatus status) =>
      status == ConnectionStatus.disconnected ||
      status == ConnectionStatus.error;

  /// Tests: hold [ad] as if it had just loaded.
  @visibleForTesting
  static void debugHoldAd(NativeAd? ad) {
    _nativeAd = ad;
    _nativeAdLoadedAt = ad == null ? null : DateTime.now();
    _nativeAdSeen = false;
    _shownNow = false;
    _shownThisConnection = false;
  }

  /// Whether an AdMob ad is on screen.
  bool get isShowingAd => _shownNow && _nativeAd != null;

  /// Whether an AdMob ad was shown for the current connection.
  bool get shownThisConnection => _shownThisConnection;

  bool get _hasFreshUnseenAd {
    final loadedAt = _nativeAdLoadedAt;
    return _nativeAd != null &&
        !_nativeAdSeen &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < _maxHeldAge;
  }

  bool _isShowing(Ref ref) {
    final state = ref.read(adsProvider);
    return _nativeAd != null && state.nativeAdIsLoaded && state.showCountdown;
  }

  @override
  Future<void> initialize(Ref ref, {OnFallbackNeeded? onFallbackNeeded}) async {
    if (_hasInitialized) return;
    if (!(Platform.isAndroid || Platform.isIOS)) {
      debugPrint('Google Ads only supported on Android/iOS');
      return;
    }
    _hasInitialized = true;

    // The shown ad's countdown ends in here. (No rotation: it would need a
    // request after the tap.)
    final adsNotifier = ref.read(adsProvider.notifier);
    _adsNotifier = adsNotifier;
    adsNotifier.setAdDisposalCallback(() => _onShownAdEnded(ref));
  }

  /// The shown ad's time is up: remove it, and load the next one if the
  /// tunnel is down (otherwise that happens on disconnect).
  void _onShownAdEnded(Ref ref) {
    // The countdown is shared: an in-house ad's end must not drop the held
    // AdMob ad.
    if (!_shownNow) return;
    _shownNow = false;
    debugPrint('AdMob ad time is up');
    _releaseAd();
    preload(ref);
  }

  /// Drops the current ad; disposes it once the box has faded it out.
  void _releaseAd() {
    final ad = _nativeAd;
    _nativeAd = null;
    _nativeAdLoadedAt = null;
    _nativeAdSeen = false;
    if (ad == null) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        ad.dispose();
      } catch (e) {
        debugPrint('Error disposing NativeAd: $e');
      }
    });
  }

  /// Makes sure an unseen ad is ready for the next connect tap. Requests
  /// only while the tunnel is down, so with the real IP.
  void preload(Ref ref) {
    if (_disposed || _loadInFlight) return;
    if (!_tunnelDown(ref.read(connectionStateProvider).status)) return;
    if (_isShowing(ref) || _hasFreshUnseenAd) return;
    if (_nativeAd != null) _releaseAd(); // seen, or too old to show

    _loadInFlight = true;
    _retryTimer?.cancel();
    _loadAdInstance(ref).whenComplete(() => _loadInFlight = false).then((
      result,
    ) {
      if (_disposed) return;
      if (result.success) {
        _retryAttempt = 0;
        // Tapped connect while it loaded: show it now, the tunnel is not up
        // yet (that comes with analyzing/connected).
        if (ref.read(connectionStateProvider).status ==
            ConnectionStatus.loading) {
          _showHeldAd(ref);
        }
        return;
      }
      _scheduleRetry(ref, result);
    });
  }

  /// Shows the held ad, if a fresh one is ready. Never requests one: the
  /// tunnel may come up any moment.
  void _showHeldAd(Ref ref) {
    if (_isShowing(ref)) return;
    if (!_hasFreshUnseenAd) {
      debugPrint('Connect tapped - no AdMob ad ready');
      return;
    }
    debugPrint('Connect tapped - showing the held AdMob ad');
    _shownNow = true;
    _shownThisConnection = true;
    final notifier = ref.read(adsProvider.notifier);
    notifier.resetRotationCount();
    notifier.setAdLoaded(true);
    notifier.startCountdownTimer(seconds: adMobDisplaySeconds);
  }

  /// Hides a shown ad and frees it.
  void _hide(Ref ref) {
    _shownNow = false;
    final notifier = ref.read(adsProvider.notifier);
    notifier.stopCountdownTimer();
    notifier.setAdLoaded(false);
    _releaseAd();
  }

  /// Loads an ad and holds it (does not show it).
  @override
  Future<AdLoadResult> loadAd({required Ref ref}) => _loadAdInstance(ref);

  Future<AdLoadResult> _loadAdInstance(Ref ref) async {
    const logPrefix = '[LOAD]';

    // Premium users never see ads (nor users whose status is not known yet);
    // a request would only be thrown away.
    if (!ref.read(adsAllowedProvider)) {
      debugPrint('$logPrefix Premium or unknown premium status - no request');
      return AdLoadResult.failure(
        errorCode: 'PREMIUM',
        errorMessage: 'No ads for premium users',
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

    // CRITICAL: requests only with the real IP - never once connecting.
    if (!_tunnelDown(ref.read(connectionStateProvider).status)) {
      debugPrint(
        '$logPrefix Skipping - connecting or connected (need real IP)',
      );
      return AdLoadResult.failure(
        errorCode: 'CONNECTED',
        errorMessage: 'Ads load only while the VPN is down',
      );
    }

    // The app's own state can lag behind the VPN: reopened while the VPN
    // still runs, it starts as "disconnected" until the status check. Ask
    // the VPN itself right before the request.
    try {
      if (await VpnBridge().getVpnStatus() == 'connected') {
        debugPrint('$logPrefix Skipping - the VPN is up (need real IP)');
        return AdLoadResult.failure(
          errorCode: 'CONNECTED',
          errorMessage: 'Ads load only while the VPN is down',
        );
      }
    } catch (e) {
      debugPrint('$logPrefix VPN status unknown ($e) - no request');
      return AdLoadResult.failure(
        errorCode: 'VPN_STATUS_UNKNOWN',
        errorMessage: 'VPN status unknown',
      );
    }

    try {
      final adUnitId = AdHelper.adUnitId;
      if (adUnitId.isEmpty) {
        debugPrint('$logPrefix No ad unit ID configured for this platform');
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
        return AdLoadResult.failure(
          errorCode: '2',
          errorMessage: 'Network unavailable',
        );
      }

      // Analytics
      final analytics = FirebaseAnalyticsService();
      await analytics.logEvent(
        name: 'ad_load_attempt',
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

            // Hold it, unseen, for the connect tap.
            _nativeAd = ad as NativeAd;
            _nativeAdLoadedAt = DateTime.now();
            _nativeAdSeen = false;

            // Log success
            analytics.logEvent(
              name: 'ad_load_success',
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

            // Log failure
            analytics.logEvent(
              name: 'ad_load_failure',
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
                'shown_on_connect': 'true',
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
                'shown_on_connect': 'true',
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
      return AdLoadResult.failure(errorCode: '0', errorMessage: e.toString());
    }
  }

  @override
  Widget buildAdWidget({
    required BuildContext context,
    required AdsState state,
    required double cornerRadius,
  }) {
    final ad = _nativeAd;
    if (ad == null) return const SizedBox.shrink();
    try {
      return AdWidget(ad: ad);
    } catch (e) {
      debugPrint('Error rendering AdWidget: $e');
      return const SizedBox.shrink();
    }
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
      if (!_disposed) preload(ref);
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
      'GoogleAdStrategy connection: ${previous.name} -> ${current.name} '
      '(held: ${_nativeAd != null})',
    );

    // The connect tap.
    if (current == ConnectionStatus.loading &&
        (previous == ConnectionStatus.disconnected ||
            previous == ConnectionStatus.error ||
            previous == ConnectionStatus.noInternet)) {
      _retryTimer?.cancel();
      _showHeldAd(ref);
      return;
    }

    // The tunnel is down again (disconnected, or the connection failed):
    // the shown ad goes, and the next one loads with the real IP.
    if (_tunnelDown(current)) {
      _retryTimer?.cancel();
      _retryAttempt = 0;
      _shownThisConnection = false;
      if (_isShowing(ref)) _hide(ref);
      preload(ref);
    }
  }

  @override
  bool shouldLoadNewAd(AdsState state) => !_hasFreshUnseenAd;

  @override
  void dispose() {
    debugPrint('GoogleAdStrategy disposed');
    _disposed = true;
    _retryTimer?.cancel();
    // The callback holds this instance's Ref, which is dead from here on. A
    // replacement strategy registers its own.
    _adsNotifier?.clearAdDisposalCallback();
    // Keep static _nativeAd alive for reuse
  }
}
