import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

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
      onTap: () async {
        if (!enable) return;
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
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
}
