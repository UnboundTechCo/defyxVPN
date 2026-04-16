import 'dart:io';
import 'package:defyx_vpn/app/advertise_director.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/ads_state.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/strategy/ad_loading_strategy.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/strategy/google_ad_strategy.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/strategy/internal_ad_strategy.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart'
    as conn;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ad Environment Configuration
///
/// Cached environment details to avoid repeated timezone/platform detection.
/// This is computed once at app startup and used throughout the app lifecycle.
class AdEnvironment {
  final bool isIranian;
  final bool isMobilePlatform;
  final bool shouldInitializeAdMob;

  const AdEnvironment({
    required this.isIranian,
    required this.isMobilePlatform,
    required this.shouldInitializeAdMob,
  });

  @override
  String toString() =>
      'AdEnvironment(isIranian: $isIranian, isMobile: $isMobilePlatform, initAdMob: $shouldInitializeAdMob)';
}

/// Provider for ad environment configuration
///
/// This is a FutureProvider because Iran detection is async (requires timezone check).
/// It's computed once and cached for the app lifetime.
///
/// Business rules:
/// - Iranian users: Don't initialize AdMob, only use internal ads
/// - Desktop platforms: Don't initialize AdMob, only use internal ads
/// - Mobile non-Iranian: Initialize AdMob, use both strategies
final adEnvironmentProvider = FutureProvider<AdEnvironment>((ref) async {
  debugPrint('🌍 Computing ad environment...');

  final isIranian = await AdvertiseDirector.isIranianUser();
  final isMobile = Platform.isAndroid || Platform.isIOS;
  final shouldInitAdMob = isMobile && !isIranian;

  final environment = AdEnvironment(
    isIranian: isIranian,
    isMobilePlatform: isMobile,
    shouldInitializeAdMob: shouldInitAdMob,
  );

  debugPrint('🌍 Ad environment: $environment');
  return environment;
});

/// Ad Strategy Manager - Handles strategy selection based on business rules
///
/// Responsibilities:
/// - Owns strategy instances (InternalAdStrategy and GoogleAdStrategy)
/// - Decides which strategy is active based on connection state and user type
/// - Orchestrates transitions between strategies
/// - Enforces business rules (Iranian users, desktop users, etc.)
/// - Manages connection state listener lifecycle
class AdStrategyManager {
  final Ref _ref;
  final AdEnvironment _environment;
  final InternalAdStrategy _internalStrategy;
  final GoogleAdStrategy? _googleStrategy; // null for Iranian/desktop users
  final bool _hasGoogleStrategy;

  ProviderSubscription<conn.ConnectionState>? _connectionSubscription;

  /// Private constructor - use factory method
  AdStrategyManager._({
    required Ref ref,
    required AdEnvironment environment,
    required InternalAdStrategy internalStrategy,
    required GoogleAdStrategy? googleStrategy,
  }) : _ref = ref,
       _environment = environment,
       _internalStrategy = internalStrategy,
       _googleStrategy = googleStrategy,
       _hasGoogleStrategy = googleStrategy != null;

  /// Factory constructor - creates strategies and sets up listener
  factory AdStrategyManager.create({
    required Ref ref,
    required AdEnvironment environment,
    Color backgroundColor = const Color(0xFF19312F),
    double cornerRadius = 10.0,
  }) {
    debugPrint('🏭 AdStrategyManager.create() - Environment: $environment');

    // Create InternalAdStrategy (always needed)
    final internalStrategy = InternalAdStrategy(
      backgroundColor: backgroundColor,
      cornerRadius: cornerRadius,
    );

    // Create GoogleAdStrategy only for mobile non-Iranian users
    final googleStrategy = environment.shouldInitializeAdMob
        ? GoogleAdStrategy(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
          )
        : null;

    final manager = AdStrategyManager._(
      ref: ref,
      environment: environment,
      internalStrategy: internalStrategy,
      googleStrategy: googleStrategy,
    );

    // Initialize connection listener
    manager._initializeConnectionListener();

    return manager;
  }

  /// Initialize connection state listener
  void _initializeConnectionListener() {
    debugPrint('🔔 AdStrategyManager - Registering connection listener');
    debugPrint('   Environment: ${_environment}');

    // Listen to connection changes and delegate to strategies
    _connectionSubscription = _ref.listen(conn.connectionStateProvider, (
      previous,
      next,
    ) {
      debugPrint(
        '🔔 Connection listener FIRED: ${previous?.status.name ?? "null"} → ${next.status.name}',
      );

      final prevStatus = previous?.status ?? conn.ConnectionStatus.disconnected;
      final currentStatus = next.status;

      _handleConnectionStateChanged(
        previous: prevStatus,
        current: currentStatus,
      );
    });

    // Trigger initial state
    final currentState = _ref.read(conn.connectionStateProvider).status;
    debugPrint('🔄 Triggering initial connection state: ${currentState.name}');
    _handleConnectionStateChanged(
      previous: conn.ConnectionStatus.disconnected,
      current: currentState,
    );
  }

