import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/speed_test_result.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';

class SpeedTestHeader extends StatelessWidget {
  final SpeedTestStep step;

  const SpeedTestHeader({
    super.key,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String upperText;
    String bottomText;

    switch (step) {
      case SpeedTestStep.loading:
      case SpeedTestStep.download:
      case SpeedTestStep.upload:
        upperText = l10n.statusIs;
        bottomText = l10n.statusTestingSpeed;
        break;
      case SpeedTestStep.ready:
        upperText = l10n.statusIsReady;
        bottomText = l10n.statusToSpeedTest;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'D',
                      style: TextStyle(
                        fontSize: 35.sp,
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFFC927),
                      ),
                    ),
                    TextSpan(
                      text: 'efyx',
                      style: TextStyle(
                        fontSize: 32.sp,
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFFFFC927),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 6.w),
            Flexible(
              child: Text(
                upperText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: AppTheme.statusHeadlineFontSize.sp,
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        Text(
          bottomText,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
          style: TextStyle(
            fontSize: AppTheme.statusHeadlineFontSize.sp,
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
