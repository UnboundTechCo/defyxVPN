import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../models/speed_test_result.dart';
import 'semicircular_progress.dart';
import '../speed_test_metrics/speed_test_metric_item.dart';

class SpeedTestProgressIndicator extends StatelessWidget {
  final double progress;
  final Color color;
  final bool showButton;
  final bool showLoadingIndicator;
  final double? centerValue;
  final String? centerUnit;
  final String? subtitle;
  final SpeedTestResult? result;
  final Widget? button;

  const SpeedTestProgressIndicator({
    super.key,
    required this.progress,
    required this.color,
    required this.showButton,
    this.showLoadingIndicator = false,
    this.centerValue,
    this.centerUnit,
    this.subtitle,
    this.result,
    this.button,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 280.w,
          height: 140.h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(280.w, 140.h),
                painter: SemicircularProgressPainter(
                  progress: progress,
                  color: color,
                  strokeWidth: 2.w,
                ),
              ),
              if (showLoadingIndicator)
                Positioned(
                  bottom: 30.h,
                  child: SizedBox(
                    width: 30.w,
                    height: 30.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.w,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
              if (centerValue != null)
                Positioned(
                  bottom: 0.h,
                  child: Column(
                    children: [
                      if (subtitle != null) ...[
                        SizedBox(height: 4.h),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontFamily: 'Lato',
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        spacing: 4.w,
                        children: [
                          Text(
                            centerValue!.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 50.sp,
                              fontFamily: 'Lato',
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(bottom: 6.h),
                            child: Text(
                              centerUnit ?? '',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontFamily: 'Lato',
                                fontWeight: FontWeight.w400,
                                color: Colors.grey.shade400,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (showButton && button != null)
                Positioned(
                  bottom: 30.h,
                  child: button!,
                ),
            ],
          ),
        ),
        CustomPaint(
          size: Size(250.w, 0.h),
          painter: SemicircularDividerPainter(strokeWidth: 2.w),
        ),
        if (result != null) ...[
          SizedBox(height: 75.h),
          SpeedTestMetrics(result: result!),
        ],
      ],
    );
  }
}

class SpeedTestMetrics extends StatelessWidget {
  final SpeedTestResult result;

  const SpeedTestMetrics({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            spacing: 10.h,
            children: [
              MetricItemCompact(
                label: 'DOWNLOAD',
                value: result.downloadSpeed,
              ),
              MetricItemCompact(
                label: 'PING',
                value: result.ping,
                unit: 'ms',
              ),
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10.h,
            children: [
              MetricItemCompact(
                label: 'UPLOAD',
                value: result.uploadSpeed,
              ),
              Column(
                spacing: 5.h,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MetricItemHorizontal(
                    label: 'LATENCY',
                    value: result.latency,
                    unit: 'ms',
                  ),
                  MetricItemHorizontal(
                    label: 'P.LOSS',
                    value: result.packetLoss,
                    unit: '%',
                  ),
                  MetricItemHorizontal(
                    label: 'JITTER',
                    value: result.jitter,
                    unit: 'ms',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
