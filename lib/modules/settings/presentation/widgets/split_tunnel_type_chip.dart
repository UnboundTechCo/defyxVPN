import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const Color _chipColor = Color(0xFF1D1D1D);

class SplitTunnelTypeChip extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String>? onSelected;

  const SplitTunnelTypeChip({
    super.key,
    required this.value,
    this.options = const [],
    this.onSelected,
  });

  bool get _isSelectable => options.length > 1 && onSelected != null;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: _chipColor,
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 17.sp,
              fontFamily: AppTheme.fontFamily,
              color: Colors.white,
            ),
          ),
          if (_isSelectable) ...[
            SizedBox(width: 6.w),
            Icon(Icons.keyboard_arrow_down, size: 20.sp, color: Colors.white),
          ],
        ],
      ),
    );

    if (!_isSelectable) return chip;

    return PopupMenuButton<String>(
      tooltip: '',
      padding: EdgeInsets.zero,
      color: _chipColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<String>(
            value: option,
            child: Text(
              option,
              style: TextStyle(
                fontSize: 17.sp,
                fontFamily: AppTheme.fontFamily,
                color: option == value ? const Color(0xFFFFC927) : Colors.white,
              ),
            ),
          ),
      ],
      child: chip,
    );
  }
}
