/// Unified Ads Widget - Strategy Pattern Implementation
/// 
/// This widget serves as a strategy coordinator that manages dual ad strategies
/// and switches between them based on VPN connection state.
/// 
/// **Architecture:**
/// Uses the Strategy Pattern to separate ad loading logic from UI presentation:
/// - GoogleAdStrategy: Handles Google AdMob ads (disconnected state ONLY)
/// - InternalAdStrategy: Handles custom/internal ads (connected state ONLY)
/// 
/// **Strategy Coordination:**
/// - Both strategies are initialized on widget creation (mobile platforms)
/// - AdsWidget routes connection state changes to the appropriate strategy
/// - When connected → InternalAdStrategy loads and shows internal ads
/// - When disconnected → GoogleAdStrategy loads and shows AdMob ads
/// - Single Responsibility: Each strategy handles ONE ad type in ONE state
/// 
/// **Responsibilities:**
/// - AdsWidget (this file): Strategy initialization, routing, lifecycle management
/// - GoogleAdStrategy: AdMob ads for disconnected state only
/// - InternalAdStrategy: Internal ads for connected state only
/// - State (ads_state.dart): Centralized state shared across strategies
/// - MainScreen: Controls when to show/hide ads widget
/// 
/// **Visibility Control:**
/// - MainScreen decides when to render AdsWidget (based on connection + countdown)
/// - AdsWidget chooses which strategy to render based on connection state
/// - Strategies handle their own ad loading and state updates
/// 
/// **UI Features:**
/// - "ADVERTISEMENT" label (top-right corner)
/// - 60-second countdown timer (bottom-left corner)
/// - Automatic hiding when countdown expires
/// - Consistent behavior across both ad types
/// 
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/ads_state.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/strategy/ad_loading_strategy.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/strategy/google_ad_strategy.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/strategy/internal_ad_strategy.dart';
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

/// Widget state - orchestrates dual strategies and renders UI
class _AdsWidgetState extends ConsumerState<AdsWidget> {
  // Dual strategy instances
  AdLoadingStrategy? _googleAdStrategy;
  AdLoadingStrategy? _internalAdStrategy;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 AdsWidget initState called');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('🎬 PostFrameCallback executing...');
      
      if (_isDisposed) {
        debugPrint('   ⚠️ Widget already disposed, aborting initialization');
        return;
      }
      
