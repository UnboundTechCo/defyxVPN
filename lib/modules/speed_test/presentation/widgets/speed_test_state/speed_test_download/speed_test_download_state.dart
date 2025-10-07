import 'package:defyx_vpn/modules/speed_test/application/speed_test_provider.dart';
import 'package:defyx_vpn/modules/speed_test/presentation/widgets/speed_test_progress/speed_test_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SpeedTestDownloadState extends StatelessWidget {
  final SpeedTestState state;

  const SpeedTestDownloadState({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final speedProgress = (state.currentSpeed / 100).clamp(0.0, 1.0);
    final combinedProgress = (state.progress * 0.5) + (speedProgress * 0.5);

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: 30.h),
        SpeedTestProgressIndicator(
          progress: combinedProgress,
          color: Colors.green,
          showButton: false,
          centerValue: state.currentSpeed > 0 ? state.currentSpeed : state.result.downloadSpeed,
          centerUnit: 'Mbps',
          subtitle: 'DOWNLOAD',
          result: state.result,
        ),
      ],
    );
  }
}
