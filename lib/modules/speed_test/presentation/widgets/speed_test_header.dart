import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/speed_test_result.dart';

class SpeedTestHeader extends StatelessWidget {
  final SpeedTestStep step;

  const SpeedTestHeader({
    super.key,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    String upperText;
    String bottomText;

    switch (step) {
      case SpeedTestStep.loading:
      case SpeedTestStep.download:
      case SpeedTestStep.upload:
        upperText = 'is';
        bottomText = 'testing speed ...';
        break;
      case SpeedTestStep.ready:
        upperText = 'is ready';
        bottomText = 'to speed test';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              'D',
              style: TextStyle(
                fontSize: 35.sp,
                fontFamily: 'Lato',
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFFC927),
              ),
            ),
            Text(
              'efyx ',
              style: TextStyle(
                fontSize: 32.sp,
                fontFamily: 'Lato',
                fontWeight: FontWeight.w400,
                color: const Color(0xFFFFC927),
              ),
            ),
            Text(
              upperText,
              style: TextStyle(
                fontSize: 32.sp,
                fontFamily: 'Lato',
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Text(
          bottomText,
          style: TextStyle(
            fontSize: 32.sp,
            fontFamily: 'Lato',
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
