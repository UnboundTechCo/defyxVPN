import 'package:defyx_vpn/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import '../../../models/speed_test_result.dart';
import '../speed_test_metrics/speed_test_metrics.dart';
import 'components/progress_arc_stack.dart';
import 'components/speed_value_display.dart';

class SpeedTestProgressIndicator extends StatefulWidget {
  final double progress;
  final Color? color;
  final bool showButton;
  final bool showLoadingIndicator;
  final double? centerValue;
  final String? centerUnit;
  final String? subtitle;
  final SpeedTestResult? result;
  final Widget? button;
  final SpeedTestStep? currentStep;
  final ConnectionStatus connectionStatus;

  const SpeedTestProgressIndicator({
    super.key,
    required this.progress,
    required this.showButton,
    this.color,
    this.showLoadingIndicator = false,
    this.centerValue,
    this.centerUnit,
    this.subtitle,
    this.result,
    this.button,
    this.currentStep,
    required this.connectionStatus,
  });

  @override
  State<SpeedTestProgressIndicator> createState() => _SpeedTestProgressIndicatorState();
}

class _SpeedTestProgressIndicatorState extends State<SpeedTestProgressIndicator>
    with TickerProviderStateMixin {
  late AnimationController _uploadAnimationController;
  late AnimationController _downloadAnimationController;
  late Animation<double> _uploadProgressAnimation;
  late Animation<double> _downloadProgressAnimation;
  late AnimationController _gridAnimationController;
  late Animation<double> _gridAnimation;
  double _uploadProgress = 0.0;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _uploadAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _uploadProgressAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _uploadAnimationController,
      curve: Curves.easeInOut,
    ));

    _downloadAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _downloadProgressAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _downloadAnimationController,
      curve: Curves.easeInOut,
    ));

    _gridAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _gridAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_gridAnimationController);

    _updateStepProgress();
  }

  @override
  void didUpdateWidget(SpeedTestProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress || oldWidget.currentStep != widget.currentStep) {
      _updateStepProgress();
    }
  }

  void _updateStepProgress() {
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

    _updateUploadAnimation();
    _updateDownloadAnimation();
  }

  void _updateUploadAnimation() {
    final currentValue = _uploadProgressAnimation.value;
    final isDecreasing = _uploadProgress < currentValue;

    final duration =
        isDecreasing ? const Duration(milliseconds: 1200) : const Duration(milliseconds: 400);

    _uploadAnimationController.duration = duration;

    _uploadProgressAnimation = Tween<double>(
      begin: currentValue,
      end: _uploadProgress,
    ).animate(CurvedAnimation(
      parent: _uploadAnimationController,
      curve: isDecreasing ? Curves.easeOutCubic : Curves.easeInOut,
    ));
    _uploadAnimationController.forward(from: 0.0);
  }

  void _updateDownloadAnimation() {
    final currentValue = _downloadProgressAnimation.value;
    final isDecreasing = _downloadProgress < currentValue;

    final duration =
        isDecreasing ? const Duration(milliseconds: 1200) : const Duration(milliseconds: 400);

    _downloadAnimationController.duration = duration;

    _downloadProgressAnimation = Tween<double>(
      begin: currentValue,
      end: _downloadProgress,
    ).animate(CurvedAnimation(
      parent: _downloadAnimationController,
      curve: isDecreasing ? Curves.easeOutCubic : Curves.easeInOut,
    ));
    _downloadAnimationController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _uploadAnimationController.dispose();
    _downloadAnimationController.dispose();
    _gridAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_uploadProgressAnimation, _downloadProgressAnimation]),
      builder: (context, child) {
        return SizedBox(
          width: 350.w,
          height: 435.h,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0.h,
                bottom: 100.h,
                left: 0.w,
                right: 0.w,
                child: ProgressArcStack(
                  uploadProgress: _uploadProgress,
                  downloadProgress: _downloadProgress,
                  color: widget.color,
                  uploadProgressAnimation: _uploadProgressAnimation,
                  downloadProgressAnimation: _downloadProgressAnimation,
                  gridAnimation: _gridAnimation,
                  showLoadingIndicator: widget.showLoadingIndicator,
                  showButton: widget.showButton,
                  button: widget.button,
                  currentStep: widget.currentStep,
                  centerContent: _buildCenterContent(),
                ),
              ),
              if (widget.result != null &&
                  (widget.currentStep != SpeedTestStep.ready && widget.result!.ping > 0))
                Positioned(
                  bottom: 10.h,
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
                    connectionStatus: widget.connectionStatus,
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
      subtitleColor: widget.color ?? AppColors.downloadColor,
    );
  }
}
