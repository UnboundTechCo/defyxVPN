/// Unified Ads Widget - Strategy Pattern Implementation (Refactored)
///
/// This widget is a simple renderer that delegates strategy selection to AdStrategyManager.
///
/// **Architecture (Proper Strategy Pattern):**
/// - AdStrategyManager: Owns strategies, decides which is active, handles transitions
/// - AdsWidget:Uses AdStrategyManager to get active strategy and render it
/// - Strategies: Handle ad loading and rendering for their specific case
///
/// **Separation of Concerns:**
/// - Business Logic -> AdStrategyManager (which strategy when)
/// - Rendering -> AdsWidget (show active strategy)
/// - Ad Loading -> Strategies (how to load and display)
///
/// **Responsibilities:**
/// - AdStrategyManager: Strategy selection, lifecycle, transitions
/// - AdsWidget (this file): Render active strategy, manage widget lifecycle
/// - GoogleAdStrategy: Load and render AdMob ads
/// - InternalAdStrategy: Load and render internal ads
/// - MainScreen: Controls when to show/hide ads widget
///
/// **UI Features:**
/// - "ADVERTISEMENT" label and countdown: in a strip above AdMob ads (nothing
///   may cover them), in the bottom corners of in-house ads (whose top edge
///   holds the "tap to learn more" cue)
/// - Countdown: 30s per AdMob ad, 25s per in-house ad, paused while unseen
/// - Ad carousel rotation with fade transitions (300ms)
/// - Automatic hiding when countdown expires
/// - Smooth fade animations (300ms)
///
library;

import 'package:defyx_vpn/app/ad_director_provider.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/ads_state.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/strategy/internal_ad_strategy.dart';
import 'package:defyx_vpn/shared/providers/premium_provider.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart'
    as conn;
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

/// Widget state - pure renderer, gets manager from provider
class _AdsWidgetState extends ConsumerState<AdsWidget> {
  late final AdsNotifier _ads;
  late final AppLifecycleListener _lifecycle;
  bool _onScreen = false;

  @override
  void initState() {
    super.initState();
    // The countdown runs only while this box can be seen.
    _ads = ref.read(adsProvider.notifier);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        final foreground = state == AppLifecycleState.resumed;
        _ads.setAppInForeground(foreground);
        if (foreground && _onScreen) _preloadForNextConnect();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // False while another page covers the main screen.
    final onScreen = TickerMode.valuesOf(context).enabled;
    _ads.setAdOnScreen(onScreen);
    if (onScreen && !_onScreen) _preloadForNextConnect();
    _onScreen = onScreen;
  }

  /// The main screen is in view again (or the app back in the foreground):
  /// make sure an AdMob ad is ready for the next connect tap.
  void _preloadForNextConnect() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(adStrategyManagerProvider)?.preloadGoogleAd();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _ads.setAdOnScreen(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get manager from provider
    final manager = ref.watch(adStrategyManagerProvider);
    final adsState = ref.watch(adsProvider);
    final connectionState = ref.watch(conn.connectionStateProvider).status;
    // Premium users (or status not known yet): no ads at all.
    if (!ref.watch(adsAllowedProvider)) {
      return const SizedBox.shrink();
    }

    // Safety check: Hide if loading failed
    if (adsState.adLoadFailed) {
      return const SizedBox.shrink();
    }

    // Wait for manager to initialize
    if (manager == null) {
      return const SizedBox.shrink();
    }

    // Ask manager which strategy is active - business logic lives there
    final activeStrategy = manager.getActiveStrategy(connectionState);

    // If no active strategy, hide widget
    if (activeStrategy == null) {
      return const SizedBox.shrink();
    }

    final radius = Radius.circular(widget.cornerRadius);
    final box = BoxDecoration(
      color: widget.backgroundColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.all(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
    );
    Widget content(BorderRadius clip) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: ClipRRect(
        key: ValueKey('ad_rotation_${adsState.rotationCount}'),
        borderRadius: clip,
        child: activeStrategy.buildAdWidget(
          context: context,
          state: adsState,
          cornerRadius: widget.cornerRadius,
        ),
      ),
    );
    final countdownText = "Closing in ${adsState.countdown}s";

    // Size is constrained by parent (main_screen.dart: 280.h x 336.w)
    if (activeStrategy is! InternalAdStrategy) {
      // AdMob: nothing may cover the ad (AdChoices icon, button), so the
      // labels sit in a strip above it.
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: box,
        child: Column(
          children: [
            SizedBox(
              height: 24.h,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                child: Row(
                  children: [
                    _stripText("ADVERTISEMENT"),
                    const Spacer(),
                    if (adsState.showCountdown) _stripText(countdownText),
                  ],
                ),
              ),
            ),
            Expanded(child: content(BorderRadius.vertical(bottom: radius))),
          ],
        ),
      );
    }

    // In-house ads: labels over the picture; the top edge holds the "tap to
    // learn more" cue, so ADVERTISEMENT sits bottom-right.
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: box,
          child: content(BorderRadius.all(radius)),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: _cornerTab(
            "ADVERTISEMENT",
            BorderRadius.only(
              bottomRight: radius,
              topLeft: Radius.circular(3.r),
            ),
          ),
        ),
        if (adsState.showCountdown)
          Positioned(
            bottom: 0,
            left: 0,
            child: _cornerTab(
              countdownText,
              BorderRadius.only(
                bottomLeft: radius,
                topRight: Radius.circular(3.r),
              ),
            ),
          ),
      ],
    );
  }

  Widget _stripText(String text) => Text(
    text,
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.7),
      fontSize: 11.sp,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.2,
    ),
  );

  Widget _cornerTab(String text, BorderRadius borderRadius) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.3),
      borderRadius: borderRadius,
    ),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
      ),
    ),
  );
}
