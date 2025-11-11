import 'dart:io';

import 'package:defyx_vpn/app/advertise_director.dart';
import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:defyx_vpn/shared/services/animation_service.dart';
import 'package:defyx_vpn/shared/services/vibration_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<bool>(
      future: _initializeApp(ref),
      builder: (context, snapshot) {
        _handleAdConfiguration(snapshot);
        return _buildApp(context, ref);
      },
    );
  }

  Future<bool> _initializeApp(WidgetRef ref) async {
    await VibrationService().init();
    await AnimationService().init();
    return await AdvertiseDirector.shouldUseInternalAds(ref);
  }

  void _handleAdConfiguration(AsyncSnapshot<bool> snapshot) {
    if (!snapshot.hasData) return;

    final shouldUseInternalAds = snapshot.data!;
    if (shouldUseInternalAds) {
      debugPrint('Using internal ads');
    } else {
      _initializeMobileAds();
    }
  }

  Future<void> _initializeMobileAds() async {
    try {
      if (!Platform.isMacOS) {
        await MobileAds.instance.initialize();
      }
    } catch (error) {
      debugPrint('Error initializing Google AdMob: $error');
    }
  }

  Widget _buildApp(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    final designSize = _getDesignSize(context);

    return ScreenUtilInit(
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
        );
      },
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
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
