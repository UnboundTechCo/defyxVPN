import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SettingsPremiumTroubleDialog extends StatefulWidget {

  const SettingsPremiumTroubleDialog({super.key});

  @override
  State<SettingsPremiumTroubleDialog> createState() =>
      _SettingsPremiumTroubleDialogState();

  static Future<void> show(
    BuildContext context,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return PopScope(
          canPop: true,
          child: const SettingsPremiumTroubleDialog(),
        );
      },
    );
  }
}

class _SettingsPremiumTroubleDialogState extends State<SettingsPremiumTroubleDialog> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = 1.sw;
    const double baseScreenWidth = 375.0;
    final ratio = screenWidth / baseScreenWidth;
    final fontSize = (16.0 * ratio).clamp(14.0, 18.0).toDouble();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Container(
        padding: EdgeInsets.all(20.w),
        width: 343.w,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Having trouble?',
              style: TextStyle(
                fontFamily: 'Lato',
                fontSize: fontSize * 1.4,
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              "If your Premium subscriptions cannot be loaded due to internet restrictions and you're unable to connect using the available methods, you can import the file obtained from the Marketplace into the app.",
              style: TextStyle(
                fontSize: fontSize,
                fontFamily: 'Lato',
                color: Colors.black.withValues(alpha: 0.5),
                height: 1.4,
              ),
            ),
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: const Color.fromARGB(255, 47, 41, 41),
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                elevation: 0,
              ),
              child: Text(
                'Got it',
                style: TextStyle(
                  fontFamily: 'Lato',
                  color: const Color(0xFF4B4B4B),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
