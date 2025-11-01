import 'package:defyx_vpn/core/theme/app_colors.dart';
import 'package:defyx_vpn/modules/speed_test/models/speed_test_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../painters/animated_grid_painter.dart';
import '../painters/semicircular_progress_painter.dart';

class ProgressArcStack extends StatelessWidget {
  final double uploadProgress;
  final double downloadProgress;
  final Color? color;
  final Animation<double> uploadProgressAnimation;
  final Animation<double> downloadProgressAnimation;
  final Animation<double> gridAnimation;
  final bool showLoadingIndicator;
  final Widget? centerContent;
  final Widget? button;
  final bool showButton;
  final SpeedTestStep? currentStep;

  const ProgressArcStack({
    super.key,
    required this.uploadProgress,
    required this.downloadProgress,
    required this.color,
    required this.uploadProgressAnimation,
    required this.downloadProgressAnimation,
    required this.gridAnimation,
    required this.showLoadingIndicator,
    required this.currentStep,
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
          size: Size(250.w, 190.h),
          painter: SemicircularProgressPainter(
            progress: uploadProgress,
            color: color ?? AppColors.uploadColor,
            strokeWidth: 2.w,
            animation: uploadProgressAnimation,
            showStep: ProgressStep.upload,
          ),
        ),
        CustomPaint(
          size: Size(280.w, 190.h),
          painter: SemicircularProgressPainter(
            progress: downloadProgress,
            color: color ?? AppColors.downloadColor,
            strokeWidth: 2.w,
            animation: downloadProgressAnimation,
            showStep: ProgressStep.download,
          ),
        ),
        Positioned(
          top: 235.h,
          child: CustomPaint(
            size: Size(350.w, 45.h),
            painter: AnimatedGridPainter(
              animation: gridAnimation,
              // gridColor: color,
              strokeWidth: 1.w,
            ),
          ),
        ),
        if (showLoadingIndicator)
          Positioned(
            top: 150.h,
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
            top: 100.h,
            child: centerContent!,
          ),
        if (showButton && button != null)
          Positioned(
            top: currentStep == null || currentStep == SpeedTestStep.ready ? 125.h : 150.h,
            child: button!,
          ),
      ],
    );
  }
}
