import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/speed_test/application/speed_test_provider.dart';
import 'package:defyx_vpn/modules/speed_test/models/speed_test_result.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_progress/speed_test_progress_indicator.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_start_button.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/tv/tv_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SpeedTestReadyState extends ConsumerWidget {
  final VoidCallback onRetry;

  const SpeedTestReadyState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(speedTestProvider);
    final connectionState = ref.watch(connectionStateProvider);

    void handleStartTest() {
      final status = connectionState.status;

      if (status == ConnectionStatus.disconnected ||
          status == ConnectionStatus.connected) {
        ref.read(speedTestProvider.notifier).startTest();
      } else {
        debugPrint(
          'Button clicked but connection status is $status. Will start when connection is valid.',
        );
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SpeedTestProgressIndicator(
            progress: 0.0,
            color: Colors.green,
            showButton: true,
            result: state.result,
            connectionStatus: connectionState.status,
            // On TV the button gets focus so OK starts (or repeats) the test.
            button: state.testCompleted
                ? SpeedTestStartButton(
                    currentStep: SpeedTestStep.ready,
                    isEnabled: true,
                    onTap: onRetry,
                    previousStep: SpeedTestStep.download,
                    autofocus: TvSupport.isTv,
                  )
                : InkWell(
                    onTap: handleStartTest,
                    // The start button below is the D-pad focus stop.
                    canRequestFocus: false,
                    child: Column(
                      spacing: 8.h,
                      children: [
                        Text(
                          AppLocalizations.of(context).tapHere,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFFABABAB),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SpeedTestStartButton(
                          currentStep: SpeedTestStep.ready,
                          isEnabled: true,
                          onTap: handleStartTest,
                          autofocus: TvSupport.isTv,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
