import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_premium_info_dialog.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_premium_login_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SettingsPremiumWidget extends StatelessWidget {
  const SettingsPremiumWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        // #EAEAEA29
        // color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.white.withOpacity(0.16), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Marketplace'.toUpperCase(),
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Browse secure VPN configurations from trusted suppliers',
                  style: TextStyle(fontSize: 13.sp, color: Colors.white60),
                  maxLines: 3,
                  softWrap: true,
                ),
                SizedBox(height: 10.h),
                Row(
                  // Align items to the center vertically
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => SettingsPremiumInfoDialog.show(context),
                      child: AppIcons.info(
                        height: 16,
                        width: 16,
                        colorFilter: ColorFilter.mode(
                          Colors.white.withOpacity(0.16),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: InkWell(
                        onTap: () => SettingsPremiumLoginDialog.show(context),
                        child: Text(
                          'LOGIN OR REGISTER',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Color(0xFFFF9A9A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Container(
            width: 50,
            height: 50,
            padding: EdgeInsets.all(13.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50.r),
              color: const Color(0xFF6F7987),
            ),
            child: AppIcons.shop(width: 24, height: 24),
          ),
        ],
      ),
    );
  }
}
