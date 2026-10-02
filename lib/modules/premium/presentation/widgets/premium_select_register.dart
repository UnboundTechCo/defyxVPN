import 'dart:io';

import 'package:defyx_vpn/common/components/button.dart';
import 'package:defyx_vpn/common/components/dialog.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/modules/core/register.dart';
import 'package:defyx_vpn/modules/premium/providers/premium_tab_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PremiumSelectRegister extends StatefulWidget {
  final WidgetRef ref;
  const PremiumSelectRegister({super.key, required this.ref});

  @override
  State<PremiumSelectRegister> createState() => _PremiumSelectRegisterState();
}

class _PremiumSelectRegisterState extends State<PremiumSelectRegister> {
  void _goToLoginPage() {
    widget.ref.read(premiumTabProvider.notifier).state = PremiumTab.account;
    Navigator.of(context).pop();
  }

  Future<void> _register() async {
    final register = Register(ref: widget.ref);
    await register.registerByApple();
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "You need to register to access premium features.",
            style: TextStyle(
              fontSize: 16.sp,
              fontFamily: AppTheme.fontFamily,
              color: Colors.black.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
          SizedBox(height: 24.h),
          if (Platform.isIOS) ...[
            AppButton(
              label: "Continue with Apple",
              onPressed: _register,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.medium,
              round: AppButtonRound.medium,
            ),
            SizedBox(height: 12.h),
          ],
          AppButton(
            label: "Go to login section",
            onPressed: _goToLoginPage,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.medium,
            round: AppButtonRound.medium,
          ),
        ],
      ),
    );
  }
}
