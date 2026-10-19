import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SplitTunnelEntryRow extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const SplitTunnelEntryRow({
    super.key,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17.sp,
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: EdgeInsets.all(4.r),
              child: Icon(Icons.close, size: 22.sp, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }
}
