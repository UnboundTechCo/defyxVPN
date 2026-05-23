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
/// - Business Logic → AdStrategyManager (which strategy when)
/// - Rendering → AdsWidget (show active strategy)
/// - Ad Loading → Strategies (how to load and display)
///
/// **Responsibilities:**
/// - AdStrategyManager: Strategy selection, lifecycle, transitions
/// - AdsWidget (this file): Render active strategy, manage widget lifecycle
/// - GoogleAdStrategy: Load and render AdMob ads
/// - InternalAdStrategy: Load and render internal ads
/// - MainScreen: Controls when to show/hide ads widget
///
/// **UI Features:**
/// - "ADVERTISEMENT" label (top-right corner)
/// - 25-second countdown timer (bottom-left corner)
/// - Ad carousel rotation with fade transitions (300ms)
/// - Automatic hiding when countdown expires
/// - Smooth fade animations (300ms)
///
import 'package:defyx_vpn/app/ad_director_provider.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/ads_state.dart';
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
  @override
  Widget build(BuildContext context) {
    // Get manager from provider
    final manager = ref.watch(adStrategyManagerProvider);
    final adsState = ref.watch(adsProvider);
    final connectionState = ref.watch(conn.connectionStateProvider).status;

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

    // Render ad container with active strategy
    // Size is constrained by parent (main_screen.dart: 280.h x 336.w)
    return Stack(
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
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: ClipRRect(
              key: ValueKey('ad_rotation_${adsState.rotationCount}'),
              borderRadius: BorderRadius.circular(widget.cornerRadius),
              child: activeStrategy.buildAdWidget(
                context: context,
                state: adsState,
                cornerRadius: widget.cornerRadius,
              ),
            ),
          ),
        ),
        // ADVERTISEMENT label (top-right)
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
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
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
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
    );
  }
}
