import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QuickMenuItem extends StatelessWidget {
  final String title;
  final TextStyle? titleStyle;
  final VoidCallback onTap;
  final bool? topBorderRadius;
  final bool? bottomBorderRadius;
  final Widget? icon;

  const QuickMenuItem({
    super.key,
    required this.title,
    required this.onTap,
    this.topBorderRadius = false,
    this.bottomBorderRadius = false,
    this.icon,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: const Color(0xffDFDFDF),
      splashColor: const Color(0xffDFDFDF),
      highlightColor: const Color(0xffDFDFDF),
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(topBorderRadius! ? 12.r : 0),
        topRight: Radius.circular(topBorderRadius! ? 12.r : 0),
        bottomLeft: Radius.circular(bottomBorderRadius! ? 12.r : 0),
        bottomRight: Radius.circular(bottomBorderRadius! ? 12.r : 0),
      ),
      child: Container(
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: titleStyle ?? TextStyle(
                fontSize: 17.sp,
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
            ?icon,
          ],
        ),
      ),
    );
  }
}
