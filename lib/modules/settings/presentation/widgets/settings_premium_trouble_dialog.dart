import 'package:defyx_vpn/common/components/button.dart';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:defyx_vpn/core/utils/toast_util.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SettingsPremiumTroubleDialog extends StatefulWidget {
  final WidgetRef ref;
  final String email;

  const SettingsPremiumTroubleDialog({
    super.key,
    required this.ref,
    required this.email,
  });

  @override
  State<SettingsPremiumTroubleDialog> createState() =>
      _SettingsPremiumTroubleDialogState();

  static Future<void> show(BuildContext context, WidgetRef ref, String email) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return PopScope(
          canPop: true,
          child: SettingsPremiumTroubleDialog(ref: ref, email: email),
        );
      },
    );
  }
}

class _SettingsPremiumTroubleDialogState
    extends State<SettingsPremiumTroubleDialog> {
  bool isSigningOut = false;
  Future<void> _handleSignOut() async {
    final l10n = AppLocalizations.of(context);
    if (isSigningOut) return;
    setState(() => isSigningOut = true);
    await widget.ref.read(authProvider.notifier).logout();
    await widget.ref
        .read(flowlineServiceProvider)
        .saveFlowline(offlineMode: false, forceUpdate: true);

    if (!mounted) return;

    setState(() => isSigningOut = false);
    Navigator.of(context).pop();
    ToastUtil.showToast(l10n.signOutSuccess);
  }

  void _closeDialog() {
    if (isSigningOut) return;
    Navigator.of(context).pop();
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
              l10n.havingTrouble,
              style: TextStyle(
                fontFamily: 'Lato',
                fontSize: fontSize * 1.4,
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.email.isNotEmpty) ...[
              SizedBox(height: 18.h),

              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: fontSize,
                    fontFamily: 'Lato',
                    color: Colors.black.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(text: '${l10n.signedInAs} '),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(color: Color(0xFF5374BD)),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ],
            SizedBox(height: 18.h),
            Text(
              l10n.premiumImportDescription,
              style: TextStyle(
                fontSize: fontSize,
                fontFamily: 'Lato',
                color: Colors.black.withValues(alpha: 0.5),
                height: 1.4,
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Text(
                  l10n.planningToExit.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontFamily: 'Lato',
                    height: 1.4,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
                SizedBox(width: 2.w),
                InkWell(
                  onTap: _handleSignOut,
                  child: Text(
                    l10n.signOut.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 12.sp,
                      height: 1.4,
                      color: const Color(0xFF17A079),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            AppButton(
              label: l10n.gotIt,
              onPressed: _closeDialog,
              size: AppButtonSize.medium,
              variant: AppButtonVariant.secondary,
              isLoading: isSigningOut,
            ),
          ],
        ),
      ),
    );
  }
}
