import 'package:defyx_vpn/common/components/button.dart';
import 'package:defyx_vpn/common/components/text_field.dart';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/core/utils/toast_util.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PremiumLoginByCode extends ConsumerStatefulWidget {
  final VoidCallback navigateToLogin;

  const PremiumLoginByCode({super.key, required this.navigateToLogin});

  @override
  ConsumerState<PremiumLoginByCode> createState() => _PremiumLoginByCodeState();
}

class _PremiumLoginByCodeState extends ConsumerState<PremiumLoginByCode> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitLoginByCodeData() async {
    final l10n = AppLocalizations.of(context);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => isSubmitting = true);

    try {
      final code = _codeController.text.trim();
      final token = await VpnBridge().loginByCode(code);

      if (token.isEmpty) {
        ToastUtil.showToast(l10n.loginFailed);
        return;
      }

      await ref.read(authProvider.notifier).loginByCode(token);

      await ref
          .read(flowlineServiceProvider)
          .saveFlowline(offlineMode: false, forceUpdate: true);

      ToastUtil.showToast(l10n.loginSuccess);

      if (mounted) Navigator.of(context).pop();
    } catch (e, stackTrace) {
      debugPrint('Login by code failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      ToastUtil.showToast(l10n.loginFailed);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fontSize = (16.0 * (1.sw / 375.0)).clamp(14.0, 18.0).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.premiumLoginByCodeDescription,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontFamily: AppTheme.fontFamily,
                    color: Colors.black.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 24.h),
                AppTextField(
                  controller: _codeController,
                  label: l10n.code.toUpperCase(),
                  hintText: l10n.codeHint,
                  prefixIcon: Icons.vpn_key,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l10n.codeValidation
                      : null,
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 20.h),
                AppButton(
                  label: l10n.login,
                  onPressed: _submitLoginByCodeData,
                  size: AppButtonSize.medium,
                  variant: AppButtonVariant.primary,
                  isLoading: isSubmitting,
                ),
                SizedBox(height: 10.h),
                AppButton(
                  label: l10n.backToLoginByEmail,
                  onPressed: widget.navigateToLogin,
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.secondary,
                  isLoading: isSubmitting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
