import 'dart:io';

import 'package:defyx_vpn/app/advertise_director.dart';
import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/modules/core/vpn.dart';
import 'package:defyx_vpn/modules/core/desktop_platform_handler.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/ump_service.dart';
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
    return FutureBuilder<bool>(
      future: _initializeApp(ref),
      builder: (context, snapshot) {
        _handleAdConfiguration(snapshot, ref);
        return _buildApp(context, ref);
      },
    );
  }

  Future<bool> _initializeApp(WidgetRef ref) async {
    await VPN(ProviderScope.containerOf(ref.context)).getVPNStatus();
    await AlertService().init();
    await AnimationService().init();
    return await AdvertiseDirector.shouldUseInternalAds(ref);
  }

  void _handleAdConfiguration(AsyncSnapshot<bool> snapshot, WidgetRef ref) {
    if (!snapshot.hasData) return;

    final shouldUseInternalAds = snapshot.data!;
    if (shouldUseInternalAds) {
      debugPrint('Using internal ads');
    } else {
      _initializeMobileAdsWithConsent(ref);
    }
  }

  Future<void> _initializeMobileAdsWithConsent(WidgetRef ref) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Get UMP service with cache integration
        final umpService = ref.read(umpServiceProvider);
        
        // Request UMP consent (checks cache first)
        await umpService.requestConsent(
          onDone: () async {
            // Initialize Mobile Ads after consent flow completes
            await MobileAds.instance.initialize();
            debugPrint('Google AdMob initialized with UMP consent');
          },
        );
      }
    } catch (error) {
      debugPrint('Error initializing Google AdMob: $error');
    }
  }

  Widget _buildApp(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    final designSize = _getDesignSize(context);

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
              // Force English locale (comment out to enable device language detection)
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en'),
                Locale('fa'),
                Locale('zh'),
                Locale('ru'),
              ],
            );
          },
        ));
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
