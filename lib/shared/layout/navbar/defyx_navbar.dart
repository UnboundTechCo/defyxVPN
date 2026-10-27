import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/modules/settings/providers/settings_provider.dart';
import 'package:defyx_vpn/shared/providers/app_screen_provider.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/defyx_nav_item.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/quick_menu_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';

class DefyxNavBar extends ConsumerStatefulWidget {
  const DefyxNavBar({super.key});

  @override
  ConsumerState<DefyxNavBar> createState() => _DefyxNavBarState();
}

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
        padding: EdgeInsets.only(bottom: 20.h),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 200.w,
              height:
                  (Theme.of(context).platform == TargetPlatform.iOS ||
                      Theme.of(context).platform == TargetPlatform.android)
                  ? 65.h
                  : 75.h,
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
              child: Focus(
                focusNode: _infoBtnFocusNode,
                onFocusChange: (_) => setState(() {}),
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.select ||
                          event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                          event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
                    _showShareDialog(context, ref);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _showShareDialog(context, ref),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 60.w,
                      height: 60.w,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: _infoBtnFocusNode.hasFocus
                            ? Border.all(
                                color: const Color(0xFFFFD700),
                                width: 2.0,
                              )
                            : null,
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
    switch (location) {
      case '/main':
        return AppScreen.home;
      case '/settings':
        return AppScreen.settings;
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
