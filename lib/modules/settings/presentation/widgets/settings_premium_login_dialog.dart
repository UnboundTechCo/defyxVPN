import 'package:defyx_vpn/common/components/text_field.dart';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/utils/toast_util.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:flutter/material.dart';
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

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _submitLoginData() async {
    try {
      if (!(_formKey.currentState?.validate() ?? false)) {
        return;
      }

      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final vpnBridge = VpnBridge();

      final token = await vpnBridge.login(email, password);

      if (token.isEmpty) {
        ToastUtil.showToast(
          'Login failed. Please check your credentials and try again.',
        );
        return;
      }

      await widget.ref.read(authProvider.notifier).login(token);

      ToastUtil.showToast('Login successful!');

      if (mounted) {
        final container = ProviderContainer();
        FlowlineService(
          container.read(secureStorageProvider),
          container,
        ).saveFlowline(offlineMode: false);

        Navigator.of(context).pop();
      }
    } catch (e, stack) {
      debugPrint(e.toString());
      debugPrint(stack.toString());
    }
  }

  void _handleNotNow() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Authentication Required',
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: fontSize * 1.4,
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                "To access premium features, please log in with your account credentials.",
                style: TextStyle(
                  fontSize: fontSize,
                  fontFamily: 'Lato',
                  color: Colors.black.withValues(alpha: 0.5),
                  height: 1.4,
                ),
              ),
              SizedBox(height: 20.h),
              AppTextField(
                controller: _emailController,
                label: 'Email',
                hintText: 'example@domain.com',
                prefixIcon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20.h),
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                hintText: "P@w0r|)",
                prefixIcon: Icons.lock,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10.h),
              ElevatedButton(
                onPressed: _submitLoginData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF21AD86),
                  foregroundColor: const Color.fromARGB(255, 47, 41, 41),
                  padding: EdgeInsets.symmetric(vertical: 11.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Login',
                  style: TextStyle(
                    fontFamily: 'Lato',
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              ElevatedButton(
                onPressed: _handleNotNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: const Color.fromARGB(255, 47, 41, 41),
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Not now',
                  style: TextStyle(
                    fontFamily: 'Lato',
                    color: const Color(0xFF4B4B4B),
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
