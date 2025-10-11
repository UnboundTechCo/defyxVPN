import 'package:defyx_vpn/modules/main/presentation/widgets/google_ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SpeedTestAdsOverlay extends StatelessWidget {
  final int countdown;
  final VoidCallback? onClose;
  final GoogleAds googleAds;

  const SpeedTestAdsOverlay({
    super.key,
    required this.countdown,
    required this.googleAds,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 130.h,
      left: 0,
      right: 0,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            googleAds,
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                height: 30.h,
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                margin: EdgeInsets.only(bottom: 2.h, left: 2.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(10.r),
                  ),
                ),
                child: Row(
                  spacing: 8.w,
                  children: [
                    Text(
                      'Closing in ${countdown}s',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontFamily: 'Lato',
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    GestureDetector(
                      onTap: countdown <= 0 ? onClose : null,
                      child: Container(
                        width: 20.w,
                        height: 20.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: countdown <= 0 ? Colors.grey.shade700 : Colors.grey.shade800,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14.sp,
                          color: countdown <= 0 ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
