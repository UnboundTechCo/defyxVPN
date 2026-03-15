import 'package:defyx_vpn/modules/main/presentation/widgets/ads_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SpeedTestAdsOverlay extends StatelessWidget {
  final AdsWidget adsWidget;

  const SpeedTestAdsOverlay({
    super.key,
    required this.adsWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: adsWidget,
    );
  }
}
