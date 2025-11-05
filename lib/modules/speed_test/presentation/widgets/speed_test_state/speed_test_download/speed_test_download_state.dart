import 'package:defyx_vpn/core/theme/app_colors.dart';
import 'package:defyx_vpn/modules/speed_test/application/speed_test_provider.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_progress/speed_test_progress_indicator.dart';
import 'package:defyx_vpn/modules/speed_test/models/speed_test_result.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SpeedTestDownloadState extends ConsumerWidget {
  final SpeedTestState state;
  final VoidCallback onStop;

  const SpeedTestDownloadState({
    super.key,
    required this.state,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speedProgress = (state.currentSpeed / 100).clamp(0.0, 1.0);
    final combinedProgress = (state.progress * 0.5) + (speedProgress * 0.5);
    final connectionState = ref.watch(connectionStateProvider);

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: 30.h),
        InkWell(
          onTap: onStop,
          child: SpeedTestProgressIndicator(
            progress: combinedProgress,
            color: AppColors.downloadColor,
            showButton: false,
            centerValue: state.currentSpeed > 0 ? state.currentSpeed : state.result.downloadSpeed,
            centerUnit: 'Mbps',
            subtitle: 'DOWNLOAD',
            result: state.result,
            currentStep: SpeedTestStep.download,
            connectionStatus: connectionState.status,
          ),
        ),
      ],
    );
  }
}
