import 'dart:io';
import 'dart:async';
import 'package:defyx_vpn/app/advertise_director.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/services/ad_cache_service.dart';
import 'package:defyx_vpn/shared/services/ad_service.dart';
import 'package:defyx_vpn/shared/services/ad_refresh_strategy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

const int _countdownDuration = 60;

Future<bool> _shouldShowGoogleAds(WidgetRef ref) async {
  final shouldUseInternalAds =
      await AdvertiseDirector.shouldUseInternalAds(ref);
  return !shouldUseInternalAds;
}

class GoogleAdsState {
  final bool nativeAdIsLoaded;
  final bool adLoadFailed;
  final int countdown;
  final bool showCountdown;
  final DateTime? adLoadedAt;
  final int retryCount;
  final String? lastErrorCode;
  final String? lastErrorMessage;

  const GoogleAdsState({
    this.nativeAdIsLoaded = false,
    this.adLoadFailed = false,
    this.countdown = _countdownDuration,
    this.showCountdown = true,
    this.adLoadedAt,
    this.retryCount = 0,
    this.lastErrorCode,
    this.lastErrorMessage,
  });

  GoogleAdsState copyWith({
    bool? nativeAdIsLoaded,
    bool? adLoadFailed,
    int? countdown,
    bool? showCountdown,
    DateTime? adLoadedAt,
    int? retryCount,
    String? lastErrorCode,
    String? lastErrorMessage,
  }) {
    return GoogleAdsState(
      nativeAdIsLoaded: nativeAdIsLoaded ?? this.nativeAdIsLoaded,
      adLoadFailed: adLoadFailed ?? this.adLoadFailed,
      countdown: countdown ?? this.countdown,
      showCountdown: showCountdown ?? this.showCountdown,
      adLoadedAt: adLoadedAt ?? this.adLoadedAt,
      retryCount: retryCount ?? this.retryCount,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
    );
  }

  // Check if ad needs refresh (older than 15 minutes)
  bool get needsRefresh {
    if (adLoadedAt == null) return true;
    final age = DateTime.now().difference(adLoadedAt!);
    return age.inMinutes >= 15;
  }

  String get errorSolution {
    if (lastErrorCode == null) return '';
    switch (lastErrorCode) {
      case '0':
        return 'Internal SDK error - will retry automatically';
      case '1':
        return 'Invalid ad request - check Ad Unit ID configuration';
      case '2':
        return 'Network error - check internet connection';
      case '3':
        return 'No ad inventory available - normal occurrence';
      default:
        return 'Unknown error - check logs for details';
    }
  }
}

class GoogleAdsNotifier extends StateNotifier<GoogleAdsState> {
  GoogleAdsNotifier() : super(const GoogleAdsState());
  Timer? _countdownTimer;

  void startCountdownTimer() {
    if (_countdownTimer != null && _countdownTimer!.isActive) {
      return;
    }

    _countdownTimer?.cancel();
    state = state.copyWith(
      countdown: _countdownDuration,
      showCountdown: true,
    );
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.countdown > 0) {
        state = state.copyWith(countdown: state.countdown - 1);
      } else {
        state = state.copyWith(
          showCountdown: false,
          // Keep ad loaded - just hide it until next connection
        );
        timer.cancel();
      }
    });
  }

  void setAdLoaded(bool isLoaded) {
    debugPrint('✅ Ad loaded: $isLoaded');
    state = state.copyWith(
      nativeAdIsLoaded: isLoaded,
      adLoadFailed: false,
      adLoadedAt: isLoaded ? DateTime.now() : null,
    );
  }

  void setAdLoadFailed({String? errorCode, String? errorMessage, int? retryCount}) {
    state = state.copyWith(
      adLoadFailed: true,
      nativeAdIsLoaded: false,
      lastErrorCode: errorCode,
      lastErrorMessage: errorMessage,
      retryCount: retryCount ?? state.retryCount,
    );
  }

  void resetState() {
    state = const GoogleAdsState();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}

final googleAdsProvider =
    StateNotifierProvider<GoogleAdsNotifier, GoogleAdsState>((ref) {
  return GoogleAdsNotifier();
});

final adsLoadTriggerProvider = StateProvider<int>((ref) => 0);

