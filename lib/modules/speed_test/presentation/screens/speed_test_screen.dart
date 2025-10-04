import 'package:defyx_vpn/modules/main/presentation/widgets/google_ads.dart';
import 'package:defyx_vpn/modules/speed_test/application/speed_test_provider.dart';
import 'package:defyx_vpn/modules/speed_test/models/speed_test_result.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/semicircular_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

class SpeedTestScreen extends ConsumerStatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  ConsumerState<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends ConsumerState<SpeedTestScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  StreamSubscription? _accelerometerSubscription;
  late final GoogleAds _googleAds;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _animationController.forward();

    _googleAds = GoogleAds(
      backgroundColor: const Color(0xFF1A1A1A),
      cornerRadius: 10.0.r,
    );

    _setupShakeDetector();
  }

  void _setupShakeDetector() {
    const threshold = 2.7;
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final gForce = event.x.abs() + event.y.abs() + event.z.abs();
      if (gForce > threshold * 9.81) {
        final state = ref.read(speedTestProvider);
        // Allow shake retry only in toast state with error
        if (state.step == SpeedTestStep.toast) {
          ref.read(speedTestProvider.notifier).retryConnection();
          Fluttertoast.showToast(
            msg: "Retrying connection...",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 14.sp,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speedTestState = ref.watch(speedTestProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 100),
          child: _buildContent(speedTestState),
        ),
      ),
    );
  }

  Widget _buildContent(SpeedTestState state) {
    switch (state.step) {
      case SpeedTestStep.ready:
        return _buildReadyState();
      case SpeedTestStep.loading:
        return _buildLoadingState();
      case SpeedTestStep.download:
        return _buildDownloadState(state);
      case SpeedTestStep.upload:
        return _buildUploadState(state);
      case SpeedTestStep.toast:
        return _buildToastState(state);
      case SpeedTestStep.ads:
        return _buildAdsState(state);
    }
  }

  Widget _buildReadyState() {
    final state = ref.watch(speedTestProvider);
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildProgressIndicator(
                    progress: 0.0,
                    color: Colors.green,
                    showButton: true,
                  ),
                  SizedBox(height: 40.h),
                  Text(
                    'Defyx is ready\nto speed test',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontFamily: 'Lato',
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomMetrics(state.result),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final state = ref.watch(speedTestProvider);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildProgressIndicator(
                  progress: 0.0,
                  color: Colors.blue,
                  showButton: false,
                  showLoadingIndicator: true,
                ),
                SizedBox(height: 40.h),
                Text(
                  'Defyx is\ntesting speed ...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontFamily: 'Lato',
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildBottomMetrics(state.result),
      ],
    );
  }

  Widget _buildDownloadState(SpeedTestState state) {
    // Calculate progress based on speed (0-100 Mbps range, normalized)
    final speedProgress = (state.currentSpeed / 100).clamp(0.0, 1.0);
    final combinedProgress = (state.progress * 0.5) + (speedProgress * 0.5);

    return Column(
      children: [
        Expanded(
          child: Center(
            child: _buildProgressIndicator(
              progress: combinedProgress,
              color: Colors.green,
              showButton: false,
              centerText:
                  '${state.currentSpeed > 0 ? state.currentSpeed.toStringAsFixed(1) : state.result.downloadSpeed.toStringAsFixed(1)}\nMbps',
              subtitle: 'DOWNLOAD',
            ),
          ),
        ),
        _buildBottomMetrics(state.result),
      ],
    );
  }

  Widget _buildUploadState(SpeedTestState state) {
    // Calculate progress based on speed (0-50 Mbps range for upload, normalized)
    final speedProgress = (state.currentSpeed / 50).clamp(0.0, 1.0);
    final combinedProgress = (state.progress * 0.5) + (speedProgress * 0.5);

    return Column(
      children: [
        Expanded(
          child: Center(
            child: _buildProgressIndicator(
              progress: combinedProgress,
              color: Colors.blue,
              showButton: false,
              centerText:
                  '${state.currentSpeed > 0 ? state.currentSpeed.toStringAsFixed(1) : state.result.uploadSpeed.toStringAsFixed(1)}\nMbps',
              subtitle: 'UPLOAD',
            ),
          ),
        ),
        _buildBottomMetrics(state.result),
      ],
    );
  }

  Widget _buildToastState(SpeedTestState state) {
    if (!state.isConnectionStable || state.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final message = state.errorMessage ??
            "Connection isn't stable. Tap retry to test again.";
        Fluttertoast.showToast(
          msg: message,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          fontSize: 14.sp,
        );
      });
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildProgressIndicator(
                  progress: 1.0,
                  color: Colors.orange,
                  showButton: true,
                  showRetryButton: true,
                ),
                SizedBox(height: 40.h),
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 60.sp,
                ),
                SizedBox(height: 20.h),
                Text(
                  state.errorMessage != null
                      ? 'Test Failed'
                      : 'Connection Unstable',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontFamily: 'Lato',
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.w),
                  child: Text(
                    'Tap the retry button or shake your phone to test again',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontFamily: 'Lato',
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildBottomMetrics(state.result),
      ],
    );
  }

  Widget _buildAdsState(SpeedTestState state) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildProgressIndicator(
                  progress: 1.0,
                  color: Colors.green,
                  showButton: true,
                ),
                SizedBox(height: 40.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: _googleAds,
                ),
              ],
            ),
          ),
        ),
        _buildBottomMetrics(state.result),
      ],
    );
  }

  Widget _buildProgressIndicator({
    required double progress,
    required Color color,
    required bool showButton,
    bool showLoadingIndicator = false,
    bool showRetryButton = false,
    String? centerText,
    String? subtitle,
  }) {
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
                  strokeWidth: 12.w,
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
              if (centerText != null)
                Positioned(
                  bottom: 30.h,
                  child: Column(
                    children: [
                      Text(
                        centerText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontFamily: 'Lato',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: 4.h),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontFamily: 'Lato',
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (showButton)
                Positioned(
                  bottom: 30.h,
                  child: _buildStartButton(showRetryButton: showRetryButton),
                ),
            ],
          ),
        ),
        SizedBox(height: 20.h),
        CustomPaint(
          size: Size(280.w, 5.h),
          painter: SemicircularDividerPainter(strokeWidth: 2.w),
        ),
      ],
    );
  }

  Widget _buildStartButton({bool showRetryButton = false}) {
    final state = ref.watch(speedTestProvider);

    return GestureDetector(
      onTap: () {
        if (state.step == SpeedTestStep.ready) {
          // Start new test
          ref.read(speedTestProvider.notifier).startTest();
        } else if (state.step == SpeedTestStep.toast) {
          // Always retry on toast state (whether error or unstable)
          ref.read(speedTestProvider.notifier).retryConnection();
        } else if (state.step == SpeedTestStep.ads) {
          // Complete and go back to ready
          ref.read(speedTestProvider.notifier).completeTest();
        }
      },
      child: Container(
        width: 60.w,
        height: 60.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10.r,
              offset: Offset(0, 5.h),
            ),
          ],
        ),
        child: Icon(
          state.step == SpeedTestStep.ready
              ? Icons.play_arrow_rounded
              : state.step == SpeedTestStep.toast
                  ? Icons.refresh_rounded
                  : Icons.check_rounded,
          color: const Color(0xFF0D1B1A),
          size: 36.sp,
        ),
      ),
    );
  }

  Widget _buildBottomMetrics(SpeedTestResult result) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMetricItem('DOWNLOAD', result.downloadSpeed),
          _buildMetricItem('UPLOAD', result.uploadSpeed),
          _buildMetricItem('PING', result.ping, unit: 'ms'),
          _buildMetricItem('LATENCY', result.latency, unit: 'ms'),
          _buildMetricItem('JITTER', result.jitter, unit: 'ms'),
          _buildMetricItem('P.LOSS', result.packetLoss, unit: '%'),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, num value, {String unit = 'Mbps'}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            fontFamily: 'Lato',
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value > 0 ? '${value.toStringAsFixed(1)} $unit' : '--',
          style: TextStyle(
            fontSize: 12.sp,
            fontFamily: 'Lato',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
