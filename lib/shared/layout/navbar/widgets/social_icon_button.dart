import 'package:defyx_vpn/shared/utils/open_link.dart';
import 'package:defyx_vpn/shared/widgets/tv_focusable.dart';
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

  Future<void> _handleTap() async {
    if (!enable) return;
    await openLink(url);
  }

  @override
  Widget build(BuildContext context) {
    final highlight = enable ? const Color(0xffDFDFDF) : Colors.transparent;

    // One focus stop for the remote; the InkWell only handles touch.
    return TvFocusable(
      onTap: _handleTap,
      enabled: enable,
      handleTaps: false,
      shape: BoxShape.circle,
      child: InkWell(
        canRequestFocus: false,
        hoverColor: highlight,
        splashColor: highlight,
        highlightColor: highlight,
        borderRadius: BorderRadius.circular(50.r),
        onTap: _handleTap,
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
      ),
    );
  }
}
