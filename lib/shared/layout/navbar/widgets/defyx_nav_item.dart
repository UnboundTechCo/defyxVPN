import 'package:defyx_vpn/shared/providers/app_screen_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DefyxNavItem extends StatelessWidget {
  final AppScreen screen;
  final String icon;
  final AppScreen current;
  final VoidCallback onTap;
  final bool isLoading;

  static const double _navItemSize = 55;
  static const double _defaultIconSize = 25;
  static const double _selectedIconIncrease = 8;

  const DefyxNavItem({
    super.key,
    required this.screen,
    required this.icon,
    required this.current,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == screen;

    final double iconSize = _defaultIconSize.w;
    final double selectedIncrease = _selectedIconIncrease.w;
    final double loadingSize = _defaultIconSize - 5;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _navItemSize.w,
        height: _navItemSize.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? const Color(0xFF555555) : Colors.transparent,
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: loadingSize,
                  height: loadingSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                )
              : SvgPicture.asset(
                  'assets/icons/$icon.svg',
                  width: isSelected ? iconSize + selectedIncrease : iconSize,
                  height: isSelected ? iconSize + selectedIncrease : iconSize,
                  colorFilter: ColorFilter.mode(
                    isSelected ? Colors.white : Colors.grey,
                    BlendMode.srcIn,
                  ),
                ),
        ),
      ),
    );
  }
}
