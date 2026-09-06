import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/modules/premium/presentation/screens/account_screen.dart';
import 'package:defyx_vpn/modules/premium/presentation/screens/plans_screen.dart';
import 'package:defyx_vpn/modules/premium/presentation/screens/wallet_screen.dart';
import 'package:defyx_vpn/modules/premium/presentation/widgets/premium_tab_bar.dart';
import 'package:defyx_vpn/modules/premium/providers/premium_tab_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(premiumTabProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 24.h),
            // Header with back button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
              child: SizedBox(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => context.go(DefyxVPNRoutes.settings.route),
                        child: AppIcons.arrowLeft(
                          width: 50.w,
                          height: 50.h,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFFFFC927),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Text(
                          'Premium',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Positioned(
                          top: -4.h,
                          left: 0.w,
                          child: AppIcons.crown(height: 18.h, width: 18.w),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Tab bar
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(height: 25.h),
                    Center(
                      child: PremiumTabBar(
                        ref: ref,
                        selectedTab: selectedTab,
                        onTabChanged: (tab) {
                          ref.read(premiumTabProvider.notifier).state = tab;
                        },
                      ),
                    ),
                    Expanded(child: _buildTabContent(selectedTab)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(PremiumTab tab) {
    switch (tab) {
      case PremiumTab.account:
        return const AccountScreen();
      case PremiumTab.plans:
        return const PlansScreen();
      case PremiumTab.wallet:
        return const WalletScreen();
    }
  }
}
