import 'dart:io';
import 'package:defyx_vpn/app/advertise_director.dart';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/ads_state.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/strategy/ad_loading_strategy.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/strategy/google_ad_strategy.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ads/strategy/internal_ad_strategy.dart';
import 'package:defyx_vpn/shared/providers/premium_provider.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart'
    as conn;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ad Environment Configuration
///
/// Whether this device runs AdMob, as decided by [AdvertiseDirector.isAdMobDisabled].
@immutable
class AdEnvironment {
  final bool adMobIsDisabled;
  final bool isMobilePlatform;
  final bool shouldInitializeAdMob;

  const AdEnvironment({
    required this.adMobIsDisabled,
    required this.isMobilePlatform,
    required this.shouldInitializeAdMob,
  });

  @override
  bool operator ==(Object other) =>
      other is AdEnvironment &&
      other.adMobIsDisabled == adMobIsDisabled &&
      other.isMobilePlatform == isMobilePlatform &&
      other.shouldInitializeAdMob == shouldInitializeAdMob;

  @override
  int get hashCode =>
      Object.hash(adMobIsDisabled, isMobilePlatform, shouldInitializeAdMob);

  @override
  String toString() =>
      'AdEnvironment(adMobDisabled: $adMobIsDisabled, isMobile: $isMobilePlatform, initAdMob: $shouldInitializeAdMob)';
}

/// Works out [AdEnvironment] and works it out again whenever new flowline
/// settings are saved, so a change to `disabledAdmob` on the server takes
/// effect as soon as the app downloads it.
///
/// Stays loading (no ads at all) until the settings exist: on a fresh install
/// they arrive moments later, when the splash screen saves the flowline. It
/// only emits when the decision changes, so dependants such as
/// [adStrategyManagerProvider] are not rebuilt on every save.
class AdEnvironmentNotifier extends StateNotifier<AsyncValue<AdEnvironment>> {
  AdEnvironmentNotifier(this._isAdMobDisabled, {required bool isMobile})
    : _isMobile = isMobile,
      super(const AsyncValue.loading()) {
    refresh();
  }

  /// [AdvertiseDirector.isAdMobDisabled] in the app: null while unknown.
  final Future<bool?> Function() _isAdMobDisabled;
  final bool _isMobile;
  bool _refreshing = false;
  bool _refreshAgain = false;

  Future<void> refresh() async {
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        final adMobDisabled = await _isAdMobDisabled();
        if (!mounted) return;
        if (adMobDisabled == null) {
          debugPrint('Ad environment: waiting for flowline settings');
          continue;
        }

        final environment = AdEnvironment(
          adMobIsDisabled: adMobDisabled,
          isMobilePlatform: _isMobile,
          shouldInitializeAdMob: _isMobile && !adMobDisabled,
        );
        if (state.valueOrNull != environment) {
          debugPrint('Ad environment: $environment');
          state = AsyncValue.data(environment);
        }
      } while (_refreshAgain && mounted);
    } catch (e) {
      // Keep the last decision; the next settings save tries again.
      debugPrint('Ad environment: could not be worked out: $e');
    } finally {
      _refreshing = false;
    }
  }
}

