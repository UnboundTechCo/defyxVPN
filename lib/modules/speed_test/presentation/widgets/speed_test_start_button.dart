import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/speed_test_result.dart';

class SpeedTestStartButton extends StatelessWidget {
  final SpeedTestStep currentStep;
  final SpeedTestStep? previousStep;
  final bool isEnabled;
  final VoidCallback onTap;

  const SpeedTestStartButton({
    super.key,
    required this.currentStep,
    required this.isEnabled,
    required this.onTap,
    this.previousStep,
  });

  IconData _getIcon() {
    if (currentStep == SpeedTestStep.ready) {
      return Icons.play_arrow_rounded;
    } else if (currentStep == SpeedTestStep.toast) {
      return Icons.refresh_rounded;
    } else if (currentStep == SpeedTestStep.ads &&
        previousStep == SpeedTestStep.toast) {
      return Icons.refresh_rounded;
    } else {
      return Icons.check_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        width: 60.w,
        height: 60.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isEnabled ? Colors.white : Colors.grey.shade700,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10.r,
              offset: Offset(0, 5.h),
            ),
          ],
        ),
        child: Icon(
          _getIcon(),
          color: isEnabled ? const Color(0xFF0D1B1A) : Colors.grey.shade500,
          size: 36.sp,
        ),
      ),
    );
  }
}
