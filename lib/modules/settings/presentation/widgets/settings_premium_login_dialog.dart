import 'package:defyx_vpn/common/components/button.dart';
import 'package:defyx_vpn/common/components/dialog.dart';
import 'package:defyx_vpn/common/components/text_field.dart';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/core/utils/toast_util.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_premium_login_by_code_dialog.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/custom_webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SettingsPremiumLoginDialog extends StatefulWidget {
  final WidgetRef ref;

  const SettingsPremiumLoginDialog({super.key, required this.ref});

  @override
  State<SettingsPremiumLoginDialog> createState() =>
      _SettingsPremiumLoginDialogState();

  static Future<void> show(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return PopScope(
          canPop: true,
          child: SettingsPremiumLoginDialog(ref: ref),
        );
      },
    );
  }
}

class _SettingsPremiumLoginDialogState
    extends State<SettingsPremiumLoginDialog> {
  final _formKey = GlobalKey<FormState>();

  bool isSubmitting = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _submitLoginData() async {
    final l10n = AppLocalizations.of(context);
    try {
      setState(() => isSubmitting = true);
      if (!(_formKey.currentState?.validate() ?? false)) {
        setState(() => isSubmitting = false);
        return;
      }

      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final vpnBridge = VpnBridge();

      final token = await vpnBridge.login(email, password);

      if (token.isEmpty) {
        ToastUtil.showToast(l10n.loginFailed);
        return;
      }

      await widget.ref.read(authProvider.notifier).login(email, token);

      await widget.ref
          .read(flowlineServiceProvider)
          .saveFlowline(offlineMode: false, forceUpdate: true);

      ToastUtil.showToast(l10n.loginSuccess);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e, stack) {
      debugPrint(e.toString());
      debugPrint(stack.toString());
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  void _openSignUpPage() {
    final l10n = AppLocalizations.of(context);
    final url = dotenv.env["WEBSITE_SIGN_UP"];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            CustomWebViewScreen(url: url!, title: l10n.signUp),
      ),
    );
  }

  void _openLoginByCodeDialog() {
    Navigator.of(context).pop();
    SettingsPremiumLoginByCodeDialog.show(context, widget.ref);
  }

  void _handleNotNow() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenWidth = 1.sw;
    const double baseScreenWidth = 375.0;
    final ratio = screenWidth / baseScreenWidth;
    final fontSize = (16.0 * ratio).clamp(14.0, 18.0).toDouble();

    return AppDialog(
      child: Form(
        key: _formKey,
        child: Column(
          // mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.authenticationRequired,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: fontSize * 1.4,
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 20.h),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.premiumLoginDescription,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontFamily: AppTheme.fontFamily,
                          color: Colors.black.withValues(alpha: 0.5),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20.h),
            AppTextField(
              controller: _emailController,
              label: l10n.email.toUpperCase(),
              hintText: l10n.emailHint,
              prefixIcon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.emailValidation;
                }
                return null;
              },
            ),
            SizedBox(height: 16.h),
            AppTextField(
              controller: _passwordController,
              label: l10n.password.toUpperCase(),
              hintText: l10n.passwordHint,
              prefixIcon: Icons.lock,
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.passwordValidation;
                }
                if (value.length < 6) {
                  return l10n.passwordMinLength;
                }
                return null;
              },
            ),
            SizedBox(height: 16.h),
            AppButton(
              label: l10n.login,
              onPressed: _submitLoginData,
              size: AppButtonSize.medium,
              variant: AppButtonVariant.primary,
              isLoading: isSubmitting,
            ),
            SizedBox(height: 10.h),
            AppButton(
              label: l10n.loginByCode,
              onPressed: _openLoginByCodeDialog,
              size: AppButtonSize.small,
              variant: AppButtonVariant.tertiary,
              isLoading: isSubmitting,
            ),
            SizedBox(height: 10.h),
            AppButton(
              label: l10n.notNow,
              onPressed: _handleNotNow,
              size: AppButtonSize.small,
              variant: AppButtonVariant.secondary,
              isLoading: isSubmitting,
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Text(
                  "${l10n.noAccount} ".toUpperCase(),
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontFamily: AppTheme.fontFamily,
                    color: Colors.black.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
                GestureDetector(
                  onTap: _openSignUpPage,
                  child: Text(
                    l10n.signUp.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontFamily: AppTheme.fontFamily,
                      color: Colors.blue,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
