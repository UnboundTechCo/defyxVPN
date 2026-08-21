import 'package:defyx_vpn/common/components/button.dart';
import 'package:defyx_vpn/common/components/dialog.dart';
import 'package:defyx_vpn/common/components/text_field.dart';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:defyx_vpn/core/utils/toast_util.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_premium_login_dialog.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SettingsPremiumLoginByCodeDialog extends StatefulWidget {
  final WidgetRef ref;

  const SettingsPremiumLoginByCodeDialog({super.key, required this.ref});

  @override
  State<SettingsPremiumLoginByCodeDialog> createState() =>
      _SettingsPremiumLoginByCodeDialogState();

  static Future<void> show(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return PopScope(
          canPop: true,
          child: SettingsPremiumLoginByCodeDialog(ref: ref),
        );
      },
    );
  }
}

class _SettingsPremiumLoginByCodeDialogState
    extends State<SettingsPremiumLoginByCodeDialog> {
  final _formKey = GlobalKey<FormState>();

  bool isSubmitting = false;

  final TextEditingController _codeController = TextEditingController();

  Future<void> _submitLoginByCodeData() async {
    final l10n = AppLocalizations.of(context);
    try {
      setState(() => isSubmitting = true);
      if (!(_formKey.currentState?.validate() ?? false)) {
        setState(() => isSubmitting = false);
        return;
      }

      final code = _codeController.text.trim();

      final vpnBridge = VpnBridge();

      final token = await vpnBridge.loginByCode(code);

      if (token.isEmpty) {
        ToastUtil.showToast(l10n.loginFailed);
        return;
      }

      await widget.ref.read(authProvider.notifier).loginByCode(token);

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

  void _handleOpenLogin() {
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
                fontFamily: 'Lato',
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
                        l10n.premiumLoginByCodeDescription,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontFamily: 'Lato',
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
              controller: _codeController,
              label: l10n.code.toUpperCase(),
              hintText: l10n.codeHint,
              prefixIcon: Icons.vpn_key,
              keyboardType: TextInputType.text,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.codeValidation;
                }
                return null;
              },
            ),

            SizedBox(height: 16.h),
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
              onPressed: _handleOpenLogin,
              size: AppButtonSize.small,
              variant: AppButtonVariant.secondary,
              isLoading: isSubmitting,
            ),
            SizedBox(height: 10.h),
          ],
        ),
      ),
    );
  }
}
