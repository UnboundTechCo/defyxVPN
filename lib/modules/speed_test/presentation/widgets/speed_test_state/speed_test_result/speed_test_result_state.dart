import 'package:defyx_vpn/modules/speed_test/application/speed_test_provider.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_progress/speed_test_progress_indicator.dart';
import 'package:defyx_vpn/modules/speed_test/models/speed_test_result.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SpeedTestResultState extends ConsumerWidget {
  final SpeedTestState state;

  const SpeedTestResultState({
    super.key,
    required this.state,
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
          color: null,
          showButton: false,
          centerValue: state.result.downloadSpeed,
          centerUnit: 'Mbps',
          subtitle: 'RESULT',
          result: state.result,
          currentStep: SpeedTestStep.result,
          connectionStatus: connectionState.status,
        ),
      ],
    );
  }
}
