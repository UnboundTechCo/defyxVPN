import 'package:defyx_vpn/core/theme/app_colors.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/split_tunnel_config.dart';

class SplitTunnelModeSelector extends StatelessWidget {
  final SplitTunnelMode selected;
  final ValueChanged<SplitTunnelMode> onChanged;

  const SplitTunnelModeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static String labelOf(AppLocalizations l10n, SplitTunnelMode mode) {
    switch (mode) {
      case SplitTunnelMode.off:
        return l10n.splitTunnelModeOff;
      case SplitTunnelMode.excludeSelected:
        return l10n.splitTunnelModeExclude;
      case SplitTunnelMode.onlySelected:
        return l10n.splitTunnelModeOnly;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
      ),
      padding: EdgeInsets.fromLTRB(2.w, 1.h, 2.w, 1.h),
      child: Column(
        children: [
          for (final mode in SplitTunnelMode.values)
            _ModeRow(
              label: labelOf(l10n, mode),
              isSelected: mode == selected,
              onTap: () => onChanged(mode),
            ),
        ],
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeRow({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                size: 24.sp,
                color: AppColors.bottomGradientConnected,
              )
            else
              SizedBox(height: 24.sp),
          ],
        ),
      ),
    );
  }
}
