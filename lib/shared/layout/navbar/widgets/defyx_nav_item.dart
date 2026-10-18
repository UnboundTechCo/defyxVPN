import 'package:defyx_vpn/shared/providers/app_screen_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DefyxNavItem extends StatefulWidget {
  final AppScreen screen;
  final String icon;
  final AppScreen current;
  final VoidCallback onTap;
  final bool isLoading;
  final FocusNode? focusNode;

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
    this.focusNode,
  });

  @override
  State<DefyxNavItem> createState() => _DefyxNavItemState();
}

class _DefyxNavItemState extends State<DefyxNavItem> {
  late FocusNode _internalFocusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = widget.focusNode ?? FocusNode();
    _internalFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    } else {
      _internalFocusNode.removeListener(_handleFocusChange);
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _hasFocus = _internalFocusNode.hasFocus;
    });
  }

  void _handleTap() {
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.current == widget.screen;

    final double iconSize = DefyxNavItem._defaultIconSize.w;
    final double selectedIncrease = DefyxNavItem._selectedIconIncrease.w;
    final double loadingSize = DefyxNavItem._defaultIconSize - 5;

    return Focus(
      focusNode: _internalFocusNode,
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          width: DefyxNavItem._navItemSize.w,
          height: DefyxNavItem._navItemSize.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? const Color(0xFF555555) : Colors.transparent,
            border: _hasFocus
                ? Border.all(color: const Color(0xFFFFD700), width: 2.0)
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: loadingSize,
                    height: loadingSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                  )
                : SvgPicture.asset(
                    'assets/icons/${widget.icon}.svg',
                    width: isSelected ? iconSize + selectedIncrease : iconSize,
                    height: isSelected ? iconSize + selectedIncrease : iconSize,
                    colorFilter: ColorFilter.mode(
                      isSelected ? Colors.white : Colors.grey,
                      BlendMode.srcIn,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
