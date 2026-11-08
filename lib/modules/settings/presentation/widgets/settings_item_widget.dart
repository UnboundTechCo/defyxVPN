import 'package:defyx_vpn/common/helpers/truncate_text.dart';
import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_toast_message.dart';
import 'package:defyx_vpn/shared/utils/tv_keyboard_helper.dart';
import 'package:defyx_vpn/shared/widgets/tv_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/settings_item.dart';
import '../../../../shared/widgets/defyx_switch.dart';

/// A settings row. With a remote it is a single focus stop: OK runs the same
/// action as a tap (toggle or open). Draggable rows can also be moved with the
/// D-pad: holding OK starts the move mode, Up/Down move the row, OK ends it.
class SettingsItemWidget extends StatelessWidget {
  final SettingsItem item;
  final VoidCallback? onToggle;
  final Function(String)? onNavigate;
  final bool isDraggable;
  final bool isLastItem;
  final bool showDragHandle;
  final int? dragIndex;
  final bool showSeparator;

  /// Focus node owned by the parent, so focus survives the row being rebuilt.
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;

  /// Called when OK is held on the row. Starts the D-pad move mode.
  final VoidCallback? onSelectLongPress;

  /// Whether the row is being moved with the D-pad.
  final bool isMoving;

  /// Moves the row by -1 (up) or +1 (down) while [isMoving].
  final ValueChanged<int>? onMove;

  /// Ends the move mode.
  final VoidCallback? onMoveEnd;

  /// A short D-pad hint shown next to the switch (e.g. how to reorder).
  final String? dpadHint;

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
    this.focusNode,
    this.onFocusChange,
    this.onSelectLongPress,
    this.isMoving = false,
    this.onMove,
    this.onMoveEnd,
    this.dpadHint,
  });

  void _handleTap() {
    if (item.itemType == SettingsItemType.navigation &&
        item.navigationRoute != null) {
      onNavigate?.call(item.navigationRoute!);
    } else {
      onToggle?.call();
    }
  }

  KeyEventResult _handleMoveKeys(FocusNode node, KeyEvent event) {
    if (!isMoving) return KeyEventResult.ignored;

    final direction = TvKeyboardHelper.directionOf(event);
    if (direction != null) {
      if (event is! KeyUpEvent) {
        if (direction == TraversalDirection.up) onMove?.call(-1);
        if (direction == TraversalDirection.down) onMove?.call(1);
      }
      // Focus stays on the row while it is being moved.
      return KeyEventResult.handled;
    }
    if (TvKeyboardHelper.isActivationKey(event)) {
      if (event is KeyDownEvent) onMoveEnd?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final handleColor = isMoving
        ? TvFocusable.focusRingColor
        : item.isAccessible
        ? Colors.grey[400]!
        : Colors.grey[600]!;

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
              child: isMoving
                  ? Icon(Icons.swap_vert, size: 24.w, color: handleColor)
                  : SvgPicture.asset(
                      'assets/icons/draggable_setting_indicator.svg',
                      width: 24.w,
                      height: 24.h,
                      colorFilter: ColorFilter.mode(
                        handleColor,
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
              // The info icons are touch-only; D-pad users see the
              // description under the list instead.
              if (item.isPremium)
                InkWell(
                  canRequestFocus: false,
                  child: AppIcons.premium(height: 18, width: 18),
                  onTap: () =>
                      SettingsToastMessage.show(item.description ?? ""),
                ),
              if (item.isMarket)
                InkWell(
                  canRequestFocus: false,
                  child: AppIcons.market(height: 18, width: 18),
                  onTap: () =>
                      SettingsToastMessage.show(item.description ?? ""),
                ),
              Flexible(
                child: Text(
                  truncateText(item.title.toUpperCase(), 20),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w400,
                    color: item.isAccessible ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
              if (item.description != null &&
                  item.description!.isNotEmpty &&
                  !item.isPremium)
                InkWell(
                  canRequestFocus: false,
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
                ),
            ],
          ),
        ),
        if (dpadHint != null)
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Text(
                dpadHint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w600,
                  color: TvFocusable.focusRingColor,
                  letterSpacing: 0.5,
                ),
              ),
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
          decoration: isMoving
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  color: TvFocusable.focusRingColor.withValues(alpha: 0.18),
                )
              : isDraggable
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  color: Colors.transparent,
                )
              : null,
          child: Opacity(opacity: 1.0, child: rowContent),
        ),
        if (!isLastItem && showSeparator)
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.05),
            margin: EdgeInsets.symmetric(vertical: 2.h),
          ),
      ],
    );

    return TvFocusable(
      focusNode: focusNode,
      onTap: _handleTap,
      onSelectLongPress: onSelectLongPress,
      onKeyEvent: _handleMoveKeys,
      onFocusChange: onFocusChange,
      borderRadius: BorderRadius.circular(8.r),
      child: content,
    );
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
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                color: Colors.grey[500],
              ),
            ),
          if (item.subtitle != null) SizedBox(width: 8.w),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 24.sp),
        ],
      );
    }

    // The row is the focus stop and toggles this switch with OK.
    return DefyxSwitch(
      value: item.isEnabled,
      onChanged: item.isAccessible ? (_) => onToggle?.call() : null,
      enabled: item.isAccessible,
      focusable: false,
    );
  }
}
