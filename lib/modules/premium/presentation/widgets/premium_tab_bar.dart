import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/modules/premium/providers/premium_tab_provider.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PremiumTabBar extends StatefulWidget {
  final WidgetRef ref;
  final PremiumTab selectedTab;
  final Function(PremiumTab) onTabChanged;

  const PremiumTabBar({
    super.key,
    required this.ref,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  State<PremiumTabBar> createState() => _PremiumTabBarState();
}

class _PremiumTabBarState extends State<PremiumTabBar> {
  bool _isLoggedIn = false;

  @override
  Widget build(BuildContext context) {
    final authState = widget.ref.watch(authProvider);
    authState.when(
      data: (data) => setState(() {
        _isLoggedIn = data.isLoggedIn;
      }),
      loading: () {},
      error: (e, st) {},
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTabButton(
              AppIcons.userPath,
              'ACCOUNT',
              PremiumTab.account,
              false,
            ),
            SizedBox(width: 24.w),
            _buildTabButton(
              AppIcons.plansPath,
              'PLANS',
              PremiumTab.plans,
              !_isLoggedIn,
            ),
            SizedBox(width: 24.w),
            _buildTabButton(
              AppIcons.walletPath,
              'WALLET',
              PremiumTab.wallet,
              !_isLoggedIn,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(
    String path,
    String label,
    PremiumTab tab,
    bool isDisabled,
  ) {
    final isSelected = widget.selectedTab == tab;
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: isDisabled ? null : () => widget.onTabChanged(tab),
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                color: isSelected
                    ? const Color(0xFF21AD86)
                    : const Color(0xFFEAEBEB),
              ),
              child: Center(
                child: SvgPicture.asset(
                  path,
                  width: 24.w,
                  height: 24.h,
                  colorFilter: isSelected
                      ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                      : const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                ),
              ),
            ),
          ),
          SizedBox(height: 9.h),
          Text(
            label,
            style: TextStyle(
              color: Colors.black,
              fontSize: 10.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
