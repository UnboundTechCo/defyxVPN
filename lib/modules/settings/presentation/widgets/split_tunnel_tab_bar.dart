import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum SplitTunnelTab { addresses, apps }

class SplitTunnelTabBar extends StatelessWidget {
  final SplitTunnelTab selected;
  final ValueChanged<SplitTunnelTab> onChanged;

  const SplitTunnelTabBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Row(
        children: [
          _TabSegment(
            label: l10n.splitTunnelTabAddresses,
            isSelected: selected == SplitTunnelTab.addresses,
            onTap: () => onChanged(SplitTunnelTab.addresses),
          ),
          _TabSegment(
            label: l10n.splitTunnelTabApps,
            isSelected: selected == SplitTunnelTab.apps,
            onTap: () => onChanged(SplitTunnelTab.apps),
          ),
        ],
      ),
    );
  }
}

class _TabSegment extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabSegment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: 10.h),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1D1D1D) : Colors.transparent,
            borderRadius: BorderRadius.circular(100.r),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15.sp,
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
