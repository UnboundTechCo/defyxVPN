import 'dart:math' as math;

import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/modules/settings/providers/settings_provider.dart';
import 'package:defyx_vpn/shared/providers/app_screen_provider.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/defyx_nav_item.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/quick_menu_dialog.dart';
import 'package:defyx_vpn/shared/widgets/tv_focusable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';

class DefyxNavBar extends ConsumerStatefulWidget {
  const DefyxNavBar({super.key});

  static const double _bottomPadding = 20;

  static double _barHeight(TargetPlatform platform) =>
      (platform == TargetPlatform.iOS || platform == TargetPlatform.android)
      ? 65.h
      : 75.h;

  /// The height at the bottom of the screen covered by the floating nav bar.
  ///
  /// Used to keep D-pad-focused content from scrolling behind the bar. Reads
  /// the [MediaQuery] without registering a dependency, so it is safe to call
  /// outside of build.
  static double coveredHeight(BuildContext context) {
    final media = context.getInheritedWidgetOfExactType<MediaQuery>()?.data;
    final barHeight = math.max(
      _barHeight(defaultTargetPlatform),
      _infoButtonSize.w,
    );
    return (media?.padding.bottom ?? 0) + _bottomPadding.h + barHeight;
  }

  @override
  ConsumerState<DefyxNavBar> createState() => _DefyxNavBarState();
}

const double _infoButtonSize = 60;

class _DefyxNavBarState extends ConsumerState<DefyxNavBar> {
  late FocusNode _speedTestFocusNode;
  late FocusNode _homeFocusNode;
  late FocusNode _settingsFocusNode;
  late FocusNode _infoBtnFocusNode;

  @override
  void initState() {
    super.initState();
    _speedTestFocusNode = FocusNode();
    _homeFocusNode = FocusNode();
    _settingsFocusNode = FocusNode();
    _infoBtnFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _speedTestFocusNode.dispose();
    _homeFocusNode.dispose();
    _settingsFocusNode.dispose();
    _infoBtnFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final currentScreen = _getCurrentScreenFromLocation(location);
    final settingsLoading = ref.watch(settingsLoadingProvider);

    final isPremiumScreen = currentScreen == AppScreen.premium;

    if (isPremiumScreen) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: DefyxNavBar._bottomPadding.h),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 200.w,
              height: DefyxNavBar._barHeight(Theme.of(context).platform),
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
                    focusNode: _speedTestFocusNode,
                  ),
                  DefyxNavItem(
                    screen: AppScreen.home,
                    icon: "chield",
                    current: currentScreen,
                    onTap: () => _navigateToHome(context),
                    focusNode: _homeFocusNode,
                  ),
                  DefyxNavItem(
                    screen: AppScreen.settings,
                    icon: "settings",
                    isLoading: settingsLoading,
                    current: currentScreen,
                    onTap: () => _navigateToSettings(context),
                    focusNode: _settingsFocusNode,
                  ),
                ],
              ),
            ),
            Positioned(
              right: 24.w,
              child: TvFocusable(
                focusNode: _infoBtnFocusNode,
                onTap: () => _showShareDialog(context, ref),
                shape: BoxShape.circle,
                child: Container(
                  width: _infoButtonSize.w,
                  height: _infoButtonSize.w,
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
      ),
    );
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
    if (location.startsWith(DefyxVPNRoutes.settings.route)) {
      return AppScreen.settings;
    }
    switch (location) {
      case '/main':
        return AppScreen.home;
      case '/speedTest':
        return AppScreen.speedTest;
      case "/premium":
        return AppScreen.premium;
      default:
        return AppScreen.home;
    }
  }

  void _showShareDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    ref.read(currentScreenProvider.notifier).state = AppScreen.share;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n.quickMenu,
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
