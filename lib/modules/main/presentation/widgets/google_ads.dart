import 'dart:io';
import 'dart:async';
import 'package:defyx_vpn/app/advertise_director.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
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

  final _adUnitId = AdHelper.adUnitId;

  DateTime? _lastAdRequest;

  @override
  void initState() {
    super.initState();
    debugPrint('GoogleAds widget initState called');

    // Load initial ad on app start (user's real IP guaranteed)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed) return;
      
      // Check if ad is already loaded from previous widget instance
      final adsState = ref.read(googleAdsProvider);
      if (_nativeAd != null && adsState.nativeAdIsLoaded) {
        debugPrint('♻️ Ad already loaded from previous session - reusing');
        _hasInitialized = true;
        return;
      }
      
      if (!_hasInitialized) {
        debugPrint('📱 Loading initial ad with real IP...');
        _initializeAds();
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

  void _initializeAds() async {
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
          debugPrint('♻️ Reusing existing loaded ad');
          return;
        }
        _loadGoogleAd();
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

  void _loadGoogleAd() async {
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
        debugPrint('🗑️ Disposed previous ad');
      } catch (e) {
        debugPrint('⚠️ Error disposing previous ad: $e');
      }
      _nativeAd = null;
    }

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
      );

      if (!_isDisposed && mounted) {
        if (result.success) {
          debugPrint('✅ Ad loaded successfully after ${result.attemptCount} attempt(s)');
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

  void _retryLoadAd() {
    _hasInitialized = false;
    ref.read(googleAdsProvider.notifier).resetState();
    ref.read(shouldShowGoogleAdsProvider.notifier).state = null;
    ref.read(customAdDataProvider.notifier).state = null;
    _initializeAds();
  }

  @override
  void dispose() {
    _isDisposed = true;
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

    // Google ads path
    if (adsState.nativeAdIsLoaded && _nativeAd != null) {
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
      return _buildLoadingWidget("Loading Google ads...");
    } else if (adsState.adLoadFailed) {
      return _buildErrorWidget(adsState);
    } else {
      return _buildErrorWidget(adsState, initialLoad: true);
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 32.sp,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "Failed to load custom ad",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
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

  Widget _buildErrorWidget(GoogleAdsState adsState, {bool initialLoad = false}) {
    final primaryMessage = initialLoad 
        ? "Tap to load ads" 
        : "Tap to retry";
    
    // Never show error details to users - only show user-friendly messages
    final secondaryMessage = initialLoad 
        ? "" 
        : adsState.errorSolution.isNotEmpty 
            ? adsState.errorSolution
            : "Check your connection";
    
    // Log detailed error information for debugging
    if (!initialLoad && adsState.lastErrorCode != null) {
      debugPrint(
        '📊 Ad Error UI - Code: ${adsState.lastErrorCode}, '
        'Retry Count: ${adsState.retryCount}, '
        'Message: ${adsState.lastErrorMessage}'
      );
    }
    
    return GestureDetector(
      onTap: _retryLoadAd,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              initialLoad ? Icons.refresh : Icons.error_outline,
              color: initialLoad
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.orange.withValues(alpha: 0.8),
              size: 32.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              primaryMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (secondaryMessage.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  secondaryMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blue.withValues(alpha: 0.8),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
            // Error codes removed from UI - logged via debugPrint instead
          ],
        ),
      ),
    );
  }
}
