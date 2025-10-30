import 'package:defyx_vpn/shared/layout/navbar/widgets/custom_webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SocialIconButton extends StatelessWidget {
  final String iconPath;
  final String url;
  final bool enable;
  final double? iconWidth;
  final double? iconHeight;

  const SocialIconButton({
    super.key,
    required this.iconPath,
    required this.url,
    this.enable = true,
    this.iconWidth,
    this.iconHeight,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      hoverColor: enable ? const Color(0xffDFDFDF) : Colors.transparent,
      splashColor: enable ? const Color(0xffDFDFDF) : Colors.transparent,
      highlightColor: enable ? const Color(0xffDFDFDF) : Colors.transparent,
      borderRadius: BorderRadius.circular(50.r),
      onTap: () {
        if (!enable) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CustomWebViewScreen(
              url: url,
              title: _getTitleFromUrl(url),
            ),
          ),
        );
      },
      child: SizedBox(
        width: 35.w,
        height: 35.w,
        child: Center(
          child: SvgPicture.asset(
            iconPath,
            width: iconWidth ?? 22.w,
            height: iconHeight ?? 22.w,
            colorFilter: ColorFilter.mode(
              enable ? Colors.black : const Color(0xffAEAEAE),
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }

  String _getTitleFromUrl(String url) {
    if (url.contains('t.me') || url.contains('telegram')) {
      return 'Telegram';
    } else if (url.contains('instagram')) {
      return 'Instagram';
    } else if (url.contains('x.com') || url.contains('twitter')) {
      return 'X';
    } else if (url.contains('facebook') || url.contains('fb.com')) {
      return 'Facebook';
    } else if (url.contains('linkedin')) {
      return 'LinkedIn';
    } else {
      return 'Social Media';
    }
  }
}
