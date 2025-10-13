import 'package:defyx_vpn/modules/main/presentation/widgets/google_ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SpeedTestAdsOverlay extends StatelessWidget {
  final VoidCallback? onClose;
  final GoogleAds googleAds;

  const SpeedTestAdsOverlay({
    super.key,
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
        child: googleAds,
      ),
    );
  }
}
