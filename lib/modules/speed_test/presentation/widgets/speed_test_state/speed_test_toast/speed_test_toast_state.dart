import 'package:defyx_vpn/modules/speed_test/application/speed_test_provider.dart';
import 'package:defyx_vpn/modules/speed_test/models/speed_test_result.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_progress/speed_test_progress_indicator.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_start_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'speed_test_toast_message.dart';

class SpeedTestToastState extends ConsumerWidget {
  final SpeedTestState state;
  final VoidCallback onRetry;

  const SpeedTestToastState({
    super.key,
    required this.state,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: 30.h),
        SpeedTestProgressIndicator(
          progress: 1.0,
          color: Colors.orange,
          showButton: true,
          result: state.result,
          button: SpeedTestStartButton(
            currentStep: SpeedTestStep.toast,
            isEnabled: true,
            onTap: onRetry,
          ),
        ),
        SizedBox(height: 55.h),
        SizedBox(
          child: SpeedTestToastMessage(
            message:
                state.errorMessage ?? 'Your connection was unstable, and the test was interrupted.',
          ),
        ),
      ],
    );
  }
}
