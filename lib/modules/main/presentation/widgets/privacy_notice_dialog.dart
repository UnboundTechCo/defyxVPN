import 'dart:io';

import 'package:defyx_vpn/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PrivacyNoticeDialog extends StatefulWidget {
  final Future<bool> Function() onAccept;

  const PrivacyNoticeDialog({
    super.key,
    required this.onAccept,
  });

  @override
  State<PrivacyNoticeDialog> createState() => _PrivacyNoticeDialogState();

  static Future<void> show(
    BuildContext context,
    Future<bool> Function() onAccept,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: PrivacyNoticeDialog(onAccept: onAccept),
        );
      },
    );
  }
}

class _PrivacyNoticeDialogState extends State<PrivacyNoticeDialog> {
  bool _isLoading = false;
  @override
  Widget build(BuildContext context) {
    final screenWidth = 1.sw;
    const double baseScreenWidth = 375.0;
    final ratio = screenWidth / baseScreenWidth;
    final fontSize = (16.0 * ratio).clamp(14.0, 18.0).toDouble();
    String message =
        'This app does not collect, store, or transmit any personal information to its servers.\n\n'
        'Only a small amount of non-personal data (such as your internet provider’s name) may be stored locally on your device to improve connection performance for future sessions.\n';
    if (Platform.isIOS) {
      message += '\nBy continuing,\nyou agree to install the VPN profile.';
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.r),
      ),
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
              'Privacy Notice',
              style: TextStyle(
                fontFamily: 'Lato',
                fontSize: fontSize * 1.4,
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              message,
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
                if (_isLoading) return;
                setState(() => _isLoading = true);

                final accepted = await widget.onAccept();
                setState(() => _isLoading = false);
                if (accepted && context.mounted) {
                  Navigator.of(context).pop();
                }
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
              child: _isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: const CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.bottomGradientConnected,
                      ),
                    )
                  : Text(
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
