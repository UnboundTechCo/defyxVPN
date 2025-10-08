import 'package:defyx_vpn/modules/speed_test/application/speed_test_provider.dart';
import 'package:defyx_vpn/modules/speed_test/models/speed_test_result.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_progress/speed_test_progress_indicator.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_start_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SpeedTestReadyState extends ConsumerWidget {
  final Animation<double> scaleAnimation;

  const SpeedTestReadyState({
    super.key,
    required this.scaleAnimation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(speedTestProvider);

    return ScaleTransition(
      scale: scaleAnimation,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(height: 30.h),
          SpeedTestProgressIndicator(
            progress: 0.0,
            color: Colors.green,
            showButton: true,
            result: state.result,
            button: Column(
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
                  onTap: () {
                    ref.read(speedTestProvider.notifier).startTest();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
