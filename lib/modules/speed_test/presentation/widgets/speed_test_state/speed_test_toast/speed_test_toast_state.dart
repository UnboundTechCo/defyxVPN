import 'package:defyx_vpn/core/theme/app_colors.dart';
import 'package:defyx_vpn/modules/speed_test/application/speed_test_provider.dart';
import 'package:defyx_vpn/modules/speed_test/models/speed_test_result.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_progress/speed_test_progress_indicator.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_start_button.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
    final connectionState = ref.watch(connectionStateProvider);

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: 30.h),
        SpeedTestProgressIndicator(
          progress: 1.0,
          color: AppColors.warningColor,
          showButton: true,
          result: state.result,
          connectionStatus: connectionState.status,
          currentStep: SpeedTestStep.toast,
          button: SpeedTestStartButton(
            currentStep: SpeedTestStep.toast,
            isEnabled: true,
            onTap: onRetry,
          ),
        ),
      ],
    );
  }
}
