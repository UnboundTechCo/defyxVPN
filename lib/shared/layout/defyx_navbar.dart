import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/shared/providers/app_screen_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => const _QuickMenuDialog(),
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
            colorFilter: ColorFilter.mode(
              isSelected ? Colors.white : Colors.grey,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickMenuDialog extends StatefulWidget {
  const _QuickMenuDialog();

  @override
  State<_QuickMenuDialog> createState() => _QuickMenuDialogState();
}

class _QuickMenuDialogState extends State<_QuickMenuDialog> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          bottom: 105.h,
          right: 24.w,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 230.w,
              decoration: BoxDecoration(
                // color: Colors.white.withAlpha(242),
                color: const Color(0xFFd1d1d1),
                borderRadius: BorderRadius.circular(15.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _QuickMenuItem(
                    title: 'Introduction',
                    onTap: () {
                      Navigator.of(context).pop();
                      showCupertinoDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (ctx) => const _IntroductionDialog(),
                      );
                    },
                  ),
                  Divider(height: 1.h, thickness: 1, color: const Color(0x8080808C)),
                  _QuickMenuItem(
                    title: 'Privacy policy',
                    onTap: () async {
                      final uri = Uri.parse('https://defyxvpn.com/privacy-policy');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  Divider(height: 1.h, thickness: 1, color: const Color(0x8080808C)),
                  _QuickMenuItem(
                    title: 'Terms & condition',
                    onTap: () async {
                      final uri = Uri.parse('https://defyxvpn.com/terms-and-conditions');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  Divider(height: 1.h, thickness: 1, color: const Color(0x8080808C)),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _SocialIconButton(
                          iconPath: AppIcons.telegramPath,
                          url: 'https://t.me/defyxvpn',
                        ),
                        _SocialIconButton(
                          iconPath: AppIcons.instagramPath,
                          url: 'https://instagram.com/defyxvpn',
                        ),
                        _SocialIconButton(
                          iconPath: AppIcons.xPath,
                          url: 'https://x.com/defyxvpn',
                        ),
                        _SocialIconButton(
                          iconPath: AppIcons.facebookPath,
                          url: 'https://fb.com/defyxvpn',
                        ),
                        _SocialIconButton(
                          iconPath: AppIcons.linkedinPath,
                          url: 'https://linkedin.com/company/defyxvpn',
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1.h, thickness: 1, color: const Color(0x8080808C)),
                  _QuickMenuItem(
                    title: 'Our website',
                    onTap: () async {
                      final uri = Uri.parse('https://defyxvpn.com/contact');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  Divider(height: 1.h, thickness: 1, color: const Color(0x8080808C)),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '© DEFYX',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 17.sp,
                            color: Colors.grey,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          _version,
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 14.sp,
                            color: Colors.grey,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IntroductionDialog extends StatelessWidget {
  const _IntroductionDialog();

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
            SizedBox(height: 10.h),
            Text(
              'LEARN MORE',
              style: TextStyle(
                fontFamily: 'Lato',
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 15.h),
            _IntroLinkItem(
              title: 'Source code',
              url: 'https://github.com/UnboundTechCo/defyxVPN',
            ),
            SizedBox(height: 10.h),
            _IntroLinkItem(
              title: 'Open source licenses',
              url:
                  'https://github.com/UnboundTechCo/DXcore?tab=readme-ov-file#third-party-licenses',
            ),
            SizedBox(height: 10.h),
            _CopyableLink(text: 'unboundtech.de/defyx'),
            SizedBox(height: 10.h),
            _IntroLinkItem(
              title: 'Beta Community',
              url: 'https://t.me/+KuigyCHadIpiNDhi',
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

class _QuickMenuItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _QuickMenuItem({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 17.sp,
                color: Colors.black,
                fontFamily: 'Lato',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final String iconPath;
  final String url;

  const _SocialIconButton({
    required this.iconPath,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(50.r),
      child: SizedBox(
        width: 35.w,
        height: 35.w,
        child: Center(
          child: SvgPicture.asset(
            iconPath,
            width: iconPath == AppIcons.telegramPath ? 15.w : 20.w,
            height: iconPath == AppIcons.telegramPath ? 15.w : 20.w,
            colorFilter: const ColorFilter.mode(
              Colors.black,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroLinkItem extends StatelessWidget {
  final String title;
  final String url;

  const _IntroLinkItem({
    required this.title,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
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
            Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.black,
                fontFamily: 'Lato',
              ),
            ),
            Icon(Icons.chevron_right, size: 20.w, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _CopyableLink extends StatefulWidget {
  final String text;
  const _CopyableLink({required this.text});

  @override
  State<_CopyableLink> createState() => _CopyableLinkState();
}

class _CopyableLinkState extends State<_CopyableLink> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8.r),
      onTap: () async {
        await Clipboard.setData(
          ClipboardData(text: widget.text),
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
              widget.text,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.black,
                fontFamily: 'Lato',
              ),
            ),
            _copied
                ? Icon(Icons.check_circle, size: 15.w, color: Colors.green)
                : Icon(Icons.content_copy, size: 15.w, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
