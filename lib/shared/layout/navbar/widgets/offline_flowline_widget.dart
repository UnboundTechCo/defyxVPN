import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/shared/providers/flow_line_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';

class OfflineFlowlineWidget extends ConsumerStatefulWidget {
  const OfflineFlowlineWidget({super.key});

  @override
  ConsumerState<OfflineFlowlineWidget> createState() =>
      _OfflineFlowlineWidgetState();
}

class _OfflineFlowlineWidgetState extends ConsumerState<OfflineFlowlineWidget> {
  @override
  Widget build(BuildContext context) {
    final flowlineData = ref.watch(flowLineProvider.notifier);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(10.r),
      ),
      padding: EdgeInsets.all(16.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 16.h,
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEA9F),
              borderRadius: BorderRadius.circular(6.r),
            ),

            child: Center(
              child: AppIcons.vpnCloud(width: 24.w, height: 24.h),
            ),
          ),
          Flexible(
            child: Text(
              AppLocalizations.of(context).offlineFlowlineMessage,
              style: TextStyle(fontSize: 14.sp, color: Colors.black87),
            ),
          ),
          TextButton(
            onPressed: () {
              flowlineData.setMode("online");
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFF2F2F2),
              padding: EdgeInsets.all(10.h),
            ),
            child: Text(AppLocalizations.of(context).offlineFlowlineUndo),
          ),
        ],
      ),
    );
  }
}
