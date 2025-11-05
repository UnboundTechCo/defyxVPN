import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:defyx_vpn/shared/layout/main_screen_background.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart' as conn;

import '../widgets/speed_test_header.dart';
import '../../application/speed_test_provider.dart';
import '../../models/speed_test_result.dart';
import '../widgets/speed_test_state/speed_test_download/speed_test_download_state.dart';
import '../widgets/speed_test_state/speed_test_loading/speed_test_loading_state.dart';
import '../widgets/speed_test_state/speed_test_ready/speed_test_ready_state.dart';
import '../widgets/speed_test_state/speed_test_upload/speed_test_upload_state.dart';
import '../widgets/speed_test_toast_message.dart';

class SpeedTestScreen extends ConsumerStatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  ConsumerState<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends ConsumerState<SpeedTestScreen> {
  // TODO: After fixing ads issue, enable this code to manage ads during speed test
  // late final GoogleAds _googleAds;

  @override
  void initState() {
    super.initState();

    // TODO: After fixing ads issue, enable this code to initialize Google Ads
    // _googleAds = GoogleAds(
    //   backgroundColor: const Color(0xFF1A1A1A),
    //   cornerRadius: 10.0.r,
    // );

    // Initialization complete - all state management is handled by providers
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

  /*
  @override
  void dispose() {
    // If needed, stop and reset the speed test
    Future.microtask(() {
      try {
        ref.read(speedTestProvider.notifier).stopAndResetTest();
      } catch (e) {
        debugPrint('Speed test provider already disposed: $e');
      }
    });
    super.dispose();
  }
  */

  @override
  Widget build(BuildContext context) {
    final speedTestState = ref.watch(speedTestProvider);
    final connectionState = ref.watch(conn.connectionStateProvider);

    /*
    ref.listen<SpeedTestState>(speedTestProvider, (previous, next) {
      if (previous?.step != next.step) {
        _handleStepChange(previous, next);
      }
    });
    */

    // TODO: After fixing ads issue, enable this code to complete test after ads
    /*
    ref.listen(googleAdsProvider, (previous, next) {
      if (!next.showCountdown &&
          next.shouldDisposeAd &&
          mounted) {
        Future(() {
          if (mounted) {
            ref.read(speedTestProvider.notifier).completeTest();
          }
        });
      }
    });
    */

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

// TODO: After fixing ads issue, enable this code to start countdown timer when entering ads step
/*
  // void _handleStepChange(SpeedTestState? previous, SpeedTestState next) {
    // Handle ads step
    if (next.step == SpeedTestStep.ads) {
      Future.microtask(() {
        if (mounted) {
          ref.read(googleAdsProvider.notifier).startCountdownTimer();
        }
      });
    }
  }
*/

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

  Widget _buildMainContent(SpeedTestState state, conn.ConnectionStatus connectionStatus) {
    if (state.step == SpeedTestStep.ready && !_isConnectionValid(connectionStatus)) {
      debugPrint('Connection not valid, showing loading state. Status: $connectionStatus');
      return const SpeedTestLoadingState();
    }

    switch (state.step) {
      case SpeedTestStep.ready:
        return SpeedTestReadyState(
          onRetry: () {
            ref.read(speedTestProvider.notifier).startTest();
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
    }
  }

  bool _shouldShowToastOverlay(SpeedTestState state) {
    return state.errorMessage != null && (state.step == SpeedTestStep.ready);
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
        // TODO: After fixing ads issue, enable this code to show ads overlay
        /*
        Positioned(
          left: 0,
          right: 0,
          bottom: 100.h,
          child: SpeedTestAdsOverlay(
              googleAds: _googleAds,
        ),
        */
      ],
    );
  }
}
