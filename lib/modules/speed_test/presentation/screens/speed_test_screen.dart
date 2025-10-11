import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vibration/vibration.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/google_ads.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/main_screen_background.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';

import '../widgets/speed_test_header.dart';
import '../../application/speed_test_provider.dart';
import '../../models/speed_test_result.dart';
import '../widgets/speed_test_state/speed_test_download/speed_test_download_state.dart';
import '../widgets/speed_test_state/speed_test_loading/speed_test_loading_state.dart';
import '../widgets/speed_test_state/speed_test_ready/speed_test_ready_state.dart';
import '../widgets/speed_test_state/speed_test_toast/speed_test_toast_state.dart';
import '../widgets/speed_test_state/speed_test_upload/speed_test_upload_state.dart';
import '../widgets/speed_test_state/speed_test_ads/speed_test_ads_state.dart';

class SpeedTestScreen extends ConsumerStatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  ConsumerState<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends ConsumerState<SpeedTestScreen> {
  late final GoogleAds _googleAds;
  Timer? _toastTimer;
  Timer? _adsCountdownTimer;
  int _adsCountdown = 10;
  bool _hasCountdownStarted = false;
  SpeedTestStep? _previousStep;
  SpeedTestStep? _stepBeforeAds;

  @override
  void initState() {
    super.initState();

    _googleAds = GoogleAds(
      backgroundColor: const Color(0xFF1A1A1A),
      cornerRadius: 10.0.r,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(() {
        if (mounted) {
          ref.read(speedTestProvider.notifier).stopAndResetTest();
        }
      });
    });
  }

  @override
  void deactivate() {
    Future.microtask(() {
      if (mounted) {
        ref.read(speedTestProvider.notifier).stopAndResetTest();
      }
    });
    super.deactivate();
  }

  @override
  void dispose() {
    Future.microtask(() {
      try {
        ref.read(speedTestProvider.notifier).stopAndResetTest();
      } catch (e) {
        debugPrint('Speed test provider already disposed: $e');
      }
    });

    _toastTimer?.cancel();
    _adsCountdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speedTestState = ref.watch(speedTestProvider);
    final connectionState = ref.watch(connectionStateProvider);

    return MainScreenBackground(
      connectionStatus: connectionState.status,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 393.w),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    children: [
                      SizedBox(height: 45.h),
                      SpeedTestHeader(step: speedTestState.step),
                    ],
                  ),
                  Positioned(
                    top: 130.h,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildContent(speedTestState),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(SpeedTestState state) {
    if (_previousStep != state.step) {
      if (state.step == SpeedTestStep.ads && _previousStep != null) {
        _stepBeforeAds = _previousStep;
      }
      _previousStep = state.step;
    }

    if (state.step == SpeedTestStep.toast && _toastTimer == null) {
      _toastTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) {
          ref.read(speedTestProvider.notifier).moveToAds();
          _toastTimer = null;
        }
      });

      Vibration.hasVibrator().then((hasVibrator) {
        if (hasVibrator == true) {
          Vibration.vibrate(
            pattern: [0, 200, 100, 200],
            intensities: [0, 128, 0, 255],
          );
        }
      });
    } else if (state.step != SpeedTestStep.toast && _toastTimer != null) {
      _toastTimer?.cancel();
      _toastTimer = null;
    }

    if (state.step == SpeedTestStep.ads) {
      if (!_hasCountdownStarted) {
        _hasCountdownStarted = true;
        _adsCountdown = 10;
        _adsCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              if (_adsCountdown > 0) {
                _adsCountdown--;
              }
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
      _hasCountdownStarted = false;
      _adsCountdownTimer?.cancel();
      _adsCountdownTimer = null;
      _stepBeforeAds = null;
    }

    switch (state.step) {
      case SpeedTestStep.ready:
        return const SpeedTestReadyState();
      case SpeedTestStep.loading:
        return const SpeedTestLoadingState();
      case SpeedTestStep.download:
        return SpeedTestDownloadState(state: state);
      case SpeedTestStep.upload:
        return SpeedTestUploadState(state: state);
      case SpeedTestStep.toast:
        return SpeedTestToastState(
          state: state,
          onRetry: () {
            _toastTimer?.cancel();
            _toastTimer = null;
            ref.read(speedTestProvider.notifier).retryConnection();
          },
        );
      case SpeedTestStep.ads:
        return SpeedTestAdsState(
          state: state,
          previousStep: _stepBeforeAds,
          countdown: _adsCountdown,
          googleAds: _googleAds,
          onClose: () {
            _adsCountdownTimer?.cancel();
            _adsCountdownTimer = null;
            _hasCountdownStarted = false;
            ref.read(speedTestProvider.notifier).completeTest();
          },
        );
    }
  }
}
