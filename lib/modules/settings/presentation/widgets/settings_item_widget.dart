import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/settings_item.dart';
import '../../../../shared/widgets/defyx_switch.dart';

class SettingsItemWidget extends StatelessWidget {
  final SettingsItem item;
  final VoidCallback? onToggle;
  final bool isDraggable;
  final bool isLastItem;
  final bool showDragHandle;
  final int? dragIndex;
  final bool
      showSeparator;

  const SettingsItemWidget({
    super.key,
    required this.item,
    this.onToggle,
    this.isDraggable = false,
    this.isLastItem = false,
    this.showDragHandle = false,
    this.dragIndex,
    this.showSeparator = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget rowContent = Row(
      children: [
        if (showDragHandle && dragIndex != null) ...[
          ReorderableDragStartListener(
            index: dragIndex!,
            child: Container(
              width: 24.w,
              height: 24.h,
              margin: EdgeInsets.only(right: 12.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4.r),
                color: Colors.transparent,
              ),
              child: SvgPicture.asset(
                'assets/icons/draggable_setting_indicator.svg',
                width: 24.w,
                height: 24.h,
                colorFilter: ColorFilter.mode(
                  item.isAccessible ? Colors.grey[400]! : Colors.grey[600]!,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
        Expanded(
          child: Text(
            item.title.toUpperCase(),
            style: TextStyle(
              fontSize: 17.sp,
              fontFamily: 'Lato',
              fontWeight: FontWeight.w400,
              color: item.isAccessible ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
        DefyxSwitch(
          value: item.isEnabled,
          onChanged: item.isAccessible ? (_) => onToggle?.call() : null,
          enabled: item.isAccessible,
        ),
      ],
    );

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.identity(),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          margin: EdgeInsets.symmetric(vertical: 2.h),
          decoration: isDraggable
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  color: Colors.transparent,
                )
              : null,
          child: Opacity(
            opacity: 1.0,
            child: rowContent,
          ),
        ),
        if (!isLastItem && showSeparator)
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.05),
            margin: EdgeInsets.symmetric(vertical: 2.h),
          ),
      ],
    );
  }
}
