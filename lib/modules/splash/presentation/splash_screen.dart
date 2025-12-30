import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/modules/core/vpn.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

  Future<void> _navigateToMain() async {
    await WidgetsBinding.instance.endOfFrame;
    Future.delayed(Duration(seconds: 3), () {
      _onNavigate();
      return;
    });
    // final vpnData = await ref.read(vpnDataProvider.future);
    final vpnStatus = await VpnBridge().getVpnStatus();

    if (vpnStatus == "connected") {
      _onNavigate();
      return;
    }

    if (ref.context.mounted) {
      final vpn = VPN(ProviderScope.containerOf(ref.context));
      await vpn.initVPN();
      _onNavigate();
      return;
    } else {
      await Future.delayed(const Duration(seconds: 3));
    }
    _onNavigate();
  }

  void _onNavigate() {
    if (!ref.context.mounted) return;
    final currentRoute = ref.read(currentRouteProvider);
    if (currentRoute == DefyxVPNRoutes.splash.route) {
      context.go('/main');
    }
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
      child: const AlwaysSpinningIndicator(),
    );
  }
}

class AlwaysSpinningIndicator extends StatefulWidget {
  const AlwaysSpinningIndicator({super.key});

  @override
  State<AlwaysSpinningIndicator> createState() =>
      _AlwaysSpinningIndicatorState();
}

class _AlwaysSpinningIndicatorState extends State<AlwaysSpinningIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const CircularProgressIndicator(
        strokeCap: StrokeCap.round,
        color: Colors.white,
        strokeWidth: 4.5,
      ),
    );
  }
}