      try {
        // Initialize BOTH strategies (for mobile platforms)
        // GoogleAdStrategy: Handles AdMob ads when disconnected
        // InternalAdStrategy: Handles internal ads when connected
        debugPrint('🎯 Initializing dual ad strategies');
        
        _googleAdStrategy = GoogleAdStrategy(
          backgroundColor: widget.backgroundColor,
          cornerRadius: widget.cornerRadius,
        );
        
        _internalAdStrategy = InternalAdStrategy(
          backgroundColor: widget.backgroundColor,
          cornerRadius: widget.cornerRadius,
        );
        
        // Initialize both strategies
        await _googleAdStrategy!.initialize(ref);
        await _internalAdStrategy!.initialize(ref);
        debugPrint('✅ Both strategies initialized');
      
      // Trigger rebuild to show the ad
      if (mounted && !_isDisposed) {
        setState(() {});
      }
      
      // Listen to connection changes and route to appropriate strategy
      ref.listenManual(connectionStateProvider, (previous, next) {
        debugPrint('🔔 AdsWidget - Connection state listener triggered:');
        debugPrint('   Previous: ${previous?.status.name ?? "null"}');
        debugPrint('   Next: ${next.status.name}');
        
        if (_isDisposed) return;
        
        // Route to appropriate strategy based on connection state
        final prevStatus = previous?.status ?? ConnectionStatus.disconnected;
        final currentStatus = next.status;
        
        // When connected, use InternalAdStrategy
        if (currentStatus == ConnectionStatus.connected) {
          debugPrint('   → Routing to InternalAdStrategy');
          _internalAdStrategy?.onConnectionStateChanged(
            ref: ref,
            previous: prevStatus,
            current: currentStatus,
            hasInitialized: true,
            onRefreshNeeded: () => _internalAdStrategy!.loadAd(ref: ref),
          );
        }
        // When disconnected, use GoogleAdStrategy
        else if (currentStatus == ConnectionStatus.disconnected) {
          debugPrint('   → Routing to GoogleAdStrategy');
          _googleAdStrategy?.onConnectionStateChanged(
            ref: ref,
            previous: prevStatus,
            current: currentStatus,
            hasInitialized: true,
            onRefreshNeeded: () => _googleAdStrategy!.loadAd(ref: ref),
          );
        }
        // For intermediate states (loading, analyzing, etc.), route to both
        else {
          debugPrint('   → Routing to both strategies (intermediate state)');
          _googleAdStrategy?.onConnectionStateChanged(
            ref: ref,
            previous: prevStatus,
            current: currentStatus,
            hasInitialized: true,
            onRefreshNeeded: () => _googleAdStrategy!.loadAd(ref: ref),
          );
          _internalAdStrategy?.onConnectionStateChanged(
            ref: ref,
            previous: prevStatus,
            current: currentStatus,
            hasInitialized: true,
            onRefreshNeeded: () => _internalAdStrategy!.loadAd(ref: ref),
          );
        }
      });
      
      debugPrint('✅ Connection state listener registered');
      
      // Manually trigger initial state check
      final currentState = ref.read(connectionStateProvider).status;
      debugPrint('🔄 Triggering initial state check: ${currentState.name}');
      
      if (!_isDisposed) {
        if (currentState == ConnectionStatus.connected) {
          _internalAdStrategy?.onConnectionStateChanged(
            ref: ref,
            previous: ConnectionStatus.disconnected,
            current: currentState,
            hasInitialized: true,
            onRefreshNeeded: () => _internalAdStrategy!.loadAd(ref: ref),
          );
        } else {
          _googleAdStrategy?.onConnectionStateChanged(
            ref: ref,
            previous: ConnectionStatus.disconnected,
            current: currentState,
            hasInitialized: true,
            onRefreshNeeded: () => _googleAdStrategy!.loadAd(ref: ref),
          );
        }
      }
      
      } catch (e, stackTrace) {
        debugPrint('❌ ERROR in AdsWidget initialization: $e');
        debugPrint('   Stack trace: $stackTrace');
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _googleAdStrategy?.dispose();
    _internalAdStrategy?.dispose();
    debugPrint('🧹 AdsWidget disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 AdsWidget.build() called');
    final adsState = ref.watch(adsProvider);
    final connectionState = ref.watch(connectionStateProvider).status;
    debugPrint('   Ad state: loaded=${adsState.nativeAdIsLoaded}, customAd=${adsState.customImageUrl != null}, countdown=${adsState.showCountdown}');
    debugPrint('   Connection: ${connectionState.name}');

    // Safety check: Hide if loading failed (MainScreen should already handle this)
    if (adsState.adLoadFailed) {
      return const SizedBox.shrink();
    }

    // Wait for strategies to initialize (happens in postFrameCallback)
    if (_googleAdStrategy == null || _internalAdStrategy == null) {
      return const SizedBox.shrink();
    }

    // Choose which strategy to render based on connection state
    AdLoadingStrategy? activeStrategy;
    if (connectionState == ConnectionStatus.connected && 
        adsState.customImageUrl != null && 
        adsState.customImageUrl!.isNotEmpty) {
      // Connected state with internal ad available → use InternalAdStrategy
      activeStrategy = _internalAdStrategy;
      debugPrint('   → Rendering InternalAdStrategy');
    } else if (adsState.nativeAdIsLoaded) {
      // Disconnected state with AdMob ad available → use GoogleAdStrategy
      activeStrategy = _googleAdStrategy;
      debugPrint('   → Rendering GoogleAdStrategy');
    }

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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.cornerRadius),
            child: activeStrategy.buildAdWidget(
                  context: context,
                  state: adsState,
                  cornerRadius: widget.cornerRadius,
                ),
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
    );
  }
}
