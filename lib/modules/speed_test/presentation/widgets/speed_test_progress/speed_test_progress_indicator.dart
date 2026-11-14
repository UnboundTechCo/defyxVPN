import 'package:defyx_vpn/core/theme/app_colors.dart';
import 'package:defyx_vpn/shared/services/animation_service.dart';
import 'package:defyx_vpn/shared/tv/tv_support.dart';
import 'package:defyx_vpn/shared/widgets/tv_focusable.dart';
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
  final VoidCallback? onStop;

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
    this.onStop,
    required this.connectionStatus,
  });

  @override
  State<SpeedTestProgressIndicator> createState() =>
      _SpeedTestProgressIndicatorState();
}

class _SpeedTestProgressIndicatorState extends State<SpeedTestProgressIndicator>
    with TickerProviderStateMixin {
  final AnimationService _animationService = AnimationService();

  // The controllers' values are the arc fills (0..1).
  late final AnimationController _uploadArc;
  late final AnimationController _downloadArc;
  late final AnimationController _gridAnimationController;
  late final Animation<double> _gridAnimation;
  double _uploadProgress = 0.0;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _uploadArc = AnimationController(vsync: this);
    _downloadArc = AnimationController(vsync: this);

    _gridAnimationController = AnimationController(
      vsync: this,
      duration: _animationService.adjustDuration(const Duration(seconds: 3)),
    );
    _animationService.conditionalRepeat(_gridAnimationController);
    _gridAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_gridAnimationController);

    _updateArcs();
  }

  @override
  void didUpdateWidget(SpeedTestProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress ||
        oldWidget.currentStep != widget.currentStep) {
      _updateArcs();
    }
  }

  void _updateArcs() {
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

    _animateArc(_uploadArc, _uploadProgress);
    _animateArc(_downloadArc, _downloadProgress);
  }

  /// Glides the arc from wherever it is to [target]. A new value arriving
  /// mid-animation continues the movement instead of restarting it.
  void _animateArc(AnimationController arc, double target) {
    if ((arc.value - target).abs() < 0.001) return;
    if (!_animationService.shouldAnimate()) {
      arc.value = target;
      return;
    }
    final falling = target < arc.value;
    arc.animateTo(
      target,
      duration: Duration(milliseconds: falling ? 600 : 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _uploadArc.dispose();
    _downloadArc.dispose();
    _gridAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The arc painters repaint from the controllers on their own, so the
    // rest of this tree only rebuilds when the widget changes.
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
            child: TvFocusRing(
              // Only while a test runs; before that the start button
              // inside this area is the focus target and has its own ring.
              enabled: widget.onStop != null,
              borderRadius: BorderRadius.circular(24.r),
              fillWhenFocused: false,
              child: InkWell(
                onTap: widget.onStop,
                // While a test runs, OK on the remote stops it.
                autofocus: TvSupport.isTv && widget.onStop != null,
                child: ProgressArcStack(
                  uploadProgress: _uploadProgress,
                  downloadProgress: _downloadProgress,
                  color: widget.color,
                  uploadProgressAnimation: _uploadArc,
                  downloadProgressAnimation: _downloadArc,
                  gridAnimation: _gridAnimation,
                  showLoadingIndicator: widget.showLoadingIndicator,
                  showButton: widget.showButton,
                  button: widget.button,
                  currentStep: widget.currentStep,
                  centerContent: _buildCenterContent(),
                ),
              ),
            ),
          ),
          if (widget.result != null &&
              (widget.currentStep != SpeedTestStep.ready &&
                  widget.result!.ping > 0))
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
