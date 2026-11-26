import 'package:defyx_vpn/common/helpers/truncate_text.dart';
import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/marketplace_info_sheet.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_toast_message.dart';
import 'package:defyx_vpn/shared/utils/tv_keyboard_helper.dart';
import 'package:defyx_vpn/shared/widgets/tv_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/method_sections.dart';
import '../../models/settings_item.dart';
import '../../../../shared/widgets/defyx_switch.dart';

/// The most characters of a connection method's name a row shows; longer
/// names end in "...".
const methodTitleMaxLength = 20;

/// [text] as a method row shows it: upper case, cut to
/// [methodTitleMaxLength] characters with "...". A cut title is wrapped in a
/// Unicode isolate so its "..." stays at the end of a Latin name in
/// right-to-left text.
String methodTitle(String text) {
  final upper = text.toUpperCase();
  final cut = truncateText(upper, methodTitleMaxLength);
  return cut == upper ? upper : '\u2068$cut\u2069';
}

/// Key handling for a row being moved with the D-pad: Up/Down move it by one
/// and OK ends the move. Ignores keys while [isMoving] is false.
KeyEventResult handleDpadMoveKeys(
  KeyEvent event, {
  required bool isMoving,
  ValueChanged<int>? onMove,
  VoidCallback? onMoveEnd,
}) {
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

  /// Shown instead of the item's title (e.g. a plan location's country).
  final String? titleOverride;

  /// A small second line under the title (seller, days left…).
  final String? caption;

  /// Leaves out the premium/market icons and the info icon, for rows inside
  /// a plan whose header already shows them.
  final bool compact;

  /// Extra space before the row's content, for rows inside a plan.
  final double indent;

  /// Shown before the title, e.g. a location's flag.
  final Widget? leading;

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
    this.titleOverride,
    this.caption,
    this.compact = false,
    this.indent = 0,
    this.leading,
  });

  void _handleTap() {
    if (item.itemType == SettingsItemType.navigation &&
        item.navigationRoute != null) {
      onNavigate?.call(item.navigationRoute!);
    } else {
      onToggle?.call();
    }
  }

  KeyEventResult _handleMoveKeys(FocusNode node, KeyEvent event) =>
      handleDpadMoveKeys(
        event,
        isMoving: isMoving,
        onMove: onMove,
        onMoveEnd: onMoveEnd,
      );

  @override
  Widget build(BuildContext context) {
    // Badges follow the method's section, not its flags: the backend still
    // marks free rewards isMarket for older apps.
    final section = item.section;
    final isPremium = section == MethodSection.premium;
    final isMarket = section == MethodSection.market;
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
              margin: EdgeInsetsDirectional.only(end: 12.w),
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
            margin: EdgeInsetsDirectional.only(end: 12.w),
            child: SvgPicture.asset(
              'assets/icons/draggable_setting_indicator.svg',
              width: 24.w,
              height: 24.h,
              colorFilter: ColorFilter.mode(Colors.grey[400]!, BlendMode.srcIn),
            ),
          ),
        ],
        Expanded(
          child: _withCaption(
            Row(
              // align center
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 7.w,
              children: [
                if (leading != null)
                  // Faded with the title when the row is off.
                  Opacity(opacity: item.isAccessible ? 1 : 0.4, child: leading),
                // The info icons are touch-only; D-pad users see the
                // description under the list instead.
                if (isPremium && !compact)
                  InkWell(
                    canRequestFocus: false,
                    child: AppIcons.premium(height: 18, width: 18),
                    onTap: () =>
                        SettingsToastMessage.show(item.description ?? ""),
                  ),
                if (isMarket && !compact)
                  InkWell(
                    canRequestFocus: false,
                    child: AppIcons.market(height: 18, width: 18),
                    onTap: () =>
                        SettingsToastMessage.show(item.description ?? ""),
                  ),
                Flexible(
                  fit: isPremium && !compact ? FlexFit.tight : FlexFit.loose,
                  child: Text(
                    methodTitle(titleOverride ?? item.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                      color: item.isAccessible
                          ? Colors.white
                          : Colors.grey[600],
                    ),
                  ),
                ),
                if (compact)
                  const SizedBox.shrink()
                else if (isPremium)
                  Padding(
                    padding: EdgeInsetsDirectional.only(end: 12.w),
                    child: _buildInfoIcon(
                      onTap: () => MarketplaceInfoSheet.show(context, item),
                    ),
                  )
                else if (item.description != null &&
                    item.description!.isNotEmpty)
                  _buildInfoIcon(
                    onTap: () =>
                        SettingsToastMessage.show(item.description ?? ""),
                  ),
              ],
            ),
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
        // Long titles (full country names) stop short of the switch.
        if (compact) SizedBox(width: 8.w),
        _buildTrailingWidget(),
      ],
    );

    Widget content = Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.identity(),
          padding: EdgeInsetsDirectional.fromSTEB(
            12.w + indent,
            8.h,
            12.w,
            8.h,
          ),
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

  Widget _withCaption(Widget titleRow) {
    if (caption == null) return titleRow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleRow,
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
    );
  }

  Widget _buildInfoIcon({required VoidCallback onTap}) {
    return InkWell(
      canRequestFocus: false,
      onTap: onTap,
      child: AppIcons.info(
        height: 22,
        width: 20,
        colorFilter: const ColorFilter.mode(Color(0xFF8C8C8C), BlendMode.srcIn),
      ),
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
