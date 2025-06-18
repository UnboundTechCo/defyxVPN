import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final size = MediaQuery.of(context).size;

    // More granular device size detection
    final isTablet = size.width > 600;
    final isLargeTablet = size.width > 900;
    final isDesktop = size.width > 1200;

    return ScreenUtilInit(
      designSize:
          isDesktop
              ? const Size(1440, 900) // Desktop design size
              : isLargeTablet
              ? const Size(1024, 768) // Large tablet design size
              : isTablet
              ? const Size(768, 1024) // iPad design size
              : const Size(393, 852), // Mobile design size
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