  /// Get active strategy based on connection state
  /// Returns null if no ad should be shown
  AdLoadingStrategy? getActiveStrategy(conn.ConnectionStatus connectionState) {
    switch (connectionState) {
      case conn.ConnectionStatus.connected:
        // Connected state: Internal ads for all users
        return _internalStrategy;

      case conn.ConnectionStatus.disconnected:
        // Disconnected state: AdMob for non-Iranian users, nothing for Iranian users
        return _googleStrategy; // null for Iranian users = no ad

      default:
        // Intermediate states (connecting, loading, etc.): no ad
        return null;
    }
  }

  /// Handle connection state changes - orchestrates strategy transitions
  /// This is called internally by the connection listener
  void _handleConnectionStateChanged({
    required conn.ConnectionStatus previous,
    required conn.ConnectionStatus current,
  }) {
    debugPrint(
      '🎯 AdStrategyManager - Connection: ${previous.name} → ${current.name}',
    );

    // When connecting: notify internal strategy
    if (current == conn.ConnectionStatus.connected &&
        previous != conn.ConnectionStatus.connected) {
      debugPrint('   → Activating InternalAdStrategy');
      _internalStrategy.onConnectionStateChanged(
        ref: _ref,
        previous: previous,
        current: current,
        hasInitialized: true,
        onRefreshNeeded: () => _internalStrategy.loadAd(ref: _ref),
      );
    }
    // When leaving connected state: Clean up internal ads immediately
    // This handles: connected → disconnecting, connected → disconnected
    else if (previous == conn.ConnectionStatus.connected &&
        current != conn.ConnectionStatus.connected) {
      debugPrint(
        '   → Leaving connected state, deactivating InternalAdStrategy',
      );
      _internalStrategy.onConnectionStateChanged(
        ref: _ref,
        previous: previous,
        current: current,
        hasInitialized: true,
        onRefreshNeeded: () => _internalStrategy.loadAd(ref: _ref),
      );
    }

    // When reaching disconnected state: Load AdMob ad (if available)
    // This handles: disconnecting → disconnected, connected → disconnected, anything → disconnected
    if (current == conn.ConnectionStatus.disconnected &&
        previous != conn.ConnectionStatus.disconnected) {
      if (_hasGoogleStrategy) {
        debugPrint(
          '   → Reached disconnected state, activating GoogleAdStrategy',
        );
        _googleStrategy!.onConnectionStateChanged(
          ref: _ref,
          previous: previous,
          current: current,
          hasInitialized: true,
          onRefreshNeeded: () => _googleStrategy.loadAd(ref: _ref),
        );
      } else {
        debugPrint('   → No GoogleAdStrategy available (Iranian/Desktop user)');
      }
    }
  }

  /// Initialize both strategies
  Future<void> initialize() async {
    debugPrint('🚀 AdStrategyManager - Initializing strategies');
    await _internalStrategy.initialize(_ref);
    if (_hasGoogleStrategy) {
      await _googleStrategy!.initialize(_ref);
    }
    debugPrint('✅ AdStrategyManager - Initialization complete');

    // CRITICAL: Check initial connection state and load ad if already disconnected
    // This handles the case where app starts in disconnected state (no state change)
    final initialConnectionState = _ref.read(conn.connectionStateProvider);
    debugPrint(
      '🎬 Checking initial connection state: ${initialConnectionState.status.name}',
    );

    if (initialConnectionState.status == conn.ConnectionStatus.disconnected &&
        _hasGoogleStrategy) {
      debugPrint(
        '   → App started in disconnected state - triggering initial AdMob load',
      );
      // Simulate a state change to trigger ad load
      final googleStrategy = _googleStrategy!;
      googleStrategy.onConnectionStateChanged(
        ref: _ref,
        previous: conn.ConnectionStatus.noInternet, // Fake previous state
        current: conn.ConnectionStatus.disconnected,
        hasInitialized: true,
        onRefreshNeeded: () => googleStrategy.loadAd(ref: _ref),
      );
    } else if (initialConnectionState.status ==
        conn.ConnectionStatus.connected) {
      debugPrint(
        '   → App started in connected state - triggering initial internal ad load',
      );
      // Simulate a state change to trigger internal ad load
      _internalStrategy.onConnectionStateChanged(
        ref: _ref,
        previous: conn.ConnectionStatus.disconnected, // Fake previous state
        current: conn.ConnectionStatus.connected,
        hasInitialized: true,
        onRefreshNeeded: () => _internalStrategy.loadAd(ref: _ref),
      );
    } else {
      debugPrint(
        '   → No initial ad load needed (state: ${initialConnectionState.status.name})',
      );
    }
  }

