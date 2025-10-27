import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

class SocialIconButton extends StatelessWidget {
  final String iconPath;
  final String url;
  final bool enable;

  const SocialIconButton({
    super.key,
    required this.iconPath,
    required this.url,
    this.enable = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () async {
        if (!enable) return;
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(50.r),
      child: SizedBox(
        width: 32.w,
        height: 32.w,
        child: Center(
          child: SvgPicture.asset(
            iconPath,
            width: iconPath == AppIcons.telegramPath ? 18.w : 24.w,
            height: iconPath == AppIcons.telegramPath ? 18.w : 24.w,
            colorFilter: ColorFilter.mode(
              enable ? Colors.black : const Color(0xffAEAEAE),
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
