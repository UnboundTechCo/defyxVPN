import 'package:defyx_vpn/shared/providers/haptic_provider.dart';
import 'package:defyx_vpn/shared/widgets/defyx_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HapticSettingWidget extends ConsumerWidget {
  const HapticSettingWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticEnabled = ref.watch(hapticEnabledProvider);

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
            child: Text(
              'PREFERENCES',
              style: TextStyle(
                fontSize: 13.sp,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w400,
                color: Colors.grey[400],
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.r),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HAPTIC FEEDBACK',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontFamily: 'Lato',
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Vibration on connect/disconnect',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontFamily: 'Lato',
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                DefyxSwitch(
                  value: hapticEnabled,
                  onChanged: (value) {
                    ref.read(hapticEnabledProvider.notifier).toggle();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
