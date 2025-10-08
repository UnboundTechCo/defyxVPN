import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../painters/animated_grid_painter.dart';
import '../painters/semicircular_divider_painter.dart';
import '../painters/semicircular_progress_painter.dart';

class ProgressArcStack extends StatelessWidget {
  final double progress;
  final Color color;
  final Animation<double> progressAnimation;
  final Animation<double> gridAnimation;
  final bool showLoadingIndicator;
  final Widget? centerContent;
  final Widget? button;
  final bool showButton;

  const ProgressArcStack({
    super.key,
    required this.progress,
    required this.color,
    required this.progressAnimation,
    required this.gridAnimation,
    required this.showLoadingIndicator,
    this.centerContent,
    this.button,
    required this.showButton,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        CustomPaint(
          size: Size(250.w, 140.h),
          painter: SemicircularDividerPainter(strokeWidth: 2.w),
        ),
        CustomPaint(
          size: Size(280.w, 140.h),
          painter: SemicircularProgressPainter(
            progress: progress,
            color: color,
            strokeWidth: 2.w,
            animation: progressAnimation,
          ),
        ),
        Positioned(
          top: 155.h,
          child: CustomPaint(
            size: Size(250.w, 60.h),
            painter: AnimatedGridPainter(
              animation: gridAnimation,
              gridColor: color,
              strokeWidth: 1.w,
            ),
          ),
        ),
        if (showLoadingIndicator)
          Positioned(
            top: 100.h,
            child: SizedBox(
              width: 30.w,
              height: 30.h,
              child: CircularProgressIndicator(
                strokeWidth: 2.w,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        if (centerContent != null)
          Positioned(
            top: 50.h,
            child: centerContent!,
          ),
        if (showButton && button != null)
          Positioned(
            top: 75.h,
            child: button!,
          ),
      ],
    );
  }
}
