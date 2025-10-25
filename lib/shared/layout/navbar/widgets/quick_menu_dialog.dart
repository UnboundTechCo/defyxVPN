import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/introduction_dialog.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/quick_menu_item.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/social_icon_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class QuickMenuDialog extends StatefulWidget {
  const QuickMenuDialog({super.key});

  @override
  State<QuickMenuDialog> createState() => _QuickMenuDialogState();
}

class _QuickMenuDialogState extends State<QuickMenuDialog> {
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
          bottom: 115.h,
          right: 24.w,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 230.w,
              decoration: BoxDecoration(
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
                  QuickMenuItem(
                    title: 'Introduction',
                    onTap: () {
                      Navigator.of(context).pop();
                      showCupertinoDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (ctx) => const IntroductionDialog(),
                      );
                    },
                  ),
                  Divider(height: 1.h, thickness: 1, color: const Color(0x8080808C)),
                  QuickMenuItem(
                    title: 'Privacy policy',
                    onTap: () async {
                      final uri = Uri.parse('https://defyxvpn.com/privacy-policy');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  Divider(height: 1.h, thickness: 1, color: const Color(0x8080808C)),
                  QuickMenuItem(
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
                        SocialIconButton(
                          iconPath: AppIcons.telegramPath,
                          url: 'https://t.me/defyxvpn',
                        ),
                        SocialIconButton(
                          iconPath: AppIcons.instagramPath,
                          url: 'https://instagram.com/defyxvpn',
                        ),
                        SocialIconButton(
                          iconPath: AppIcons.xPath,
                          url: 'https://x.com/defyxvpn',
                        ),
                        SocialIconButton(
                          iconPath: AppIcons.facebookPath,
                          url: 'https://fb.com/defyxvpn',
                        ),
                        SocialIconButton(
                          iconPath: AppIcons.linkedinPath,
                          url: 'https://linkedin.com/company/defyxvpn',
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1.h, thickness: 1, color: const Color(0x8080808C)),
                  QuickMenuItem(
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
                            fontSize: 17.sp,
                            color: const Color(0xff747474),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _version,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: const Color(0xff141414),
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
