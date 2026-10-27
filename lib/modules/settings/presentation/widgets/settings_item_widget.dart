import 'package:defyx_vpn/common/helpers/truncate_text.dart';
import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_toast_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/settings_item.dart';
import '../../../../shared/widgets/defyx_switch.dart';

class SettingsItemWidget extends StatefulWidget {
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
  State<SettingsItemWidget> createState() => _SettingsItemWidgetState();
}

class _SettingsItemWidgetState extends State<SettingsItemWidget> {
  late FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _hasFocus = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget rowContent = Row(
      children: [
        if (widget.showDragHandle && widget.dragIndex != null) ...[
          ReorderableDragStartListener(
            index: widget.dragIndex!,
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
                  widget.item.isAccessible
                      ? Colors.grey[400]!
                      : Colors.grey[600]!,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ] else if (widget.item.showLeftIcon) ...[
          Container(
            width: 24.w,
            height: 24.h,
            margin: EdgeInsets.only(right: 12.w),
            child: SvgPicture.asset(
              'assets/icons/draggable_setting_indicator.svg',
              width: 24.w,
              height: 24.h,
              colorFilter: ColorFilter.mode(Colors.grey[400]!, BlendMode.srcIn),
            ),
          ),
        ],
        Expanded(
          child: Row(
            // align center
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 7.w,
            children: [
              if (widget.item.isPremium)
                InkWell(
                  child: AppIcons.premium(height: 18, width: 18),
                  onTap: () =>
                      SettingsToastMessage.show(widget.item.description ?? ""),
                ),
              Text(
                truncateText(widget.item.title.toUpperCase(), 20),
                style: TextStyle(
                  fontSize: 17.sp,
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  color: widget.item.isAccessible
                      ? Colors.white
                      : Colors.grey[600],
                ),
              ),
              if (widget.item.description != null &&
                  widget.item.description!.isNotEmpty &&
                  !widget.item.isPremium)
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
                      SettingsToastMessage.show(widget.item.description ?? ""),
                ),
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
          decoration: widget.isDraggable
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  color: Colors.transparent,
                )
              : null,
          child: Opacity(opacity: 1.0, child: rowContent),
        ),
        if (!widget.isLastItem && widget.showSeparator)
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.05),
            margin: EdgeInsets.symmetric(vertical: 2.h),
          ),
      ],
    );

    return Focus(
      focusNode: _focusNode,
      child: GestureDetector(
        onTap: () {
          if (widget.item.itemType == SettingsItemType.navigation &&
              widget.item.navigationRoute != null) {
            widget.onNavigate?.call(widget.item.navigationRoute!);
          } else {
            widget.onToggle?.call();
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: _hasFocus && widget.item.isAccessible
              ? BoxDecoration(
                  border: Border.all(color: const Color(0xFFFFD700), width: 2),
                  borderRadius: BorderRadius.circular(8.r),
                )
              : null,
          child: content,
        ),
      ),
    );
  }

  Widget _buildTrailingWidget() {
    if (widget.item.itemType == SettingsItemType.navigation) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.item.subtitle != null)
            Text(
              widget.item.subtitle!,
              style: TextStyle(
                fontSize: 14.sp,
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                color: Colors.grey[500],
              ),
            ),
          if (widget.item.subtitle != null) SizedBox(width: 8.w),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 24.sp),
        ],
      );
    }

    return DefyxSwitch(
      value: widget.item.isEnabled,
      onChanged: widget.item.isAccessible
          ? (_) => widget.onToggle?.call()
          : null,
      enabled: widget.item.isAccessible,
    );
  }
}
