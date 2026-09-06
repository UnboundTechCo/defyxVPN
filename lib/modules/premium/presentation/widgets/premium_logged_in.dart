import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/core/utils/toast_util.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PremiumLoggedIn extends StatefulWidget {
  final WidgetRef ref;
  final String email;

  const PremiumLoggedIn({super.key, required this.ref, required this.email});

  static Future<void> show(BuildContext context, WidgetRef ref, String email) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PremiumLoggedIn(ref: ref, email: email),
      ),
    );
  }

  @override
  State<PremiumLoggedIn> createState() => _PremiumLoggedInState();
}

class _PremiumLoggedInState extends State<PremiumLoggedIn> {
  bool isSigningOut = false;

  Future<void> _handleSignOut() async {
    final l10n = AppLocalizations.of(context);

    if (isSigningOut) return;

    try {
      setState(() => isSigningOut = true);

      await widget.ref.read(authProvider.notifier).logout();

      await widget.ref
          .read(flowlineServiceProvider)
          .saveFlowline(offlineMode: false, forceUpdate: true);

      if (!mounted) return;

      ToastUtil.showToast(l10n.signOutSuccess);
    } finally {
      if (mounted) {
        setState(() => isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.email.isNotEmpty) ...[
                SizedBox(height: 18.h),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontFamily: AppTheme.fontFamily,
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
                SizedBox(height: 18.h),
              ],
              Text(
                l10n.premiumImportDescription,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontFamily: AppTheme.fontFamily,
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
                      fontFamily: AppTheme.fontFamily,
                      height: 1.4,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  InkWell(
                    onTap: isSigningOut ? null : _handleSignOut,
                    child: Text(
                      l10n.signOut.toUpperCase(),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.sp,
                        height: 1.4,
                        color: const Color(0xFFFF4C4C),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
