import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/google_ads.dart';
import 'package:defyx_vpn/shared/layout/main_screen_background.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart' as conn;
import 'package:defyx_vpn/shared/services/vibration_service.dart';

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
  late final VibrationService _vibrationService;
  Timer? _toastTimer;
  Timer? _resultTimer;
  SpeedTestStep? _previousStep;
  SpeedTestStep? _stepBeforeAds;
  bool _isWaitingForConnection = false;
  bool _isButtonClicked = false;
  conn.ConnectionStatus? _previousConnectionStatus;

  @override
  void initState() {
    super.initState();

    _googleAds = GoogleAds(
      backgroundColor: const Color(0xFF1A1A1A),
      cornerRadius: 10.0.r,
    );

    _vibrationService = VibrationService();
    _vibrationService.init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(() {
        if (mounted) {
          /*
          // If needed, reset any ongoing speed test
          ref.read(speedTestProvider.notifier).stopAndResetTest();
          */

          if (ref.read(speedTestProvider).step == SpeedTestStep.ads ||
              ref.read(speedTestProvider).step == SpeedTestStep.toast) {
            ref.read(speedTestProvider.notifier).completeTest();
          }

          final currentConnectionState = ref.read(conn.connectionStateProvider);
          _previousConnectionStatus = currentConnectionState.status;
          debugPrint('Initial connection status: $_previousConnectionStatus');
        }
      });
    });
  }

  /*
  // If needed, stop and reset the speed test
  @override
  void deactivate() {
    Future.microtask(() {
      if (mounted) {
        ref.read(speedTestProvider.notifier).stopAndResetTest();
      }
    });
    super.deactivate();
  }
  */

  @override
  void dispose() {
    /*
    // If needed, stop and reset the speed test
    Future.microtask(() {
      try {
        ref.read(speedTestProvider.notifier).stopAndResetTest();
      } catch (e) {
        debugPrint('Speed test provider already disposed: $e');
      }
    });
    */

    _toastTimer?.cancel();
    _resultTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speedTestState = ref.watch(speedTestProvider);
    final connectionState = ref.watch(conn.connectionStateProvider);

    ref.listen<conn.ConnectionState>(conn.connectionStateProvider, (previous, next) {
      _handleConnectionStateChange(previous, next);
    });

    ref.listen<SpeedTestState>(speedTestProvider, (previous, next) {
      if (previous?.step != next.step) {
        _handleStepChange(previous, next);
      }
    });

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
                    child: _buildContent(speedTestState, connectionState.status),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleConnectionStateChange(conn.ConnectionState? previous, conn.ConnectionState next) {
    final currentStatus = next.status;

    if (_previousConnectionStatus != currentStatus) {
      debugPrint('Connection status changed from $_previousConnectionStatus to $currentStatus');
      _previousConnectionStatus = currentStatus;

      if (_isWaitingForConnection && _isButtonClicked && _isConnectionValid(currentStatus)) {
        _isWaitingForConnection = false;

        final speedTestState = ref.read(speedTestProvider);
        if (speedTestState.step == SpeedTestStep.ready && mounted) {
          Future.microtask(() {
            if (mounted) {
              debugPrint(
                  'Starting speed test after connection became valid and button was clicked');
              ref.read(speedTestProvider.notifier).startTest();
              _isButtonClicked = false;
            }
          });
        }
      } else if (!_isConnectionValid(currentStatus)) {
        final speedTestState = ref.read(speedTestProvider);
        if (speedTestState.step == SpeedTestStep.ready) {
          _isWaitingForConnection = true;
          debugPrint('Waiting for valid connection status...');
        }
      }
    }
  }

  void _handleStepChange(SpeedTestState? previous, SpeedTestState next) {
    // Handle step transition tracking
    if (_previousStep != next.step) {
      if (next.step == SpeedTestStep.ads && _previousStep != null) {
        _stepBeforeAds = _previousStep;
      }
      _previousStep = next.step;
    }

    if (next.step == SpeedTestStep.ready) {
      _stepBeforeAds = null;
    }

    // Handle toast timer
    if (next.step == SpeedTestStep.toast && _toastTimer == null) {
      _startToastTimer(next);
      _triggerVibration();
    } else if (next.step != SpeedTestStep.toast && _toastTimer != null) {
      _cancelToastTimer();
    }

    // Handle result timer
    if (next.step == SpeedTestStep.result && _resultTimer == null) {
      _startResultTimer();
    } else if (next.step != SpeedTestStep.result && _resultTimer != null) {
      _cancelResultTimer();
    }

    // Handle ads step
    // TODO: After fixing ads issue, enable this code to start countdown timer when entering ads step
    /*
    if (next.step == SpeedTestStep.ads) {
      Future.microtask(() {
        if (mounted) {
          ref.read(googleAdsProvider.notifier).startCountdownTimer();
        }
      });
    }
    */
  }

  bool _isConnectionValid(conn.ConnectionStatus status) {
    return status == conn.ConnectionStatus.disconnected ||
        status == conn.ConnectionStatus.connected;
  }

  Widget _buildContent(SpeedTestState state, conn.ConnectionStatus connectionStatus) {
    final mainContent = _buildMainContent(state, connectionStatus);
    final shouldShowToast = _shouldShowToastOverlay(state);

    if (!shouldShowToast) {
      return mainContent;
    }

    return _buildContentWithToast(mainContent, state.errorMessage!);
  }

  void _startToastTimer(SpeedTestState state) {
    ref.read(speedTestProvider.notifier).completeTest();
    // TODO: After fixing toast issue, enable this code to moveToAds
    /*
    _toastTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        if (state.testCompleted) {
          ref.read(speedTestProvider.notifier).moveToAds();
        }
        _toastTimer = null;
      }
    });
    */
  }

  void _cancelToastTimer() {
    _toastTimer?.cancel();
    _toastTimer = null;
  }

  void _triggerVibration() {
    _vibrationService.vibrateError();
  }

  void _startResultTimer() {
    ref.read(speedTestProvider.notifier).completeTest();
    // TODO: After fixing ads issue, enable this code to moveToAds
    /*
    _resultTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        ref.read(speedTestProvider.notifier).moveToAds();
        _resultTimer = null;
      }
    });
    */
  }

  void _cancelResultTimer() {
    _resultTimer?.cancel();
    _resultTimer = null;
  }

  Widget _buildMainContent(SpeedTestState state, conn.ConnectionStatus connectionStatus) {
    if (state.step == SpeedTestStep.ready) {
      if (!_isConnectionValid(connectionStatus)) {
        _isWaitingForConnection = true;
        debugPrint('Connection not valid, showing loading state. Status: $connectionStatus');
        return const SpeedTestLoadingState();
      } else {
        if (_isWaitingForConnection) {
          _isWaitingForConnection = false;
          debugPrint('Connection is now valid. Status: $connectionStatus');
        }
      }
    }

    switch (state.step) {
      case SpeedTestStep.ready:
        return SpeedTestReadyState(
          onButtonClicked: () {
            _isButtonClicked = true;
            debugPrint('Speed test button clicked');
          },
        );
      case SpeedTestStep.loading:
        return const SpeedTestLoadingState();
      case SpeedTestStep.download:
        return SpeedTestDownloadState(
          state: state,
          onStop: () {
            ref.read(speedTestProvider.notifier).stopAndResetTest();
          },
        );
      case SpeedTestStep.upload:
        return SpeedTestUploadState(
            state: state,
            onStop: () {
              ref.read(speedTestProvider.notifier).stopAndResetTest();
            });
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
