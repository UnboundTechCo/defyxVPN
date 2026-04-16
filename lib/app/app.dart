import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:defyx_vpn/app/ad_director_provider.dart';
import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/modules/core/vpn.dart';
import 'package:defyx_vpn/modules/core/desktop_platform_handler.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ump_service.dart';
import 'package:defyx_vpn/shared/providers/language_provider.dart';
import 'package:defyx_vpn/shared/providers/ad_personalization_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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
    ref.read(adEnvironmentProvider);

    return FutureBuilder<void>(
      future: _initializeApp(ref),
      builder: (context, snapshot) {
        _handleAdConfiguration(ref);
        return _buildApp(context, ref);
      },
    );
  }

  Future<void> _initializeApp(WidgetRef ref) async {
    await VPN(ProviderScope.containerOf(ref.context)).getVPNStatus();
    await AlertService().init();
    await AnimationService().init();
  }

  void _handleAdConfiguration(WidgetRef ref) {
    // Use adEnvironmentProvider to decide AdMob initialization
    final environmentAsync = ref.read(adEnvironmentProvider);

    environmentAsync.whenData((environment) {
      if (!environment.shouldInitializeAdMob) {
        debugPrint(
          '📱 Using internal ads only (${environment.isIranian ? "Iranian user" : "desktop platform"})',
        );
      } else {
        debugPrint('📱 Initializing AdMob for mobile non-Iranian user');
        _initializeMobileAdsWithConsent(ref, environment);
      }
    });
  }

  Future<void> _initializeMobileAdsWithConsent(
    WidgetRef ref,
    AdEnvironment environment,
  ) async {
    try {
      // Environment already verified shouldInitializeAdMob = true
      debugPrint('📱 Starting AdMob initialization...');

      if (Platform.isAndroid || Platform.isIOS) {
        // Request App Tracking Transparency (iOS only)
        if (Platform.isIOS) {
          final status =
              await AppTrackingTransparency.trackingAuthorizationStatus;
          if (status == TrackingStatus.notDetermined) {
            // Small delay to ensure UI is ready
            await Future.delayed(const Duration(milliseconds: 500));
            await AppTrackingTransparency.requestTrackingAuthorization();
          }
          // Store ATT status in provider (for both cases)
          await ref
              .read(adPersonalizationProvider.notifier)
              .checkTrackingStatus();
        }

        // UMP service will handle ATT status and decide whether to show consent
        final umpService = ref.read(umpServiceProvider);
        await umpService.requestConsentWithATT(
          ref: ref,
          onDone: () async {
            // Initialize Mobile Ads after consent flow completes
            await MobileAds.instance.initialize();
            debugPrint('📱 Google AdMob initialized');
          },
        );
      }
    } catch (error) {
      debugPrint('Error initializing Google AdMob: $error');
    }
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
