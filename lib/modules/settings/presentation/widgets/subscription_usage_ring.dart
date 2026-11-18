import 'dart:math' as math;

import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/shared/services/animation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

class SubscriptionUsageRing extends StatelessWidget {
  final double usedFraction;
  final String remaining;
  final String total;
  final String label;
  final Color color;

  const SubscriptionUsageRing({
    super.key,
    required this.usedFraction,
    required this.remaining,
    required this.total,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _UsageRingPainter(
        usedFraction: usedFraction,
        color: color,
        strokeWidth: 10.w,
      ),
      child: Padding(
        padding: EdgeInsets.all(18.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: RichText(
                  maxLines: 1,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: remaining,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: '/$total',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF3D3D3D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 6.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 9.5.sp,
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF4B4B4B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubscriptionUsageRingShimmer extends StatelessWidget {
  const SubscriptionUsageRingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE9E9E9),
      highlightColor: const Color(0xFFF8F8F8),
      enabled: AnimationService().shouldAnimate(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 10.w),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBar(width: 78.w, height: 18.h),
              SizedBox(height: 8.h),
              _buildBar(width: 62.w, height: 9.h),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6.r),
      ),
    );
  }
}

class _UsageRingPainter extends CustomPainter {
  static const double _startAngle = 112.5 * math.pi / 180;
  static const Color _trackColor = Color(0xFFF3F3F3);

  final double usedFraction;
  final Color color;
  final double strokeWidth;

  const _UsageRingPainter({
    required this.usedFraction,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = _trackColor;

    canvas.drawCircle(center, radius, paint);
    if (usedFraction <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _startAngle,
      usedFraction * 2 * math.pi,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_UsageRingPainter oldDelegate) =>
      oldDelegate.usedFraction != usedFraction ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