final shouldShowGoogleAdsProvider = StateProvider<bool?>((ref) => null);

final customAdDataProvider = StateProvider<Map<String, String>?>((ref) => null);

class GoogleAds extends ConsumerStatefulWidget {
  final Color backgroundColor;
  final double cornerRadius;

  const GoogleAds({
    super.key,
    this.backgroundColor = Colors.white,
    this.cornerRadius = 10.0,
  });

  @override
  ConsumerState<GoogleAds> createState() => _GoogleAdsState();
}

class AdHelper {
  static String get adUnitId {
    if (Platform.isAndroid) {
      return dotenv.env['ANDROID_AD_UNIT_ID'] ?? '';
    } else if (Platform.isIOS) {
      return dotenv.env['IOS_AD_UNIT_ID'] ?? '';
    } else {
      return "";
      // throw UnsupportedError('Unsupported platform');
    }
  }
}

class _GoogleAdsState extends ConsumerState<GoogleAds> {
  static NativeAd? _nativeAd;
  bool _isLoading = false;
  bool _isDisposed = false;
  bool _hasInitialized = false;
  Timer? _autoRetryTimer;

  final _adUnitId = AdHelper.adUnitId;

  DateTime? _lastAdRequest;

  @override
  void initState() {
    super.initState();
    debugPrint('GoogleAds widget initState called');

    // Load initial ad on app start (user's real IP guaranteed)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed) return;
      
      // Validate if ad is still valid from previous widget instance
      final adsState = ref.read(googleAdsProvider);
      bool isAdValid = false;
      
      if (_nativeAd != null) {
        try {
          // Try to access ad properties to verify it's not disposed
          // ignore: unnecessary_null_checks
          final _ = _nativeAd!.hashCode;
          isAdValid = true;
          debugPrint('♻️ Ad from previous session is still valid - reusing');
          
          // Sync state to match reality - ad is valid so mark as loaded
          if (!adsState.nativeAdIsLoaded) {
            debugPrint('🔄 Syncing state: ad is valid but state was reset');
            ref.read(googleAdsProvider.notifier).setAdLoaded(true);
          }
        } catch (e) {
          debugPrint('⚠️ Previous ad was disposed during app closure - clearing');
          _nativeAd = null;
          // Force complete state reset
          ref.read(googleAdsProvider.notifier).resetState();
        }
      }
      
      // If ad is valid, reuse it - don't check state since we just synced it
      if (isAdValid) {
        _hasInitialized = true;
        debugPrint('✅ Reusing valid ad from previous session');
        return;
      }
      
      // Load fresh ad if none exists or previous was invalid
      if (!_hasInitialized) {
        // Check cache metadata to decide whether to load immediately or delay
        _checkCacheAndLoad();
      }
    });

    // Smart ad refresh & countdown management
    ref.listenManual(connectionStateProvider, (previous, next) {
      final adsState = ref.read(googleAdsProvider);
      final refreshStrategy = ref.read(adRefreshStrategyProvider);
      
      // Record connection for activity tracking
      if (next.status == ConnectionStatus.connected && 
          previous?.status != ConnectionStatus.connected) {
        refreshStrategy.recordConnection();
      }
      
      // When disconnected, check if ad needs refresh using adaptive strategy
      if (next.status == ConnectionStatus.disconnected && 
          previous?.status == ConnectionStatus.connected &&
          adsState.nativeAdIsLoaded &&
          refreshStrategy.shouldRefreshAd() &&
          !_isDisposed) {
        
        // Check 60s throttle to comply with AdMob policy
        final now = DateTime.now();
        if (_lastAdRequest != null) {
          final timeSinceLastRequest = now.difference(_lastAdRequest!);
          if (timeSinceLastRequest.inSeconds < 60) {
            debugPrint('⏱️ Skipping ad refresh - only ${timeSinceLastRequest.inSeconds}s since last request');
            return;
          }
        }
        
        debugPrint('🔄 Ad refresh triggered by adaptive strategy');
        _lastAdRequest = now;
        _hasInitialized = false;
        _initializeAds();
        return;
      }
      
      // Start countdown when connected (reuse existing ad)
      if (next.status == ConnectionStatus.connected && 
          previous?.status != ConnectionStatus.connected &&
          adsState.nativeAdIsLoaded &&
          !_isDisposed) {
        debugPrint('▶️ Starting 60s countdown for ad impression');
        ref.read(googleAdsProvider.notifier).startCountdownTimer();
      }
    });
  }

  void _initializeAds({bool bypassRateLimit = false}) async {
    if (_isDisposed || _hasInitialized) return;

    _hasInitialized = true;

    try {
      // Disable Google Ads on non-mobile platforms.
      if (!(Platform.isAndroid || Platform.isIOS)) {
        final customAdData = await AdvertiseDirector.getRandomCustomAd(ref);
        if (!_isDisposed) {
          ref.read(shouldShowGoogleAdsProvider.notifier).state = false;
          ref.read(customAdDataProvider.notifier).state = customAdData;
          ref.read(googleAdsProvider.notifier).setAdLoaded(true);
        }
        return;
      }

      final shouldShowGoogle = await _shouldShowGoogleAds(ref);

      if (_isDisposed) return;

      ref.read(shouldShowGoogleAdsProvider.notifier).state = shouldShowGoogle;

      if (shouldShowGoogle) {
        // Check if static ad already exists and is still valid
        final adsState = ref.read(googleAdsProvider);
        if (_nativeAd != null && adsState.nativeAdIsLoaded && !adsState.needsRefresh) {
          // Verify ad is actually valid before reusing
          try {
            // ignore: unnecessary_null_checks
            final _ = _nativeAd!.hashCode;
            debugPrint('♻️ Reusing existing loaded ad (age: ${DateTime.now().difference(adsState.adLoadedAt!).inMinutes}min)');
            return;
          } catch (e) {
            debugPrint('⚠️ Existing ad became invalid - loading fresh ad');
            _nativeAd = null;
            ref.read(googleAdsProvider.notifier).resetState();
          }
        }
        _loadGoogleAd(bypassRateLimit: bypassRateLimit);
        return;
      }

      final customAdData = await AdvertiseDirector.getRandomCustomAd(ref);
      if (!_isDisposed) {
        ref.read(customAdDataProvider.notifier).state = customAdData;
        ref.read(googleAdsProvider.notifier).setAdLoaded(true);
      }
    } catch (e) {
      debugPrint('Error initializing ads: $e');
      if (!_isDisposed) {
        ref.read(googleAdsProvider.notifier).setAdLoadFailed();
      }
    }
  }

  void _loadGoogleAd({bool bypassRateLimit = false}) async {
    if (_isDisposed) return;

    // Reset ad loaded state BEFORE disposing to prevent showing disposed ad
    if (_nativeAd != null) {
      ref.read(googleAdsProvider.notifier).setAdLoaded(false);
    }

    setState(() {
      _isLoading = true;
    });

    // Dispose previous ad only if exists
    if (_nativeAd != null) {
      try {
        _nativeAd!.dispose();
        debugPrint('🗑️ Disposed previous ad to load fresh ad');
      } catch (e) {
        debugPrint('⚠️ Error disposing previous ad: $e');
      }
      _nativeAd = null;
    }
    
    // Clear any cached ad data to force fresh ad
    debugPrint('🔄 Requesting fresh ad from AdMob...');

    try {
      if (_adUnitId.isEmpty) {
        // No ad unit id available for this platform; fall back to custom ads.
        final customAdData = await AdvertiseDirector.getRandomCustomAd(ref);
        if (!_isDisposed) {
          ref.read(shouldShowGoogleAdsProvider.notifier).state = false;
          ref.read(customAdDataProvider.notifier).state = customAdData;
          ref.read(googleAdsProvider.notifier).setAdLoaded(true);
        }
        return;
      }

      // Use AdService for network checks and retry logic
      final adService = ref.read(adServiceProvider);
      
      // Create template style
      final templateStyle = NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: widget.backgroundColor,
        cornerRadius: widget.cornerRadius,
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

      // Create listener for AdService
      final listener = NativeAdListener(
        onAdLoaded: (ad) {
          if (!_isDisposed && mounted) {
            setState(() {
              _isLoading = false;
            });
            _nativeAd = ad as NativeAd;
            debugPrint('✅ New ad loaded and cached (hashCode: ${_nativeAd!.hashCode})');
            ref.read(googleAdsProvider.notifier).setAdLoaded(true);
            
            // Record ad load time for adaptive refresh strategy
            ref.read(adRefreshStrategyProvider).recordAdLoad();
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!_isDisposed && mounted) {
            setState(() {
              _isLoading = false;
            });
            // Error is already logged by AdService
          }
        },
        onAdClicked: (ad) {
          debugPrint('👆 NativeAd clicked');
          adService.logAdEvent('clicked', {});
        },
        onAdImpression: (ad) {
          debugPrint('👁️ NativeAd impression recorded');
          // Already logged by AdService
        },
      );

      // Load ad with retry logic via AdService
      debugPrint('🚀 Loading ad with AdService retry logic...');
      final result = await adService.loadAdWithRetry(
        adUnitId: _adUnitId,
        listener: listener,
        templateStyle: templateStyle,
        bypassRateLimit: bypassRateLimit,
      );

      if (!_isDisposed && mounted) {
        if (result.success) {
          debugPrint('✅ Ad loaded successfully after ${result.attemptCount} attempt(s)');
          _autoRetryTimer?.cancel();
        } else {
          debugPrint('❌ Ad failed to load after ${result.attemptCount} attempts: ${result.errorMessage}');
          setState(() {
            _isLoading = false;
          });
          ref.read(googleAdsProvider.notifier).setAdLoadFailed(
            errorCode: result.errorCode,
            errorMessage: result.errorMessage,
            retryCount: result.attemptCount,
          );
          
          // Auto-retry after cooldown for rate limit or no-fill errors
          if (result.errorCode == 'RATE_LIMIT' || result.errorCode == '3') {
            _scheduleAutoRetry();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error creating NativeAd: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
        });
        ref.read(googleAdsProvider.notifier).setAdLoadFailed(
          errorCode: '0',
          errorMessage: e.toString(),
        );
      }
    }
  }

  Future<void> _checkCacheAndLoad() async {
    if (_isDisposed) return;
    
    try {
      // Check if we have cached metadata about recent load attempts
      final cacheService = ref.read(adCacheServiceProvider);
      final metadata = await cacheService.loadMetadata();
      
      if (metadata != null && metadata.lastErrorCode != null) {
        final timeSinceError = DateTime.now().difference(metadata.loadedAt);
        
        // If we recently had a "no fill" error (code 3), delay the next attempt
        if (metadata.lastErrorCode == '3' && timeSinceError.inSeconds < 300) {
          // Had no-fill error less than 5 minutes ago - delay loading
          final delaySeconds = 120 - timeSinceError.inSeconds;
          if (delaySeconds > 0) {
            debugPrint('📊 Cache shows recent no-fill error - delaying load by ${delaySeconds}s');
            await Future.delayed(Duration(seconds: delaySeconds));
          }
        }
      }
      
      // Proceed with normal load
      debugPrint('📱 Loading fresh ad with real IP...');
      _initializeAds();
    } catch (e) {
      debugPrint('⚠️ Cache check failed, loading immediately: $e');
      _initializeAds();
    }
  }

  void _scheduleAutoRetry() {
    _autoRetryTimer?.cancel();
    
    final adService = ref.read(adServiceProvider);
    final rateLimitWait = adService.getTimeUntilRateLimitReset();
    
    // Always respect the 60-second rate limit for auto-retries
    Duration waitDuration;
    
    if (rateLimitWait != null && rateLimitWait.inSeconds > 0) {
      // Rate limit is active, wait for it to reset
      waitDuration = rateLimitWait;
      debugPrint('⏰ Auto-retry scheduled in ${waitDuration.inSeconds}s (rate limit cooldown)...');
    } else {
      // No active rate limit, but still wait 60s minimum to avoid hitting it
      waitDuration = const Duration(seconds: 60);
      debugPrint('⏰ Auto-retry scheduled in 60s (respecting rate limit)...');
    }
    
    _autoRetryTimer = Timer(waitDuration, () {
      if (!_isDisposed && mounted) {
        debugPrint('⏱️ Auto-retry triggered after ${waitDuration.inSeconds}s wait');
        _retryLoadAd(isAutoRetry: true);
      }
    });
  }

  void _retryLoadAd({bool isAutoRetry = false}) {
    debugPrint('🔄 ${isAutoRetry ? "Auto" : "Manual"} retry triggered - clearing all state');
    _hasInitialized = false;
    _autoRetryTimer?.cancel();
    
    // Dispose current ad if exists
    if (_nativeAd != null) {
      try {
        _nativeAd!.dispose();
        debugPrint('🗑️ Disposed ad before retry');
      } catch (e) {
        debugPrint('⚠️ Error disposing ad on retry: $e');
      }
      _nativeAd = null;
    }
    
    ref.read(googleAdsProvider.notifier).resetState();
    ref.read(shouldShowGoogleAdsProvider.notifier).state = null;
    ref.read(customAdDataProvider.notifier).state = null;
    _initializeAds(bypassRateLimit: !isAutoRetry); // Manual retries bypass rate limit
  }

  @override
  void dispose() {
    _isDisposed = true;
    _autoRetryTimer?.cancel();
    // Keep static _nativeAd alive across navigation for ad reuse
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adsState = ref.watch(googleAdsProvider);
    final shouldShowGoogle = ref.watch(shouldShowGoogleAdsProvider);
    final customAdData = ref.watch(customAdDataProvider);

    return SizedBox(
      height: 280.h,
      width: 336.w,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: widget.backgroundColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(widget.cornerRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.cornerRadius),
              child: _buildAdContent(adsState, shouldShowGoogle, customAdData),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 10.w,
                vertical: 4.h,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(widget.cornerRadius),
                  bottomLeft: Radius.circular(3.r),
                ),
              ),
              child: Text(
                "ADVERTISEMENT",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          if (adsState.showCountdown)
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10.w,
                  vertical: 4.h,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(widget.cornerRadius),
                    topRight: Radius.circular(3.r),
                  ),
                ),
                child: Text(
                  "Closing in ${adsState.countdown}s",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdContent(GoogleAdsState adsState, bool? shouldShowGoogle,
      Map<String, String>? customAdData) {
    if (shouldShowGoogle == null) {
      return _buildLoadingWidget("Initializing ads...");
    }

    // Custom ads path
    if (!shouldShowGoogle) {
      return _buildCustomAdContent(customAdData, adsState);
    }

    // Google ads path - check _nativeAd directly, not state (avoid race condition on restart)
    if (_nativeAd != null) {
      // Wrap in try-catch to prevent red error screens from disposed ads
      try {
        return AdWidget(ad: _nativeAd!);
      } catch (e) {
        // Log error but don't show technical details to users
        debugPrint('❌ Error rendering AdWidget: $e');
        // Reset state and show loading instead
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed && mounted) {
            ref.read(googleAdsProvider.notifier).setAdLoaded(false);
            setState(() {
              _isLoading = true;
            });
          }
        });
        return _buildLoadingWidget("Preparing ad...");
      }
    } else if (_isLoading) {
      return _buildLoadingWidget("Loading ads...");
    } else if (adsState.adLoadFailed) {
      // Silent auto-retry in background - just show loading state
      debugPrint('🔄 Ad failed - auto-retry running in background');
      return _buildLoadingWidget("Loading ads...");
    } else {
      // Initial load state
      return _buildLoadingWidget("Preparing ads...");
    }
  }

  Widget _buildCustomAdContent(
      Map<String, String>? customAdData, GoogleAdsState adsState) {
    return Stack(
      children: [
        if (customAdData == null)
          _buildLoadingWidget("Loading ads...")
        else
          _buildCustomAdWidget(customAdData),
      ],
    );
  }

  Widget _buildCustomAdWidget(Map<String, String> customAdData) {
    final imageUrl = customAdData['imageUrl'] ?? '';

    if (imageUrl.isNotEmpty) {
      return GestureDetector(
        onTap: () {
          final clickUrl = customAdData['clickUrl'] ?? '';
          if (clickUrl.isNotEmpty) {
            launchUrl(Uri.parse(clickUrl));
          }
        },
        child: Image.network(
          imageUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                color: Colors.green,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Custom ad image load error: $error');
            // Silent error - just show loading state instead
            return Center(
              child: CircularProgressIndicator(
                color: Colors.green,
                strokeWidth: 2,
              ),
            );
          },
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Custom Ad Placeholder",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              "No image URL provided",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildLoadingWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.green),
          SizedBox(height: 8.h),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
