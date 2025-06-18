import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// State class for Google Ads
class GoogleAdsState {
  final bool nativeAdIsLoaded;
  final int countdown;
  final bool showCountdown;

  const GoogleAdsState({
    this.nativeAdIsLoaded = false,
    this.countdown = 20,
    this.showCountdown = true,
  });

  GoogleAdsState copyWith({
    bool? nativeAdIsLoaded,
    int? countdown,
    bool? showCountdown,
  }) {
    return GoogleAdsState(
      nativeAdIsLoaded: nativeAdIsLoaded ?? this.nativeAdIsLoaded,
      countdown: countdown ?? this.countdown,
      showCountdown: showCountdown ?? this.showCountdown,
    );
  }
}

// Provider for Google Ads state
class GoogleAdsNotifier extends StateNotifier<GoogleAdsState> {
  GoogleAdsNotifier() : super(const GoogleAdsState());
  Timer? _countdownTimer;

  void startCountdownTimer() {
    _countdownTimer?.cancel(); // Cancel existing timer if any
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.countdown > 0) {
        state = state.copyWith(countdown: state.countdown - 1);
      } else {
        state = state.copyWith(showCountdown: false);
        timer.cancel();
      }
    });
  }

  void resetTimer() {
    _countdownTimer?.cancel();
    state = const GoogleAdsState(
      nativeAdIsLoaded: false,
      countdown: 20,
      showCountdown: true,
    );
    startCountdownTimer();
  }

  void setAdLoaded(bool isLoaded) {
    state = state.copyWith(nativeAdIsLoaded: isLoaded);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}

// Provider for the Google Ads state
final googleAdsProvider =
    StateNotifierProvider<GoogleAdsNotifier, GoogleAdsState>((ref) {
      return GoogleAdsNotifier();
    });

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

class _GoogleAdsState extends ConsumerState<GoogleAds> {
  NativeAd? _nativeAd;

  final String _adUnitId =
      Platform.isAndroid
          ? 'ca-app-pub-0000000000000000/0000000000'
          : 'ca-app-pub-0000000000000000/0000000000';

  @override
  void initState() {
    super.initState();
    loadAd();
    ref.read(googleAdsProvider.notifier).startCountdownTimer();
  }

  /// Loads a native ad.
  void loadAd() {
    _nativeAd = NativeAd(
      adUnitId: _adUnitId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('$NativeAd loaded.');
          ref.read(googleAdsProvider.notifier).setAdLoaded(true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('$NativeAd failed to load: $error');
          ad.dispose();
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
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adsState = ref.watch(googleAdsProvider);
    return adsState.nativeAdIsLoaded && _nativeAd != null
        ? ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 336.w,
            minHeight: 280.h,
            maxWidth: 336.w,
            maxHeight: 280.h,
          ),
          child: AdWidget(ad: _nativeAd!),
        )
        : SizedBox(
          height: 280.h,
          width: 336.w,
          child: Stack(
            children: [
              Center(child: CircularProgressIndicator()),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(10.r),
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

              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(10.r),
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
}