/// Provider for ad environment configuration
///
/// Business rules:
/// - Time zones listed in the server's `disabledAdmob` (or "general"):
///   don't initialize AdMob, only use internal ads
/// - Desktop platforms: don't initialize AdMob, only use internal ads
/// - Everyone else on mobile: initialize AdMob, use both strategies
final adEnvironmentProvider =
    StateNotifierProvider<AdEnvironmentNotifier, AsyncValue<AdEnvironment>>((
      ref,
    ) {
      final notifier = AdEnvironmentNotifier(
        () => AdvertiseDirector.isAdMobDisabled(ref),
        isMobile: Platform.isAndroid || Platform.isIOS,
      );
      ref.listen(
        flowlineSettingsRevisionProvider,
        (_, _) => notifier.refresh(),
      );
      return notifier;
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
  final InternalAdStrategy _internalStrategy;
  final GoogleAdStrategy? _googleStrategy; // null for Iranian/desktop users
  final bool _hasGoogleStrategy;

  ProviderSubscription<conn.ConnectionState>? _connectionSubscription;

  // DXcore is switching method or reconnecting while connected: analyzing
  // right after connected. The tunnel stays up throughout.
  bool _switching = false;

  bool get _inHouseAdShowing {
    final url = _ref.read(adsProvider).customImageUrl;
    return url != null && url.isNotEmpty;
  }

  /// Private constructor - use factory method
  AdStrategyManager._({
    required Ref ref,
    required AdEnvironment environment,
    required InternalAdStrategy internalStrategy,
    required GoogleAdStrategy? googleStrategy,
  }) : _ref = ref,
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
    // Listen to connection changes and delegate to strategies
    _connectionSubscription = _ref.listen(conn.connectionStateProvider, (
      previous,
      next,
    ) {
      debugPrint(
        'Connection changed: ${previous?.status.name ?? "none"} -> ${next.status.name}',
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
    _handleConnectionStateChanged(
      previous: conn.ConnectionStatus.disconnected,
      current: currentState,
    );
  }

  /// Get active strategy based on connection state
  /// Returns null if no ad should be shown
  AdLoadingStrategy? getActiveStrategy(conn.ConnectionStatus connectionState) {
    // A DXcore switch keeps the tunnel up: an in-house ad on screen stays
    // through it, instead of vanishing until the reconnect.
    if (connectionState == conn.ConnectionStatus.analyzing &&
        _switching &&
        _inHouseAdShowing) {
      return _internalStrategy;
    }
    if (_hasGoogleStrategy) {
      // AdMob: from the connect tap through connecting and connected (the
      // ad shown at the tap stays for its countdown), and the ad shown
      // after a disconnect. Otherwise nothing while disconnected: the ad is
      // only loaded then, for the next tap. Connected without an AdMob ad
      // on screen: the in-house fallback.
      switch (connectionState) {
        case conn.ConnectionStatus.disconnected:
          return _googleStrategy!.isShowingAd ? _googleStrategy : null;
        case conn.ConnectionStatus.loading:
        case conn.ConnectionStatus.analyzing:
          return _googleStrategy;
        case conn.ConnectionStatus.connected:
          return _googleStrategy!.isShowingAd
              ? _googleStrategy
              : _internalStrategy;
        default:
          return null;
      }
    }
    // AdMob off here (e.g. Iran time zones): in-house ads while connected.
    return connectionState == conn.ConnectionStatus.connected
        ? _internalStrategy
        : null;
  }

  /// Handle connection state changes - orchestrates strategy transitions
  /// This is called internally by the connection listener
  void _handleConnectionStateChanged({
    required conn.ConnectionStatus previous,
    required conn.ConnectionStatus current,
  }) {
    if (current != conn.ConnectionStatus.analyzing) {
      _switching = false;
    } else if (previous == conn.ConnectionStatus.connected) {
      _switching = true;
    }

    // AdMob users: the AdMob strategy follows every change (shows at the
    // connect tap, loads the next ad once the tunnel is down).
    if (_hasGoogleStrategy) {
      _googleStrategy!.onConnectionStateChanged(
        ref: _ref,
        previous: previous,
        current: current,
        hasInitialized: true,
        onRefreshNeeded: () => _googleStrategy.preload(_ref),
      );
    }

    // In-house ads on connect: always where AdMob is off; for AdMob users
    // only as a fallback, when no AdMob ad was shown for this connection
    // (the app reopened while connected - the ad died with the closed app -
    // or none was ready at the tap). One still on screen (after a switch)
    // is kept rather than replaced.
    final inHouseOnConnect =
        !_hasGoogleStrategy || !_googleStrategy!.shownThisConnection;
    if (current == conn.ConnectionStatus.connected &&
        previous != conn.ConnectionStatus.connected &&
        inHouseOnConnect &&
        !_inHouseAdShowing) {
      _internalStrategy.onConnectionStateChanged(
        ref: _ref,
        previous: previous,
        current: current,
        hasInitialized: true,
        onRefreshNeeded: () => _internalStrategy.loadAd(ref: _ref),
      );
    }

    // The tunnel is down: the in-house ad goes, whatever came before
    // (a disconnect passes through disconnecting first).
    if (current != previous &&
        (current == conn.ConnectionStatus.disconnected ||
            current == conn.ConnectionStatus.error) &&
        _inHouseAdShowing) {
      final ads = _ref.read(adsProvider.notifier);
      ads.stopCountdownTimer();
      ads.clearCustomAdData();
    }
  }

  /// Initialize both strategies
  Future<void> initialize() async {
    await _internalStrategy.initialize(_ref);
    if (_hasGoogleStrategy) {
      await _googleStrategy!.initialize(_ref);
    }

    // Start-up: AdMob users get an ad loaded (not shown) for the connect
    // tap, if the tunnel is down. (Already connected: the listener's replay
    // of the starting state brings the in-house ad.)
    if (_hasGoogleStrategy) {
      _googleStrategy!.preload(_ref);
    }
  }

  /// The consent the AdMob ads were requested with no longer holds: drop
  /// them, shown or held.
  void dropGoogleAds() => _googleStrategy?.dropAds(_ref);

  /// Makes sure an AdMob ad is loaded for the next connect tap (after
  /// consent completes, when ads become allowed, or when the user comes back
  /// to the main screen). Loads only while the tunnel is down.
  void preloadGoogleAd() {
    if (!_hasGoogleStrategy) return;
    _googleStrategy!.preload(_ref);
  }

  /// Dispose strategies and subscriptions
  void dispose() {
    debugPrint('AdStrategyManager - Disposing');
    _connectionSubscription?.close();
    _internalStrategy.dispose();
    _googleStrategy?.dispose();
    debugPrint('AdStrategyManager - Disposed');
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
/// - Session-scoped provider (NOT autoDispose) to prevent recreation churn
/// - Manager holds static NativeAd which should persist across widget rebuilds
/// - ref.onDispose: Ensures manager.dispose() is called on app exit
final adStrategyManagerProvider = Provider<AdStrategyManager?>((ref) {
  // Wait for environment to be ready
  final environmentAsync = ref.watch(adEnvironmentProvider);

  return environmentAsync.when(
    data: (environment) {
      // Create manager with environment
      final manager = AdStrategyManager.create(
        ref: ref,
        environment: environment,
      );

      // Initialize strategies synchronously
      // (actual ad loading happens on connection changes, which is async)
      manager.initialize();

      // Disposed on app exit, and when the AdMob decision changes (the
      // manager is then rebuilt with or without the Google strategy).
      ref.onDispose(() {
        manager.dispose();
      });

      return manager;
    },
    loading: () {
      return null;
    },
    error: (error, stack) {
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
  if (!ref.watch(adsAllowedProvider)) return false; // Premium: no ads.
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
