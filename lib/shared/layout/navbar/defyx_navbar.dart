import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/shared/providers/app_screen_provider.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/defyx_nav_item.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/quick_menu_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class DefyxNavBar extends ConsumerWidget {
  const DefyxNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final currentScreen = _getCurrentScreenFromLocation(location);

    return SafeArea(
        child: Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 200.w,
            height: 65.h,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(100.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                DefyxNavItem(
                  screen: AppScreen.speedTest,
                  icon: "speed",
                  current: currentScreen,
                  onTap: () => _handleSpeedTest(context, ref),
                ),
                DefyxNavItem(
                  screen: AppScreen.home,
                  icon: "chield",
                  current: currentScreen,
                  onTap: () => _navigateToHome(context),
                ),
                DefyxNavItem(
                  screen: AppScreen.settings,
                  icon: "settings",
                  current: currentScreen,
                  onTap: () => _navigateToSettings(context),
                ),
              ],
            ),
          ),
          Positioned(
            right: 24.w,
            child: GestureDetector(
              onTap: () => _showShareDialog(context, ref),
              child: Container(
                width: 60.w,
                height: 60.w,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/info.svg',
                    width: 25.w,
                    height: 25.w,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }

  void _handleSpeedTest(BuildContext context, WidgetRef ref) {
    context.go(DefyxVPNRoutes.speedTest.route);
  }

  void _navigateToHome(BuildContext context) {
    context.go(DefyxVPNRoutes.main.route);
  }

  void _navigateToSettings(BuildContext context) {
    context.go(DefyxVPNRoutes.settings.route);
  }

  AppScreen _getCurrentScreenFromLocation(String location) {
    switch (location) {
      case '/main':
        return AppScreen.home;
      case '/settings':
        return AppScreen.settings;
      case '/speedTest':
        return AppScreen.speedTest;
      default:
        return AppScreen.home;
    }
  }

  void _showShareDialog(BuildContext context, WidgetRef ref) {
    ref.read(currentScreenProvider.notifier).state = AppScreen.share;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Quick Menu',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const QuickMenuDialog();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
            alignment: Alignment.bottomRight,
            child: child,
          ),
        );
      },
    ).then((_) {
      ref.read(currentScreenProvider.notifier).state = AppScreen.home;
    });
  }
}
