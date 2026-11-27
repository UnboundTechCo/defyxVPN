import 'package:defyx_vpn/shared/widgets/tv_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QuickMenuItem extends StatelessWidget {
  final String title;
  final TextStyle? titleStyle;
  final VoidCallback onTap;
  final bool? topBorderRadius;
  final bool? bottomBorderRadius;
  final Widget? icon;
  final Widget? leadingIcon;
  final FocusNode? focusNode;
  final bool autofocus;

  const QuickMenuItem({
    super.key,
    required this.title,
    required this.onTap,
    this.topBorderRadius = false,
    this.bottomBorderRadius = false,
    this.icon,
    this.leadingIcon,
    this.titleStyle,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(topBorderRadius! ? 12.r : 0),
      topRight: Radius.circular(topBorderRadius! ? 12.r : 0),
      bottomLeft: Radius.circular(bottomBorderRadius! ? 12.r : 0),
      bottomRight: Radius.circular(bottomBorderRadius! ? 12.r : 0),
    );

    // One focus stop for the remote; the InkWell only handles touch.
    return TvFocusable(
      onTap: onTap,
      focusNode: focusNode,
      autofocus: autofocus,
      handleTaps: false,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        canRequestFocus: false,
        hoverColor: const Color(0xffDFDFDF),
        splashColor: const Color(0xffDFDFDF),
        highlightColor: const Color(0xffDFDFDF),
        borderRadius: borderRadius,
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (leadingIcon != null) ...[
                    leadingIcon!,
                    SizedBox(width: 10.w),
                  ],
                  Text(
                    title,
                    style:
                        titleStyle ??
                        TextStyle(
                          fontSize: 17.sp,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
              icon ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
