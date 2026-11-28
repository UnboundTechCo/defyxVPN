import 'dart:io';

import 'package:defyx_vpn/app/ad_director_provider.dart';
import 'package:defyx_vpn/shared/providers/premium_provider.dart';
import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/app/router/dpad_shell_page.dart';
import 'package:defyx_vpn/shared/layout/navbar/defyx_navbar.dart';
import 'package:defyx_vpn/shared/tv/dpad_traversal_policy.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/modules/core/vpn.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ump_service.dart';
import 'package:defyx_vpn/shared/providers/language_provider.dart';
import 'package:defyx_vpn/shared/providers/haptics_provider.dart';
import 'package:defyx_vpn/shared/providers/ad_readiness_coordinator.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart'
    as conn;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:defyx_vpn/shared/services/animation_service.dart';
import 'package:defyx_vpn/shared/services/alert_service.dart';
import 'package:toastification/toastification.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// D-pad/keyboard traversal for the whole app. Content focused inside a
/// shell page is kept clear of the floating nav bar.
final FocusTraversalPolicy _dpadTraversalPolicy = DpadTraversalPolicy(
  bottomObstruction: (context) =>
      DpadShellPage.contains(context) ? DefyxNavBar.coveredHeight(context) : 0,
);

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  bool _hasCheckedInitialization = false;

  bool get _isMobilePlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Widget build(BuildContext context) {
    // The AdMob decision can arrive after the privacy notice was accepted
    // (fresh install) or change when new server settings are saved. Listening
    // also creates the provider eagerly, without rebuilding the app.
    ref.listen(adEnvironmentProvider, (previous, next) => _maybeStartAdFlow());

    // Ads only for users known not to be premium. Once that is known (the
    // settings loaded, or a plan ended), set ads up and fill the box.
    ref.listen(adsAllowedProvider, (previous, allowed) {
      if (!allowed) return;
      _maybeStartAdFlow();
      ref.read(adStrategyManagerProvider)?.preloadGoogleAd();
    });

    // Keep the vibration alert backend in sync with the Haptic Feedback setting
    ref.listen(hapticsProvider, (previous, next) {
      if (_isMobilePlatform) {
        AlertService().setActionEnabled(next);
      }
    });

    // Single listener for ad readiness state changes
    ref.listen(adReadinessCoordinatorProvider, (previous, next) {
      if (previous == null) return;

      // When canInitializeAdMob transitions to true, start the flow
      if (next.canInitializeAdMob && !previous.canInitializeAdMob) {
        _maybeStartAdFlow();
      }

      // When consent completes and we're disconnected, retry ad load
      if (next.canLoadAds && !previous.canLoadAds) {
        final connectionState = ref.read(conn.connectionStateProvider).status;
        if (connectionState == conn.ConnectionStatus.disconnected) {
          debugPrint('Consent complete & disconnected - triggering ad load');
          Future.delayed(const Duration(milliseconds: 100), () {
            ref.read(adStrategyManagerProvider)?.preloadGoogleAd();
          });
        }
      }
    });

    return FutureBuilder<void>(
      future: _initializeApp(),
      builder: (context, snapshot) {
        // Check ONCE if we need to initialize ads after app startup (e.g., after migration)
        if (snapshot.connectionState == ConnectionState.done &&
            !_hasCheckedInitialization) {
          _hasCheckedInitialization = true;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybeStartAdFlow();
          });
        }
        return _buildApp(context);
      },
    );
  }

  Future<void> _initializeApp() async {
    // Initialize cache directory for VPN core
    try {
      final String vpnCacheDir = await VpnBridge().getSharedDirectory();
      await VpnBridge().setCacheDir(vpnCacheDir);
      debugPrint('VPN cache directory set to: $vpnCacheDir');
    } catch (e) {
      debugPrint('Failed to set cache directory: $e');
    }

    await VPN(ProviderScope.containerOf(context, listen: false)).getVPNStatus();
    await AlertService().init();
    if (_isMobilePlatform) {
      AlertService().setActionEnabled(ref.read(hapticsProvider));
    }
    await AnimationService().init();
  }

  /// Runs the consent check and AdMob setup once both the AdMob decision and
  /// the privacy notice allow it. Safe to call repeatedly: the coordinator
  /// runs the flow once per launch.
  void _maybeStartAdFlow() {
    // Premium users get no ads, so no ad consent form or AdMob setup either.
    if (!ref.read(adsAllowedProvider)) return;
    final environment = ref.read(adEnvironmentProvider).valueOrNull;
    if (environment == null) return; // Server settings not saved yet.
    if (!environment.shouldInitializeAdMob) {
      debugPrint('Using in-house ads only ($environment)');
      return;
    }
    if (!ref.read(adReadinessCoordinatorProvider).canInitializeAdMob) return;
    _initializeAdFlow();
  }

  /// Initialize ad flow using the coordinator
  void _initializeAdFlow() {
    final coordinator = ref.read(adReadinessCoordinatorProvider.notifier);
    final umpService = ref.read(umpServiceProvider);

    coordinator.initializeAdFlow(
      onRunUMP: (shouldRequestUMP) async {
        if (shouldRequestUMP) {
          await umpService.requestConsentWithATT(ref: ref, onDone: () {});
        }
      },
    );
  }

  Widget _buildApp(BuildContext context) {
    final router = ref.watch(routerProvider);
    final languageState = ref.watch(languageProvider);
    final designSize = _getDesignSize(context);

    AppTheme.updateFontFamilyForLocale(languageState.language.locale);

    return ToastificationWrapper(
      config: ToastificationConfig(
        maxToastLimit: 1,
        blockBackgroundInteraction: false,
        applyMediaQueryViewInsets: true,
      ),
      child: ScreenUtilInit(
        designSize: designSize,
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, __) {
          return MaterialApp.router(
            title: 'Defyx',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            routerConfig: router,
            builder: _appBuilder,
            debugShowCheckedModeBanner: false,
            locale: languageState.language.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('fa'),
              Locale('ru'),
              Locale('zh'),
            ],
          );
        },
      ),
    );
  }

  Size _getDesignSize(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isLargeTablet = size.width > 900;
    final isDesktop = size.width > 1200;

    if (isDesktop) return const Size(1440, 900);
    if (isLargeTablet) return const Size(1024, 768);
    if (isTablet) return const Size(768, 1024);
    return const Size(393, 852);
  }

  Widget _appBuilder(BuildContext context, Widget? child) {
    // DISABLED: DesktopPlatformHandler overrides VPN channel handler in native code
    // Desktop features (tray menu, etc.) are handled directly in native Linux/Windows code
    // if (Platform.isWindows || Platform.isLinux) {
    //   DesktopPlatformHandler.initialize();
    // }

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
      child: FocusTraversalGroup(
        policy: _dpadTraversalPolicy,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
