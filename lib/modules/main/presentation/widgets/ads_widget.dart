/// Unified Ads Widget - Strategy Pattern Implementation
/// 
/// This widget serves as a lightweight orchestrator that delegates ad loading
/// to specialized strategy classes based on the user's region.
/// 
/// **Architecture:**
/// Uses the Strategy Pattern to separate ad loading logic from UI presentation:
/// - GoogleAdStrategy: Handles Google AdMob ads with full orchestration
/// - InternalAdStrategy: Handles custom/internal ads for restricted regions
/// 
/// **Strategy Selection:**
/// - Determined at runtime via AdvertiseDirector.shouldUseInternalAds()
/// - Strategy is instantiated in initState() and used throughout lifecycle
/// 
/// **Responsibilities:**
/// - Widget (this file): UI rendering, strategy selection, lifecycle management
/// - Strategies: Ad loading logic, connection state handling, resource cleanup
/// - State (ads_state.dart): Centralized state shared across all strategies
/// 
/// **UI Features:**
/// - "ADVERTISEMENT" label (top-right corner)
/// - 60-second countdown timer (bottom-left corner, shown when connected)
/// - Automatic hiding when countdown expires
/// - Consistent behavior across all ad types
/// 
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/ads_state.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/strategy/ad_loading_strategy.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/strategy/google_ad_strategy.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/strategy/internal_ad_strategy.dart';
import 'package:defyx_vpn/app/advertise_director.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Main ads widget - uses Strategy Pattern for ad loading
class AdsWidget extends ConsumerStatefulWidget {
  final Color backgroundColor;
  final double cornerRadius;

  const AdsWidget({
    super.key,
    this.backgroundColor = Colors.white,
    this.cornerRadius = 10.0,
  });

  @override
  ConsumerState<AdsWidget> createState() => _AdsWidgetState();
}

/// Widget state - orchestrates strategy and renders UI
class _AdsWidgetState extends ConsumerState<AdsWidget> {
  AdLoadingStrategy? _strategy;
  bool _isDisposed = false;
  bool _useInternalAds = false;

  @override
  void initState() {
    super.initState();
    debugPrint('AdsWidget initState called');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_isDisposed) return;
      
      // Determine which strategy to use
      _useInternalAds = await AdvertiseDirector.shouldUseInternalAds(ref);
      debugPrint('📱 Ad type determined: ${_useInternalAds ? "Internal" : "Google"}');
      
      // Create appropriate strategy
      if (_useInternalAds) {
        _strategy = InternalAdStrategy();
      } else {
        _strategy = GoogleAdStrategy(
          backgroundColor: widget.backgroundColor,
          cornerRadius: widget.cornerRadius,
        );
      }
      
      // Initialize strategy (this also loads the initial ad)
      await _strategy!.initialize(ref);
      
      // Listen to connection changes and delegate to strategy
      ref.listenManual(connectionStateProvider, (previous, next) {
        if (_strategy == null || _isDisposed) return;
        
        _strategy!.onConnectionStateChanged(
          ref: ref,
          previous: previous?.status ?? ConnectionStatus.disconnected,
          current: next.status,
          hasInitialized: true,
          onRefreshNeeded: () => _strategy!.loadAd(ref: ref),
        );
      });
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _strategy?.dispose();
    debugPrint('🧹 AdsWidget disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adsState = ref.watch(adsProvider);

    // Hide ad panel completely if loading failed (don't show errors to users)
    if (adsState.adLoadFailed) {
      return const SizedBox.shrink();
    }

    // For internal ads: Don't show container until we have a valid image URL
    if (_useInternalAds) {
      if (adsState.customImageUrl == null || adsState.customImageUrl!.isEmpty) {
        return const SizedBox.shrink();
      }
    }

    // For Google ads: Don't show container until ad is actually loaded
    if (!_useInternalAds && !adsState.nativeAdIsLoaded) {
      return const SizedBox.shrink();
    }

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
              child: _strategy?.buildAdWidget(
                    context: context,
                    state: adsState,
                    cornerRadius: widget.cornerRadius,
                  ) ?? const SizedBox.shrink(),
            ),
          ),
          // ADVERTISEMENT label (top-right)
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
          // Countdown timer (bottom-left)
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
}
