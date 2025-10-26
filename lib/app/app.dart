import 'dart:io' show Platform;
import 'package:defyx_vpn/app/advertise_director.dart';
import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:defyx_vpn/modules/core/vpn.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';

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
    await dotenv.load();
    await _initializeServices(ref);
    return await AdvertiseDirector.shouldUseInternalAds(ref);
  }

  Future<void> _initializeServices(WidgetRef ref) async {
    try {
      final vpnBridge = VpnBridge();
      await vpnBridge.getVpnStatus();
      if (!ref.context.mounted) return;
      final vpn = VPN(ProviderScope.containerOf(ref.context));
      await vpn.getVPNStatus();
      await vpnBridge.setAsnName();
      await ref.read(flowlineServiceProvider).saveFlowline();
    } on PlatformException catch (e, stack) {
      debugPrint('PlatformException: ${e.message}, details: ${e.details}');
      debugPrintStack(stackTrace: stack);
    } catch (e, stack) {
      debugPrint('Unexpected error saving flowline: $e');
      debugPrintStack(stackTrace: stack);
    }
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
      // Only initialize on supported platforms (Android/iOS) TODO:  this part added for test only. When we add appropriate Windows and/or Linux support for ads, this part should be changed
      if (Platform.isAndroid || Platform.isIOS) {
        await MobileAds.instance.initialize();
      } else {
        debugPrint('Skipping AdMob initialization on this platform');
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
          theme: _buildAppTheme(),
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

  ThemeData _buildAppTheme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Lato',
      textTheme: TextTheme(
        bodyLarge: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w400),
      ),
    );
  }

  Widget _appBuilder(BuildContext context, Widget? child) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
