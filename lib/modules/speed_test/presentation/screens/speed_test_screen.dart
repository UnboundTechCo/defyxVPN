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
  Timer? _toastTimer;
  Timer? _adsCountdownTimer;
  int _adsCountdown = 10;
  bool _hasCountdownStarted = false;

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

    // Reset speed test when entering the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(() {
        if (mounted) {
          ref.read(speedTestProvider.notifier).stopAndResetTest();
        }
      });
    });
  }

  void _setupShakeDetector() {
    const threshold = 2.7;
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final gForce = event.x.abs() + event.y.abs() + event.z.abs();
      if (gForce > threshold * 9.81) {
        final state = ref.read(speedTestProvider);
        // Allow shake retry only in toast state with error
        if (state.step == SpeedTestStep.toast) {
          // Cancel the auto-transition timer
          _toastTimer?.cancel();
          _toastTimer = null;
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
  void deactivate() {
    // Stop the speed test when the widget is deactivated (e.g., navigating away)
    Future.microtask(() {
      if (mounted) {
        ref.read(speedTestProvider.notifier).stopAndResetTest();
      }
    });
    super.deactivate();
  }

  @override
  void dispose() {
    // Ensure speed test is stopped and reset when leaving the screen (deferred)
    Future.microtask(() {
      try {
        ref.read(speedTestProvider.notifier).stopAndResetTest();
      } catch (e) {
        // Handle case where provider might already be disposed
        print('Speed test provider already disposed: $e');
      }
    });

    _animationController.dispose();
    _accelerometerSubscription?.cancel();
    _toastTimer?.cancel();
    _adsCountdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speedTestState = ref.watch(speedTestProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF18181E), Color(0xFF1C443B), Color(0xFF1F5F4D)],
            stops: [0.2, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(height: 45.h),
              _buildHeader(speedTestState.step),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: _buildContent(speedTestState),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(SpeedTestStep step) {
    String upperText;
    String bottomText;

    switch (step) {
      case SpeedTestStep.loading:
      case SpeedTestStep.download:
      case SpeedTestStep.upload:
        upperText = 'is';
        bottomText = 'testing speed ...';
        break;
      case SpeedTestStep.ready:
      case SpeedTestStep.toast:
      case SpeedTestStep.ads:
        upperText = 'is ready';
        bottomText = 'to speed test';
        break;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'D',
                style: TextStyle(
                  fontSize: 35.sp,
                  fontFamily: 'Lato',
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFC927),
                ),
              ),
              Text(
                'efyx ',
                style: TextStyle(
                  fontSize: 32.sp,
                  fontFamily: 'Lato',
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFFFC927),
                ),
              ),
              Text(
                upperText,
                style: TextStyle(
                  fontSize: 32.sp,
                  fontFamily: 'Lato',
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Text(
            bottomText,
            style: TextStyle(
              fontSize: 32.sp,
              fontFamily: 'Lato',
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(SpeedTestState state) {
    // Start timer when entering toast state
    if (state.step == SpeedTestStep.toast && _toastTimer == null) {
      _toastTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) {
          ref.read(speedTestProvider.notifier).moveToAds();
          _toastTimer = null;
        }
      });
    } else if (state.step != SpeedTestStep.toast && _toastTimer != null) {
      // Cancel timer if we leave toast state
      _toastTimer?.cancel();
      _toastTimer = null;
    }

    // Start countdown when entering ads state (only once)
    if (state.step == SpeedTestStep.ads) {
      if (!_hasCountdownStarted) {
        _hasCountdownStarted = true;
        _adsCountdown = 10;
        _adsCountdownTimer =
            Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              if (_adsCountdown > 0) {
                _adsCountdown--;
              }
              // Stop the timer when countdown reaches 0
              if (_adsCountdown <= 0) {
                timer.cancel();
                _adsCountdownTimer = null;
              }
            });
          } else {
            timer.cancel();
          }
        });
      }
    } else if (state.step == SpeedTestStep.ready) {
      // Reset countdown flag when returning to ready state
      _hasCountdownStarted = false;
      _adsCountdownTimer?.cancel();
      _adsCountdownTimer = null;
    }

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
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(height: 30.h),
          _buildProgressIndicator(
            progress: 0.0,
            color: Colors.green,
            showButton: true,
            result: state.result,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final state = ref.watch(speedTestProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: 30.h),
        _buildProgressIndicator(
          progress: 0.0,
          color: Colors.blue,
          showButton: false,
          showLoadingIndicator: true,
          result: state.result,
        ),
      ],
    );
  }

  Widget _buildDownloadState(SpeedTestState state) {
    // Calculate progress based on speed (0-100 Mbps range, normalized)
    final speedProgress = (state.currentSpeed / 100).clamp(0.0, 1.0);
    final combinedProgress = (state.progress * 0.5) + (speedProgress * 0.5);

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: 30.h),
        _buildProgressIndicator(
          progress: combinedProgress,
          color: Colors.green,
          showButton: false,
          centerValue: state.currentSpeed > 0
              ? state.currentSpeed
              : state.result.downloadSpeed,
          centerUnit: 'Mbps',
          subtitle: 'DOWNLOAD',
          result: state.result,
        ),
      ],
    );
  }

  Widget _buildUploadState(SpeedTestState state) {
    // Calculate progress based on speed (0-50 Mbps range for upload, normalized)
    final speedProgress = (state.currentSpeed / 50).clamp(0.0, 1.0);
    final combinedProgress = (state.progress * 0.5) + (speedProgress * 0.5);

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: 30.h),
        _buildProgressIndicator(
          progress: combinedProgress,
          color: Colors.blue,
          showButton: false,
          centerValue: state.currentSpeed > 0
              ? state.currentSpeed
              : state.result.uploadSpeed,
          centerUnit: 'Mbps',
          subtitle: 'UPLOAD',
          result: state.result,
        ),
      ],
    );
  }

  Widget _buildToastState(SpeedTestState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: 30.h),
        _buildProgressIndicator(
          progress: 1.0,
          color: Colors.orange,
          showButton: true,
          showRetryButton: true,
          result: state.result,
        ),
        SizedBox(height: 40.h),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20.w),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.errorMessage ?? 'Connection unstable. Please try again.',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontFamily: 'Lato',
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdsState(SpeedTestState state) {
    return Stack(
      children: [
        // Main content with progress indicator
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: 30.h),
            _buildProgressIndicator(
              progress: 1.0,
              color: Colors.green,
              showButton: true,
              result: state.result,
            ),
          ],
        ),
        // Ad overlay positioned near bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 20.w),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ADVERTISEMENT',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontFamily: 'Lato',
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Row(
                      spacing: 8.w,
                      children: [
                        Text(
                          'Closing in ${_adsCountdown}s',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontFamily: 'Lato',
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        GestureDetector(
                          onTap: _adsCountdown <= 0
                              ? () {
                                  _adsCountdownTimer?.cancel();
                                  _adsCountdownTimer = null;
                                  _hasCountdownStarted = false;
                                  ref
                                      .read(speedTestProvider.notifier)
                                      .completeTest();
                                }
                              : null,
                          child: Container(
                            width: 20.w,
                            height: 20.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _adsCountdown <= 0
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade800,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 14.sp,
                              color: _adsCountdown <= 0
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                _googleAds,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator({
    required double progress,
    required Color color,
    required bool showButton,
    bool showLoadingIndicator = false,
    bool showRetryButton = false,
    double? centerValue,
    String? centerUnit,
    String? subtitle,
    SpeedTestResult? result,
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
                          subtitle,
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
                            centerValue.toStringAsFixed(1),
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
              if (showButton)
                Positioned(
                  bottom: 30.h,
                  child: _buildStartButton(showRetryButton: showRetryButton),
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
          _buildMetricsUnderProgress(result),
        ],
      ],
    );
  }

  Widget _buildMetricsUnderProgress(SpeedTestResult result) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First row: DOWNLOAD and UPLOAD
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            spacing: 10.h,
            children: [
              _buildMetricItemCompact('DOWNLOAD', result.downloadSpeed),
              _buildMetricItemCompact('PING', result.ping, unit: 'ms'),
            ],
          ),
          // Second row: PING on left, LATENCY/JITTER/P.LOSS on right
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10.h,
            children: [
              _buildMetricItemCompact('UPLOAD', result.uploadSpeed),
              Column(
                spacing: 5.h,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetricItemHorizontal('LATENCY', result.latency,
                      unit: 'ms'),
                  _buildMetricItemHorizontal('P.LOSS', result.packetLoss,
                      unit: '%'),
                  _buildMetricItemHorizontal('JITTER', result.jitter,
                      unit: 'ms'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItemCompact(String label, num value,
      {String unit = 'Mbps'}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 6.h,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontFamily: 'Lato',
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
        value > 0
            ? Text(
                '${value.toStringAsFixed(1)} $unit',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontFamily: 'Lato',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : Container(
                width: 75.w,
                height: 10.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF307065),
                  borderRadius: BorderRadius.circular(15.r),
                ),
              ),
      ],
    );
  }

  Widget _buildMetricItemHorizontal(String label, num value,
      {String unit = 'Mbps'}) {
    // For packet loss, 0.0 is a valid value (good connection)
    // For other metrics, 0 means no data yet
    final bool hasValue = (label == 'P.LOSS') ? true : value > 0;

    return SizedBox(
      width: 115.w,
      height: 20.h,
      child: Stack(
        // spacing: 8.w,
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            top: 5.h,
            left: 0,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                fontFamily: 'Lato',
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          hasValue
              ? Positioned(
                  bottom: 0,
                  right: 0,
                  child: Text(
                    '${value.toStringAsFixed(1)} $unit',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontFamily: 'Lato',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : Positioned(
                  bottom: 2.5.h,
                  right: 0,
                  child: Container(
                    width: 60.w,
                    height: 7.5.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF307065),
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                  ),
                ),
        ],
      ),
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
          // Cancel the auto-transition timer and retry
          _toastTimer?.cancel();
          _toastTimer = null;
          // Always retry on toast state (whether error or unstable)
          ref.read(speedTestProvider.notifier).retryConnection();
        } else if (state.step == SpeedTestStep.ads) {
          // Only allow closing when countdown reaches 0
          if (_adsCountdown <= 0) {
            // Cancel countdown timer and complete
            _adsCountdownTimer?.cancel();
            _adsCountdownTimer = null;
            _hasCountdownStarted = false;
            // Complete and go back to ready
            ref.read(speedTestProvider.notifier).completeTest();
          }
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
}
