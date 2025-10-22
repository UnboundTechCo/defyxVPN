import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/modules/main/application/defyx_navbar_prodiver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
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
                _DefyxNavItem(
                  screen: AppScreen.speedTest,
                  icon: "speed",
                  current: currentScreen,
                  onTap: () => _handleSpeedTest(context, ref),
                ),
                _DefyxNavItem(
                  screen: AppScreen.home,
                  icon: "chield",
                  current: currentScreen,
                  onTap: () => _navigateToHome(context),
                ),
                _DefyxNavItem(
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
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _DefyxShareDialog(),
    ).then((_) {
      ref.read(currentScreenProvider.notifier).state = AppScreen.home;
    });
  }
}

class _DefyxNavItem extends StatelessWidget {
  final AppScreen screen;
  final String icon;
  final AppScreen current;
  final VoidCallback onTap;

  static const double _navItemSize = 55;
  static const double _defaultIconSize = 25;
  static const double _selectedIconIncrease = 8;

  const _DefyxNavItem({
    required this.screen,
    required this.icon,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == screen;

    final double iconSize = _defaultIconSize.w;
    final double selectedIncrease = _selectedIconIncrease.w;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _navItemSize.w,
        height: _navItemSize.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? const Color(0xFF555555) : Colors.transparent,
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/icons/$icon.svg',
            width: isSelected ? iconSize + selectedIncrease : iconSize,
            height: isSelected ? iconSize + selectedIncrease : iconSize,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _DefyxShareDialog extends StatelessWidget {
  const _DefyxShareDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
      child: Container(
        padding: EdgeInsets.all(25.w),
        width: 343.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Introduction',
              style: TextStyle(
                fontFamily: 'Lato',
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 15.h),
            Text(
              'The goal of Defyx is to ensure secure access to public information and provide a free browsing experience.',
              style: TextStyle(
                fontFamily: 'Lato',
                fontSize: 15.sp,
                color: Colors.grey,
              ),
            ),
            /*SizedBox(height: 15.h),
            Text(
              'LEARN MORE',
              style: TextStyle(
                fontSize: 12.sp,
                fontFamily: 'Lato',
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),*/
            SizedBox(height: 15.h),
            _DefyxLinkItem(
              title: 'Privacy policy',
              url: 'https://defyxvpn.com/privacy-policy',
              fontSize: 14.sp,
            ),
            SizedBox(height: 10.h),
            _DefyxLinkItem(
              title: 'Terms & conditions',
              url: 'https://defyxvpn.com/terms-and-conditions',
              fontSize: 14.sp,
            ),
            /*SizedBox(height: 10.h),
            _DefyxLinkItem(
              title: 'Download from GitHub',
              url: 'https://github.com/UnboundTechCo/defyxVPN',
              fontSize: 14.sp,
            ),*/
            SizedBox(height: 10.h),
            _DefyxInputLink(fontSize: 14.sp),
            SizedBox(height: 10.h),
            _DefyxLinkItem(
              title: 'Telegram Channel',
              url: 'https://t.me/DefyxVPN',
              fontSize: 14.sp,
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  shadowColor: Colors.transparent,
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 16.h,
                    horizontal: 15.w,
                  ),
                  child: Text(
                    'Got it',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontFamily: 'Lato',
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
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
}

class _DefyxLinkItem extends StatelessWidget {
  final String title;
  final String url;
  final double fontSize;

  const _DefyxLinkItem({
    required this.title,
    required this.url,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 15.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 14.sp, color: Colors.black)),
            AppIcons.chevronLeft(width: 24.w, height: 24.h),
          ],
        ),
      ),
    );
  }
}

class _DefyxInputLink extends StatefulWidget {
  final double fontSize;
  const _DefyxInputLink({required this.fontSize});

  @override
  State<_DefyxInputLink> createState() => _DefyxInputLinkState();
}

class _DefyxInputLinkState extends State<_DefyxInputLink> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8.r),
      onTap: () async {
        await Clipboard.setData(
          const ClipboardData(text: 'https://defyxvpn.com'),
        );
        setState(() => _copied = true);
        Future.delayed(
          const Duration(seconds: 1),
          () => setState(() => _copied = false),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 19.h, horizontal: 15.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'defyxvpn.com',
              style: TextStyle(fontSize: 14.sp, color: Colors.black),
            ),
            _copied
                ? Icon(Icons.check_circle, size: 15.w, color: Colors.green)
                : AppIcons.copy(width: 15.w, height: 15.h),
          ],
        ),
      ),
    );
  }
}
