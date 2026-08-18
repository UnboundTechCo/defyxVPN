import 'package:defyx_vpn/common/components/button.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_premium_login_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SettingsPremiumInfoDialog extends StatefulWidget {
  final WidgetRef ref;

  const SettingsPremiumInfoDialog({super.key, required this.ref});

  @override
  State<SettingsPremiumInfoDialog> createState() =>
      _SettingsPremiumInfoDialogState();

  static Future<void> show(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return PopScope(
          canPop: true,
          child: SettingsPremiumInfoDialog(ref: ref),
        );
      },
    );
  }
}

class _SettingsPremiumInfoDialogState extends State<SettingsPremiumInfoDialog> {
  void _handleGotIt() async {
    Navigator.of(context).pop();
    SettingsPremiumLoginDialog.show(context, widget.ref);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              l10n.connectionRequired,
              style: TextStyle(
                fontFamily: 'Lato',
                fontSize: fontSize * 1.4,
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              l10n.connectionRequiredDescription,
              style: TextStyle(
                fontSize: fontSize,
                fontFamily: 'Lato',
                color: Colors.black.withValues(alpha: 0.5),
                height: 1.4,
              ),
            ),
            SizedBox(height: 20.h),
            AppButton(
              label: l10n.gotIt,
              onPressed: _handleGotIt,
              size: AppButtonSize.small,
              variant: AppButtonVariant.secondary,
              // isLoading: isSubmitting,
            ),
          ],
        ),
      ),
    );
  }
}
