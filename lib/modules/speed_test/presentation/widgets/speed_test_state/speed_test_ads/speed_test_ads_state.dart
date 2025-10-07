import 'package:defyx_vpn/modules/main/presentation/widgets/google_ads.dart';
import 'package:defyx_vpn/modules/speed_test/application/speed_test_provider.dart';
import 'package:defyx_vpn/modules/speed_test/models/speed_test_result.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_progress/speed_test_progress_indicator.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_start_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'speed_test_ads_overlay.dart';

class SpeedTestAdsState extends ConsumerWidget {
  final SpeedTestState state;
  final SpeedTestStep? previousStep;
  final int countdown;
  final VoidCallback onClose;
  final GoogleAds googleAds;

  const SpeedTestAdsState({
    super.key,
    required this.state,
    required this.countdown,
    required this.onClose,
    required this.googleAds,
    this.previousStep,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: 30.h),
            SpeedTestProgressIndicator(
              progress: 1.0,
              color: previousStep == SpeedTestStep.toast ? Colors.orange : Colors.green,
              showButton: true,
              result: state.result,
              button: SpeedTestStartButton(
                currentStep: SpeedTestStep.ads,
                previousStep: previousStep,
                isEnabled: false,
                onTap: () {},
              ),
            ),
          ],
        ),
        SpeedTestAdsOverlay(
          countdown: countdown,
          googleAds: googleAds,
          onClose: onClose,
        ),
      ],
    );
  }
}
