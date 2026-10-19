import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SplitTunnelSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const SplitTunnelSearchField({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      child: Row(
        children: [
          Icon(Icons.search, size: 22.sp, color: Colors.grey[400]),
          SizedBox(width: 8.w),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 17.sp,
                fontFamily: AppTheme.fontFamily,
                color: Colors.white,
              ),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).splitTunnelSearch,
                hintStyle: TextStyle(
                  fontSize: 17.sp,
                  fontFamily: AppTheme.fontFamily,
                  color: Colors.grey[400],
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14.h),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
