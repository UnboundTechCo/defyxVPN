import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_toast_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/settings_item.dart';
import '../../../../shared/widgets/defyx_switch.dart';

class SettingsItemWidget extends StatelessWidget {
  final SettingsItem item;
  final VoidCallback? onToggle;
  final Function(String)? onNavigate;
  final bool isDraggable;
  final bool isLastItem;
  final bool showDragHandle;
  final int? dragIndex;
  final bool showSeparator;

  const SettingsItemWidget({
    super.key,
    required this.item,
    this.onToggle,
    this.onNavigate,
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
        ] else if (item.showLeftIcon) ...[
          Container(
            width: 24.w,
            height: 24.h,
            margin: EdgeInsets.only(right: 12.w),
            child: SvgPicture.asset(
              'assets/icons/draggable_setting_indicator.svg',
              width: 24.w,
              height: 24.h,
              colorFilter: ColorFilter.mode(
                Colors.grey[400]!,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
        Expanded(
          child: Row(
            spacing: 7.w,
            children: [
              Text(
                item.title.toUpperCase(),
                style: TextStyle(
                  fontSize: 17.sp,
                  fontFamily: 'Lato',
                  fontWeight: FontWeight.w400,
                  color: item.isAccessible ? Colors.white : Colors.grey[600],
                ),
              ),
              if (item.description != null && item.description!.isNotEmpty)
                InkWell(
                  child: AppIcons.info(
                    height: 22,
                    width: 20,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF8C8C8C),
                      BlendMode.srcIn,
                    ),
                  ),
                  onTap: () =>
                      SettingsToastMessage.show(item.description ?? ""),
                )
            ],
          ),
        ),
        _buildTrailingWidget(),
      ],
    );

    Widget content = Column(
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

    if (item.itemType == SettingsItemType.navigation &&
        item.navigationRoute != null) {
      return GestureDetector(
        onTap: () => onNavigate?.call(item.navigationRoute!),
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }

  Widget _buildTrailingWidget() {
    if (item.itemType == SettingsItemType.navigation) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.subtitle != null)
            Text(
              item.subtitle!,
              style: TextStyle(
                fontSize: 14.sp,
                fontFamily: 'Lato',
                fontWeight: FontWeight.w400,
                color: Colors.grey[500],
              ),
            ),
          if (item.subtitle != null) SizedBox(width: 8.w),
          Icon(
            Icons.chevron_right,
            color: Colors.grey[400],
            size: 24.sp,
          ),
        ],
      );
    }

    return DefyxSwitch(
      value: item.isEnabled,
      onChanged: item.isAccessible ? (_) => onToggle?.call() : null,
      enabled: item.isAccessible,
    );
  }
}
