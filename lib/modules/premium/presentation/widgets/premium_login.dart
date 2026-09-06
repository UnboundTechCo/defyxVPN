import 'package:defyx_vpn/common/components/button.dart';
import 'package:defyx_vpn/common/components/text_field.dart';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/core/utils/toast_util.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/custom_webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PremiumLogin extends StatefulWidget {
  final WidgetRef ref;
  final VoidCallback navigateToLoginByCode;

  const PremiumLogin({
    super.key,
    required this.ref,
    required this.navigateToLoginByCode,
  });

  @override
  State<PremiumLogin> createState() => _PremiumLoginState();
}

class _PremiumLoginState extends State<PremiumLogin> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLoginData() async {
    final l10n = AppLocalizations.of(context);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      setState(() => isSubmitting = true);

      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final token = await VpnBridge().login(email, password);

      if (token.isEmpty) {
        ToastUtil.showToast(l10n.loginFailed);
        return;
      }

      await widget.ref.read(authProvider.notifier).login(email, token);

      await widget.ref
          .read(flowlineServiceProvider)
          .saveFlowline(offlineMode: false, forceUpdate: true);

      ToastUtil.showToast(l10n.loginSuccess);

      if (mounted) Navigator.of(context).pop();
    } catch (e, stack) {
      debugPrint('$e\n$stack');
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  void _openSignUpPage() {
    final l10n = AppLocalizations.of(context);
    final url = dotenv.env["WEBSITE_SIGN_UP"];

    if (url == null || url.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomWebViewScreen(url: url, title: l10n.signUp),
      ),
    );
  }

  void _openLoginByCodeDialog() {
    widget.navigateToLoginByCode();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fontSize = (16.0 * (1.sw / 375.0)).clamp(14.0, 18.0).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 20.h),
                Text(
                  l10n.premiumLoginDescription,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontFamily: AppTheme.fontFamily,
                    color: Colors.black.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 20.h),
                AppTextField(
                  controller: _emailController,
                  label: l10n.email.toUpperCase(),
                  hintText: l10n.emailHint,
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value == null || value.isEmpty
                      ? l10n.emailValidation
                      : null,
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
                    if (value.length < 6) return l10n.passwordMinLength;
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
                  size: AppButtonSize.medium,
                  variant: AppButtonVariant.tertiary,
                  isLoading: isSubmitting,
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Text(
                      '${l10n.noAccount} '.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontFamily: AppTheme.fontFamily,
                        color: Colors.black.withValues(alpha: 0.5),
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
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
