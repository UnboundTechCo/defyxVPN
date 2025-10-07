import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../models/speed_test_result.dart';
import '../speed_test_metrics/speed_test_metrics.dart';
import 'semicircular_progress.dart';

class SpeedTestProgressIndicator extends StatefulWidget {
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
  State<SpeedTestProgressIndicator> createState() =>
      _SpeedTestProgressIndicatorState();
}

class _SpeedTestProgressIndicatorState extends State<SpeedTestProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  double _previousProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void didUpdateWidget(SpeedTestProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _previousProgress = oldWidget.progress;
      _progressAnimation = Tween<double>(
        begin: _previousProgress,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ));
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
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
                      progress: _progressAnimation.value,
                      color: widget.color,
                      strokeWidth: 2.w,
                      animation: _progressAnimation,
                    ),
                  ),
                  if (widget.showLoadingIndicator)
                    Positioned(
                      bottom: 0.h,
                      child: SizedBox(
                        width: 30.w,
                        height: 30.h,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.w,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                  if (widget.centerValue != null)
                    Positioned(
                      bottom: 0.h,
                      child: Column(
                        children: [
                          if (widget.subtitle != null) ...[
                            SizedBox(height: 4.h),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontFamily: 'Lato',
                                color: widget.color,
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
                                widget.centerValue!.toStringAsFixed(1),
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
                                  widget.centerUnit ?? '',
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
                  if (widget.showButton && widget.button != null)
                    Positioned(
                      bottom: 0.h,
                      child: widget.button!,
                    ),
                ],
              ),
            ),
            CustomPaint(
              size: Size(250.w, 0.h),
              painter: SemicircularDividerPainter(strokeWidth: 2.w),
            ),
            if (widget.result != null) ...[
              SizedBox(height: 75.h),
              SpeedTestMetricsDisplay(
                downloadSpeed: widget.result!.downloadSpeed,
                uploadSpeed: widget.result!.uploadSpeed,
                ping: widget.result!.ping,
                latency: widget.result!.latency,
                packetLoss: widget.result!.packetLoss,
                jitter: widget.result!.jitter,
                showDownload: true,
                showUpload: true,
              ),
            ],
          ],
        );
      },
    );
  }
}
