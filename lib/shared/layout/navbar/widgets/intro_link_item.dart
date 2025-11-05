import 'package:defyx_vpn/shared/layout/navbar/widgets/custom_webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class IntroLinkItem extends StatelessWidget {
  final String title;
  final String url;

  const IntroLinkItem({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CustomWebViewScreen(
              url: url,
              title: title,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        height: 56.h,
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
              ),
            ),
            Icon(Icons.chevron_right, size: 20.w, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
