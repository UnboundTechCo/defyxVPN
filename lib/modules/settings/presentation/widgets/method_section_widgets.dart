import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/shared/services/animation_service.dart';
import 'package:defyx_vpn/shared/widgets/defyx_switch.dart';
import 'package:defyx_vpn/shared/widgets/tv_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'settings_item_widget.dart';

/// The header of a connection-method section (Premium, Market, Built-in,
/// Rewards). Tapping it, or OK on the remote, opens or closes the section.
class MethodSectionHeader extends StatelessWidget {
  const MethodSectionHeader({
    super.key,
    required this.title,
    required this.summary,
    required this.expanded,
    required this.onTap,
    this.showDivider = false,
    this.focusNode,
    this.onFocusChange,
  });

  final String title;

  /// What the section holds, e.g. "2 of 5 on".
  final String summary;
  final bool expanded;
  final VoidCallback onTap;

  /// A line above the header, between it and the section before.
  final bool showDivider;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 13.sp,
      fontFamily: AppTheme.fontFamily,
      fontWeight: FontWeight.w400,
      color: Colors.grey[400],
      letterSpacing: 0.5,
    );

    return Column(
      children: [
        if (showDivider)
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        TvFocusable(
          focusNode: focusNode,
          onTap: onTap,
          onFocusChange: onFocusChange,
          borderRadius: BorderRadius.circular(8.r),
          child: Semantics(
            button: true,
            expanded: expanded,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                  Text(summary, style: style.copyWith(color: Colors.grey[500])),
                  SizedBox(width: 8.w),
                  _Chevron(expanded: expanded),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The row for a plan with several locations. Tapping it opens or closes
/// the locations; its switch turns the whole plan on or off. With a remote,
/// the row and the switch are separate focus stops, and holding OK on the row
/// starts moving the plan.
class MethodPlanHeader extends StatelessWidget {
  const MethodPlanHeader({
    super.key,
    required this.title,
    required this.isOn,
    required this.expanded,
    required this.onTap,
    this.caption,
    this.isPremium = false,
    this.isMarket = false,
    this.onInfo,
    this.onToggle,
    this.dragIndex,
    this.focusNode,
    this.onFocusChange,
    this.onSelectLongPress,
    this.isMoving = false,
    this.onMove,
    this.onMoveEnd,
    this.dpadHint,
    this.showSeparator = true,
  });

  final String title;

  /// A small second line: seller or features, and days left.
  final String? caption;
  final bool isPremium;
  final bool isMarket;
  final VoidCallback? onInfo;

  /// Whether the plan is switched on.
  final bool isOn;
  final VoidCallback? onToggle;
  final bool expanded;
  final VoidCallback onTap;

  /// The plan's index in its section's list, for dragging.
  final int? dragIndex;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;
  final VoidCallback? onSelectLongPress;
  final bool isMoving;
  final ValueChanged<int>? onMove;
  final VoidCallback? onMoveEnd;
  final String? dpadHint;
  final bool showSeparator;

  @override
  Widget build(BuildContext context) {
    final handleColor = isMoving
        ? TvFocusable.focusRingColor
        : Colors.grey[400]!;

    final row = Row(
      children: [
        if (dragIndex != null)
          ReorderableDragStartListener(
            index: dragIndex!,
            child: Container(
              width: 24.w,
              height: 24.h,
              margin: EdgeInsetsDirectional.only(end: 12.w),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                spacing: 7.w,
                children: [
                  if (isPremium) AppIcons.premium(height: 18, width: 18),
                  if (isMarket) AppIcons.market(height: 18, width: 18),
                  Flexible(
                    child: Text(
                      title.toUpperCase(),
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
                  if (onInfo != null)
                    // Touch-only, like the other rows' info icons.
                    InkWell(
                      canRequestFocus: false,
                      onTap: onInfo,
                      child: AppIcons.info(
                        height: 22,
                        width: 20,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF8C8C8C),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                ],
              ),
              if (caption != null)
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontFamily: AppTheme.fontFamily,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
        ),
        if (dpadHint != null)
          Flexible(
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
        _Chevron(expanded: expanded),
      ],
    );

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.symmetric(vertical: 2.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
            color: isMoving
                ? TvFocusable.focusRingColor.withValues(alpha: 0.18)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Expanded(
                child: TvFocusable(
                  focusNode: focusNode,
                  onTap: onTap,
                  onSelectLongPress: onSelectLongPress,
                  onKeyEvent: (node, event) => handleDpadMoveKeys(
                    event,
                    isMoving: isMoving,
                    onMove: onMove,
                    onMoveEnd: onMoveEnd,
                  ),
                  onFocusChange: onFocusChange,
                  borderRadius: BorderRadius.circular(8.r),
                  child: Semantics(
                    button: true,
                    expanded: expanded,
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        12.w,
                        8.h,
                        8.w,
                        8.h,
                      ),
                      child: row,
                    ),
                  ),
                ),
              ),
              // Beside the row rather than inside it, so the D-pad reaches
              // it with Right (directional focus skips targets inside the
              // focused one).
              DefyxSwitch(
                value: isOn,
                onChanged: onToggle == null ? null : (_) => onToggle!(),
              ),
              SizedBox(width: 12.w),
            ],
          ),
        ),
        if (showSeparator)
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.05),
            margin: EdgeInsets.symmetric(vertical: 2.h),
          ),
      ],
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: expanded ? 0.5 : 0,
      duration: AnimationService().adjustDuration(
        const Duration(milliseconds: 200),
      ),
      child: Icon(Icons.expand_more, size: 22.sp, color: Colors.grey[400]),
    );
  }
}
