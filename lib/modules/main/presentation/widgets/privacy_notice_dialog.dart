import 'dart:io';

import 'package:defyx_vpn/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PrivacyNoticeDialog extends StatefulWidget {
  final Future<bool> Function(bool telemetryOptIn) onAccept;
  final bool telemetryOnly;

  const PrivacyNoticeDialog({
    super.key,
    required this.onAccept,
    this.telemetryOnly = false,
  });

  @override
  State<PrivacyNoticeDialog> createState() => _PrivacyNoticeDialogState();

  static Future<void> show(
    BuildContext context,
    Future<bool> Function(bool telemetryOptIn) onAccept, {
    bool telemetryOnly = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: PrivacyNoticeDialog(
            onAccept: onAccept,
            telemetryOnly: telemetryOnly,
          ),
        );
      },
    );
  }
}

class _PrivacyNoticeDialogState extends State<PrivacyNoticeDialog> {
  bool _isLoading = false;
  bool _telemetryOptIn = false;

  Future<void> _handleGotIt() async {
    try {
      if (_isLoading) return;
      setState(() => _isLoading = true);

      final accepted = await widget.onAccept(_telemetryOptIn);
      setState(() => _isLoading = false);
      if (accepted && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error in _handleGotIt: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = 1.sw;
    const double baseScreenWidth = 375.0;
    final ratio = screenWidth / baseScreenWidth;
    final fontSize = (16.0 * ratio).clamp(14.0, 18.0).toDouble();

    String message = widget.telemetryOnly
        ? 'You previously accepted the VPN setup notice. Please choose separately whether Defyx may send diagnostic and usage telemetry.'
        : 'Defyx needs your permission to install and use the VPN profile. VPN operation may process account, IP address, server, and connection information.';

    if (Platform.isIOS || Platform.isAndroid) {
      message +=
          '\nAdMob and its consent form are handled separately after this notice.';
    }

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
            SizedBox(height: 12.h),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _telemetryOptIn,
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() => _telemetryOptIn = value ?? false);
                    },
              title: Text(
                'Allow telemetry',
                style: TextStyle(
                  fontSize: fontSize,
                  fontFamily: 'Lato',
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Optional: Firebase Analytics, Crashlytics, Sessions, VPN diagnostics, and Cloudflare speed-test measurements. You can revoke this choice later in Settings.',
                style: TextStyle(
                  fontSize: fontSize * 0.82,
                  fontFamily: 'Lato',
                  color: Colors.black.withValues(alpha: 0.5),
                  height: 1.3,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: _handleGotIt,
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
