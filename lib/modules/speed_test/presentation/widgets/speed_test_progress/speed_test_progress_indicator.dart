import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../models/speed_test_result.dart';
import '../speed_test_metrics/speed_test_metrics.dart';
import 'components/progress_arc_stack.dart';
import 'components/speed_value_display.dart';

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
  final SpeedTestStep? currentStep;

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
    this.currentStep,
  });

  @override
  State<SpeedTestProgressIndicator> createState() => _SpeedTestProgressIndicatorState();
}

class _SpeedTestProgressIndicatorState extends State<SpeedTestProgressIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  late AnimationController _gridAnimationController;
  late Animation<double> _gridAnimation;
  double _previousProgress = 0.0;
  double _uploadProgress = 0.0;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
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

    _gridAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _gridAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_gridAnimationController);
  }

  @override
  void didUpdateWidget(SpeedTestProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _updateProgressAnimation();
      _updateStepProgress();
    }
  }

  void _updateProgressAnimation() {
    _previousProgress = _progressAnimation.value;
    _progressAnimation = Tween<double>(
      begin: _previousProgress,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward(from: 0.0);
  }

  void _updateStepProgress() {
    setState(() {
      if (widget.currentStep == SpeedTestStep.upload) {
        _uploadProgress = widget.progress;
        _downloadProgress = 0.0;
      } else if (widget.currentStep == SpeedTestStep.download) {
        _uploadProgress = 0.0;
        _downloadProgress = widget.progress;
      } else {
        _uploadProgress = widget.progress;
        _downloadProgress = widget.progress;
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _gridAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return SizedBox(
          width: 350.w,
          height: 380.h,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0.h,
                bottom: 100.h,
                child: ProgressArcStack(
                  uploadProgress: _uploadProgress,
                  downloadProgress: _downloadProgress,
                  color: widget.color,
                  progressAnimation: _progressAnimation,
                  gridAnimation: _gridAnimation,
                  showLoadingIndicator: widget.showLoadingIndicator,
                  showButton: widget.showButton,
                  button: widget.button,
                  centerContent: _buildCenterContent(),
                ),
              ),
              if (widget.result != null)
                Positioned(
                  bottom: 0.h,
                  left: 0.w,
                  right: 0.w,
                  child: SpeedTestMetricsDisplay(
                    downloadSpeed: widget.result!.downloadSpeed,
                    uploadSpeed: widget.result!.uploadSpeed,
                    ping: widget.result!.ping,
                    latency: widget.result!.latency,
                    packetLoss: widget.result!.packetLoss,
                    jitter: widget.result!.jitter,
                    showDownload: true,
                    showUpload: true,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget? _buildCenterContent() {
    if (widget.centerValue == null || widget.centerUnit == null) {
      return null;
    }

    return SpeedValueDisplay(
      value: widget.centerValue!,
      unit: widget.centerUnit!,
      subtitle: widget.subtitle,
      subtitleColor: widget.color,
    );
  }
}
