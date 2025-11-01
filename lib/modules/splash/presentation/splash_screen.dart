import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/modules/core/vpn.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:defyx_vpn/core/data/local/vpn_data/vpn_data.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToMain();
  }

  void _navigateToMain() async {
    final vpnData = await ref.read(vpnDataProvider.future);
    final vpnBridge = VpnBridge();
    if (vpnData.isVPNEnabled && mounted) {
      context.go('/main');
      return;
    }

    final vpnIsPrepared = await vpnBridge.isVPNPrepared();

    if (ref.context.mounted && vpnIsPrepared) {
      final vpn = VPN(ProviderScope.containerOf(ref.context));
      await vpn.initVPN();
      if (mounted) {
        context.go('/main');
        return;
      }
    }

    if (!vpnIsPrepared) {
      await Future.delayed(const Duration(seconds: 3));
    }
    if (mounted) context.go('/main');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              children: [
                const Spacer(flex: 8),
                _buildLogo(),
                20.h.verticalSpace,
                _buildTitle(),
                const Spacer(flex: 9),
                _buildSubtitle(),
                60.h.verticalSpace,
                _buildLoadingIndicator(),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackground({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF18181E), Color(0xFF1C443B), Color(0xFF1F5F4D)],
          stops: [0.2, 0.7, 1.0],
        ),
      ),
      child: child,
    );
  }

  Widget _buildLogo() {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 235.w),
      child: AppIcons.logo(width: 150.w, height: 150.w),
    );
  }

  Widget _buildTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _titlePart('D', FontWeight.w700),
        _titlePart('efyx ', FontWeight.w400),
        _titlePart('VPN', FontWeight.w400, color: Colors.white),
      ],
    );
  }

  Widget _titlePart(String text, FontWeight weight, {Color? color}) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Lato',
        fontSize: 34.sp,
        color: color ?? const Color(0xFFFFC927),
        fontWeight: weight,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      "Crafted for secure internet access,\ndesigned for everyone, everywhere",
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Lato',
        fontSize: 18.sp,
        color: const Color(0xFFCFCFCF),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 28.w,
      height: 28.w,
      child: const CircularProgressIndicator(
        strokeCap: StrokeCap.round,
        color: Colors.white,
        strokeWidth: 4.5,
      ),
    );
  }
}
