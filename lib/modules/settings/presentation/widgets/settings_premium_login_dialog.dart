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

  static Future<void> show(BuildContext context,  WidgetRef ref) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return PopScope(
          canPop: true,
          child: SettingsPremiumLoginDialog( ref: ref),
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

      if(token.isEmpty){
        ToastUtil.showToast('Login failed. Please check your credentials and try again.');
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
                "To access your Premium subscription(s), you need to login or create an account through the Defyx website or Telegram bot.",
                style: TextStyle(
                  fontSize: fontSize,
                  fontFamily: 'Lato',
                  color: Colors.black.withValues(alpha: 0.5),
                  height: 1.4,
                ),
              ),
              SizedBox(height: 20.h),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20.h),
              TextFormField(
                controller: _passwordController,
                obscureText: true, // Hides the typing for passwords
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  prefixIcon: Icon(Icons.lock),
                ),
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
                  backgroundColor: Colors.grey[200],
                  foregroundColor: const Color.fromARGB(255, 47, 41, 41),
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Login',
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
      ),
    );
  }
}
