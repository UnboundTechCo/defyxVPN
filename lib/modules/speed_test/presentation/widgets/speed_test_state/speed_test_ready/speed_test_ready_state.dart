import 'package:defyx_vpn/modules/speed_test/application/speed_test_provider.dart';
import 'package:defyx_vpn/modules/speed_test/models/speed_test_result.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_progress/speed_test_progress_indicator.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_start_button.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SpeedTestReadyState extends ConsumerWidget {
  final VoidCallback onRetry;

  const SpeedTestReadyState({
    super.key,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(speedTestProvider);
    final connectionState = ref.watch(connectionStateProvider);

    void handleStartTest() {
      final status = connectionState.status;

      if (status == ConnectionStatus.disconnected || status == ConnectionStatus.connected) {
        ref.read(speedTestProvider.notifier).startTest();
      } else {
        debugPrint(
            'Button clicked but connection status is $status. Will start when connection is valid.');
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: 30.h),
        SpeedTestProgressIndicator(
          progress: 0.0,
          color: Colors.green,
          showButton: true,
          result: state.result,
          connectionStatus: connectionState.status,
          button: state.testCompleted
              ? SpeedTestStartButton(
                  currentStep: SpeedTestStep.ready,
                  isEnabled: true,
                  onTap: onRetry,
                  previousStep: SpeedTestStep.download,
                )
              : InkWell(
                  onTap: handleStartTest,
                  child: Column(
                    spacing: 8.h,
                    children: [
                      Text(
                        "TAP HERE",
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
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