  /// Retry ad loading for Google Ads (after consent completes)
  /// This is called when consent flow completes and user is still disconnected
  void retryGoogleAdLoad() {
    if (!_hasGoogleStrategy) {
      debugPrint('⚠️ Cannot retry - Google strategy not available');
      return;
    }

    final currentConnectionState = _ref.read(conn.connectionStateProvider);
    if (currentConnectionState.status != conn.ConnectionStatus.disconnected) {
      debugPrint(
        '⚠️ Cannot retry - not disconnected (${currentConnectionState.status.name})',
      );
      return;
    }

    debugPrint('🔄 Retrying Google ad load after consent');
    final googleStrategy = _googleStrategy!;
    googleStrategy.onConnectionStateChanged(
      ref: _ref,
      previous: conn.ConnectionStatus.disconnected,
      current: conn.ConnectionStatus.disconnected,
      hasInitialized: true,
      onRefreshNeeded: () => googleStrategy.loadAd(ref: _ref),
    );
  }

  /// Dispose strategies and subscriptions
  void dispose() {
    debugPrint('🧹 AdStrategyManager - Disposing');
    _connectionSubscription?.close();
    _internalStrategy.dispose();
    _googleStrategy?.dispose();
    debugPrint('✅ AdStrategyManager - Disposed');
  }

  InternalAdStrategy get internalStrategy => _internalStrategy;
  GoogleAdStrategy? get googleStrategy => _googleStrategy;
  bool get hasGoogleStrategy => _hasGoogleStrategy;
}

/// Provider for AdStrategyManager
///
/// Creates and manages the ad strategy manager instance.
/// The manager is created lazily when first accessed and disposed automatically.
///
/// Dependencies:
/// - adEnvironmentProvider: To determine which strategies to create
///
/// Lifecycle:
/// - autoDispose: Cleans up when no longer watched
/// - ref.onDispose: Ensures manager.dispose() is called
final adStrategyManagerProvider = Provider.autoDispose<AdStrategyManager?>((
  ref,
) {
  // Wait for environment to be ready
  final environmentAsync = ref.watch(adEnvironmentProvider);

  return environmentAsync.when(
    data: (environment) {
      debugPrint('📦 Creating AdStrategyManager from provider');

      // Create manager with environment
      final manager = AdStrategyManager.create(
        ref: ref,
        environment: environment,
      );

      // Initialize strategies synchronously
      // (actual ad loading happens on connection changes, which is async)
      manager.initialize();

      // Register disposal
      ref.onDispose(() {
        debugPrint('📦 AdStrategyManager provider disposing');
        manager.dispose();
      });

      return manager;
    },
    loading: () {
      debugPrint('⏳ Waiting for ad environment...');
      return null;
    },
    error: (error, stack) {
      debugPrint('❌ Error loading ad environment: $error');
      return null;
    },
  );
});

/// Provider for active ad visibility
///
/// Returns true if there's an active ad strategy that should be displayed.
/// This is the single source of truth for ad container visibility.
///
/// Checks not just if a strategy exists, but if it has actually loaded an ad.
/// This prevents showing empty ad containers:
/// - When GoogleAdStrategy hasn't loaded yet (nativeAdIsLoaded = false)
/// - When InternalAdStrategy has no ad data (customImageUrl = null/empty)
final hasActiveAdProvider = Provider.autoDispose<bool>((ref) {
  final manager = ref.watch(adStrategyManagerProvider);
  final connectionState = ref.watch(conn.connectionStateProvider);
  final adsState = ref.watch(adsProvider);

  if (manager == null) {
    return false;
  }

  final activeStrategy = manager.getActiveStrategy(connectionState.status);

  if (activeStrategy == null) {
    return false;
  }

  // Check if the strategy has actually loaded an ad
  bool hasLoadedAd = false;

  if (activeStrategy is GoogleAdStrategy) {
    // GoogleAdStrategy: Check if ad is loaded (show immediately when disconnected)
    hasLoadedAd = adsState.nativeAdIsLoaded;
  } else if (activeStrategy is InternalAdStrategy) {
    // InternalAdStrategy: Must have custom ad image URL
    hasLoadedAd =
        adsState.customImageUrl != null && adsState.customImageUrl!.isNotEmpty;
  }

  return hasLoadedAd;
});
