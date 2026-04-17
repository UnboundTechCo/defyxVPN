import 'package:defyx_vpn/app/ad_director_provider.dart';
import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/modules/core/vpn.dart';
import 'package:defyx_vpn/modules/core/desktop_platform_handler.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ump_service.dart';
import 'package:defyx_vpn/shared/providers/language_provider.dart';
import 'package:defyx_vpn/shared/providers/ad_readiness_coordinator.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
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

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly trigger environment computation
    final environmentAsync = ref.watch(adEnvironmentProvider);

    // Single listener for ad readiness state changes
    ref.listen(adReadinessCoordinatorProvider, (previous, next) {
      if (previous == null) return;
      
      // When canInitializeAdMob transitions to true, start the flow
      if (next.canInitializeAdMob && !previous.canInitializeAdMob) {
        debugPrint('🚀 Privacy accepted - starting ad initialization flow');
        
        environmentAsync.whenData((environment) {
          if (environment.shouldInitializeAdMob) {
            _initializeAdFlow(ref);
          } else {
            debugPrint(
              '📱 Using internal ads only (${environment.isIranian ? "Iranian user" : "desktop platform"})',
            );
          }
        });
      }
      
      // When consent completes and we're disconnected, retry ad load
      if (next.canLoadAds && !previous.canLoadAds) {
        final connectionState = ref.read(connectionStateProvider).status;
        if (connectionState == ConnectionStatus.disconnected) {
          debugPrint('✅ Consent complete & disconnected - triggering ad load');
          Future.delayed(const Duration(milliseconds: 100), () {
            ref.read(adStrategyManagerProvider)?.retryGoogleAdLoad();
          });
        }
      }
    });

    return FutureBuilder<void>(
      future: _initializeApp(ref),
      builder: (context, snapshot) => _buildApp(context, ref),
    );
  }

  Future<void> _initializeApp(WidgetRef ref) async {
    await VPN(ProviderScope.containerOf(ref.context)).getVPNStatus();
    await AlertService().init();
    await AnimationService().init();
  }

  /// Initialize ad flow using the coordinator
  void _initializeAdFlow(WidgetRef ref) {
    final coordinator = ref.read(adReadinessCoordinatorProvider.notifier);
    final umpService = ref.read(umpServiceProvider);

    coordinator.initializeAdFlow(
      onRunUMP: (shouldRequestUMP) async {
        if (shouldRequestUMP) {
          debugPrint('🔐 Running UMP consent flow...');
          await umpService.requestConsentWithATT(
            ref: ref,
            onDone: () {
              debugPrint('✅ UMP flow complete - marking consent done');
              coordinator.markConsentComplete();
            },
          );
        } else {
          debugPrint('⏭️ Skipping UMP (ATT denied/restricted)');
          coordinator.markConsentComplete();
        }
      },
    );
  }

  Widget _buildApp(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final languageState = ref.watch(languageProvider);
    final designSize = _getDesignSize(context);

    debugPrint('🌍 Building app with locale: ${languageState.language.locale}');

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
            supportedLocales: const [Locale('en'), Locale('zh')],
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
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      DesktopPlatformHandler.initialize();
    }

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
