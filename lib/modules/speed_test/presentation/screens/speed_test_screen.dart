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
import '../widgets/speed_test_state/speed_test_result/speed_test_result_state.dart';
import '../widgets/speed_test_state/speed_test_ads/speed_test_ads_state.dart';
import '../widgets/speed_test_state/speed_test_toast/speed_test_toast_message.dart';

class SpeedTestScreen extends ConsumerStatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  ConsumerState<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends ConsumerState<SpeedTestScreen> {
  late final GoogleAds _googleAds;
  Timer? _toastTimer;
  Timer? _resultTimer;
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
    _resultTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speedTestState = ref.watch(speedTestProvider);
    final connectionState = ref.watch(connectionStateProvider);

    ref.listen(googleAdsProvider, (previous, next) {
      if (speedTestState.step == SpeedTestStep.ads &&
          !next.showCountdown &&
          next.shouldDisposeAd &&
          mounted) {
        Future(() {
          if (mounted) {
            ref.read(speedTestProvider.notifier).completeTest();
          }
        });
      }
    });

    return MainScreenBackground(
      connectionStatus: connectionState.status,
      child: SafeArea(
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
    _handleStepTransition(state);
    _handleToastTimer(state);
    _handleResultTimer(state);
    _handleAdsStep(state);

    final mainContent = _buildMainContent(state);
    final shouldShowToast = _shouldShowToastOverlay(state);

    if (!shouldShowToast) {
      return mainContent;
    }

    return _buildContentWithToast(mainContent, state.errorMessage!);
  }

  void _handleStepTransition(SpeedTestState state) {
    if (_previousStep != state.step) {
      if (state.step == SpeedTestStep.ads && _previousStep != null) {
        _stepBeforeAds = _previousStep;
      }
      _previousStep = state.step;
    }

    if (state.step == SpeedTestStep.ready) {
      _stepBeforeAds = null;
    }
  }

  void _handleToastTimer(SpeedTestState state) {
    if (state.step == SpeedTestStep.toast && _toastTimer == null) {
      _startToastTimer(state);
      _triggerVibration();
    } else if (state.step != SpeedTestStep.toast && _toastTimer != null) {
      _cancelToastTimer();
    }
  }

  void _startToastTimer(SpeedTestState state) {
    _toastTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        if (state.testCompleted) {
          ref.read(speedTestProvider.notifier).moveToAds();
        }
        _toastTimer = null;
      }
    });
  }

  void _cancelToastTimer() {
    _toastTimer?.cancel();
    _toastTimer = null;
  }

  void _triggerVibration() {
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator == true) {
        Vibration.vibrate(
          pattern: [0, 200, 100, 200],
          intensities: [0, 128, 0, 255],
        );
      }
    });
  }

  void _handleResultTimer(SpeedTestState state) {
    if (state.step == SpeedTestStep.result && _resultTimer == null) {
      _startResultTimer();
    } else if (state.step != SpeedTestStep.result && _resultTimer != null) {
      _cancelResultTimer();
    }
  }

  void _startResultTimer() {
    _resultTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        ref.read(speedTestProvider.notifier).moveToAds();
        _resultTimer = null;
      }
    });
  }

  void _cancelResultTimer() {
    _resultTimer?.cancel();
    _resultTimer = null;
  }

  void _handleAdsStep(SpeedTestState state) {
    if (state.step == SpeedTestStep.ads) {
      Future.microtask(() {
        if (mounted) {
          ref.read(googleAdsProvider.notifier).startCountdownTimer();
        }
      });
    }
  }

  Widget _buildMainContent(SpeedTestState state) {
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
        return _buildToastState(state);
      case SpeedTestStep.result:
        return SpeedTestResultState(state: state);
      case SpeedTestStep.ads:
        return _buildAdsState(state);
    }
  }

  Widget _buildToastState(SpeedTestState state) {
    return SpeedTestToastState(
      state: state,
      onRetry: () {
        _cancelToastTimer();
        ref.read(speedTestProvider.notifier).retryConnection();
      },
    );
  }

  Widget _buildAdsState(SpeedTestState state) {
    return SpeedTestAdsState(
      state: state,
      previousStep: _stepBeforeAds,
      googleAds: _googleAds,
      onClose: () {
        ref.read(speedTestProvider.notifier).completeTest();
      },
    );
  }

  bool _shouldShowToastOverlay(SpeedTestState state) {
    return state.errorMessage != null &&
        (state.step == SpeedTestStep.ready || state.step == SpeedTestStep.toast);
  }

  Widget _buildContentWithToast(Widget mainContent, String errorMessage) {
    return Stack(
      children: [
        mainContent,
        Positioned(
          left: 0,
          right: 0,
          bottom: 100.h,
          child: SpeedTestToastMessage(
            message: errorMessage,
          ),
        ),
      ],
    );
  }
}
