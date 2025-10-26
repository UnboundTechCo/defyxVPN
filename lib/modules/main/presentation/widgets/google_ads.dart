import 'dart:io';
import 'dart:async';
import 'package:defyx_vpn/app/advertise_director.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

const int _countdownDuration = 60;

Future<bool> _shouldShowGoogleAds(WidgetRef ref) async {
  final shouldUseInternalAds = await AdvertiseDirector.shouldUseInternalAds(ref);
  return !shouldUseInternalAds;
}

class GoogleAdsState {
  final bool nativeAdIsLoaded;
  final int countdown;
  final bool showCountdown;
  final bool shouldDisposeAd;
  final bool adLoadFailed;

  const GoogleAdsState({
    this.nativeAdIsLoaded = false,
    this.countdown = _countdownDuration,
    this.showCountdown = true,
    this.shouldDisposeAd = false,
    this.adLoadFailed = false,
  });

  GoogleAdsState copyWith({
    bool? nativeAdIsLoaded,
    int? countdown,
    bool? showCountdown,
    bool? shouldDisposeAd,
    bool? adLoadFailed,
  }) {
    return GoogleAdsState(
      nativeAdIsLoaded: nativeAdIsLoaded ?? this.nativeAdIsLoaded,
      countdown: countdown ?? this.countdown,
      showCountdown: showCountdown ?? this.showCountdown,
      shouldDisposeAd: shouldDisposeAd ?? this.shouldDisposeAd,
      adLoadFailed: adLoadFailed ?? this.adLoadFailed,
    );
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
      shouldDisposeAd: false,
    );
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.countdown > 0) {
        state = state.copyWith(countdown: state.countdown - 1);
      } else {
        state = state.copyWith(
          showCountdown: false,
          shouldDisposeAd: true,
          nativeAdIsLoaded: false,
        );
        timer.cancel();
      }
    });
  }

  void setAdLoaded(bool isLoaded) {
    debugPrint('Ad loaded: $isLoaded');
    state = state.copyWith(
      nativeAdIsLoaded: isLoaded,
      adLoadFailed: false,
    );
    if (isLoaded && state.showCountdown && state.countdown == _countdownDuration) {
      startCountdownTimer();
    }
  }

  void setAdLoadFailed() {
    state = state.copyWith(
      adLoadFailed: true,
      nativeAdIsLoaded: false,
    );
  }

  void acknowledgeDisposal() {
    state = state.copyWith(shouldDisposeAd: false);
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

final googleAdsProvider = StateNotifierProvider<GoogleAdsNotifier, GoogleAdsState>((ref) {
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
  // Returns null on unsupported platforms (desktop/web), so callers can
  // gracefully skip Google ads and fall back to custom ads.
  static String? get adUnitId {
    if (Platform.isAndroid) {
      return dotenv.env['ANDROID_AD_UNIT_ID'];
    } else if (Platform.isIOS) {
      return dotenv.env['IOS_AD_UNIT_ID'];
    }
    return null;
  }
}

class _GoogleAdsState extends ConsumerState<GoogleAds> {
  NativeAd? _nativeAd;
  bool _isLoading = false;
  bool _isDisposed = false;
  bool _hasInitialized = false;

  final String? _adUnitId = AdHelper.adUnitId;

  @override
  void initState() {
    super.initState();
    debugPrint('GoogleAds widget initState called');

    // Reset state when widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        debugPrint('Resetting Google ads state...');
        ref.read(googleAdsProvider.notifier).resetState();
        _initializeAds();
      }
    });
  }

  void _initializeAds() async {
    if (_isDisposed || _hasInitialized) return;

    try {
      final shouldShowGoogle = await _shouldShowGoogleAds(ref);

      if (_isDisposed) return;

      ref.read(shouldShowGoogleAdsProvider.notifier).state = shouldShowGoogle;

      if (shouldShowGoogle) {
        // If we don't have an ad unit ID (e.g., desktop), fall back to custom ad path.
        if (_adUnitId == null || _adUnitId.isEmpty) {
          final customAdData = await AdvertiseDirector.getRandomCustomAd(ref);
          if (!_isDisposed) {
            ref.read(customAdDataProvider.notifier).state = customAdData;
            ref.read(googleAdsProvider.notifier).setAdLoaded(true);
            ref.read(shouldShowGoogleAdsProvider.notifier).state = false;
          }
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

    setState(() {
      _isLoading = true;
    });

    // Dispose previous ad
    _nativeAd?.dispose();
    _nativeAd = null;

    try {
      // Guard: If ad unit is unavailable on this platform, don't attempt to load.
      if (_adUnitId == null || _adUnitId.isEmpty) {
        if (!_isDisposed && mounted) {
          setState(() {
            _isLoading = false;
          });
          ref.read(googleAdsProvider.notifier).setAdLoadFailed();
        }
        return;
      }
      _nativeAd = NativeAd(
        adUnitId: _adUnitId,
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            if (!_isDisposed && mounted) {
              setState(() {
                _isLoading = false;
              });
              ref.read(googleAdsProvider.notifier).setAdLoaded(true);
            }
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (!_isDisposed && mounted) {
              setState(() {
                _isLoading = false;
              });
              ref.read(googleAdsProvider.notifier).setAdLoadFailed();
            }
          },
          onAdClicked: (ad) {
            debugPrint('👆 NativeAd clicked');
          },
          onAdImpression: (ad) {
            debugPrint('👁️ NativeAd impression recorded');
          },
        ),
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(
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
        ),
      );

      _nativeAd!.load();
    } catch (e) {
      debugPrint('❌ Error creating NativeAd: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
        });
        ref.read(googleAdsProvider.notifier).setAdLoadFailed();
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
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adsState = ref.watch(googleAdsProvider);
    final shouldShowGoogle = ref.watch(shouldShowGoogleAdsProvider);
    final customAdData = ref.watch(customAdDataProvider);

    // Listen for disposal requests
    ref.listen(googleAdsProvider, (previous, next) {
      if (next.shouldDisposeAd && !_isDisposed) {
        _nativeAd?.dispose();
        _nativeAd = null;
        setState(() {
          _isLoading = false;
        });
        ref.read(googleAdsProvider.notifier).acknowledgeDisposal();
      }
    });
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

  Widget _buildAdContent(
      GoogleAdsState adsState, bool? shouldShowGoogle, Map<String, String>? customAdData) {
    if (shouldShowGoogle == null) {
      return _buildLoadingWidget("Initializing ads...");
    }

    // Custom ads path
    if (!shouldShowGoogle) {
      return _buildCustomAdContent(customAdData, adsState);
    }

    // Google ads path
    if (adsState.nativeAdIsLoaded && _nativeAd != null) {
      // For Google ads, return ONLY the AdWidget without any overlays
      return AdWidget(ad: _nativeAd!);
    } else if (_isLoading) {
      return _buildLoadingWidget("Loading Google ads...");
    } else if (adsState.adLoadFailed) {
      return _buildErrorWidget("Failed to load Google ads", "Tap to retry", _retryLoadAd);
    } else {
      return _buildErrorWidget("Tap to load ads", "", _retryLoadAd);
    }
  }

  Widget _buildCustomAdContent(Map<String, String>? customAdData, GoogleAdsState adsState) {
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
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
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

  Widget _buildErrorWidget(String primaryMessage, String secondaryMessage, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              primaryMessage.contains("Failed") ? Icons.error_outline : Icons.refresh,
              color: primaryMessage.contains("Failed")
                  ? Colors.orange.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.6),
              size: 32.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              primaryMessage,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (secondaryMessage.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Text(
                secondaryMessage,
                style: TextStyle(
                  color: Colors.blue.withValues(alpha: 0.8),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
