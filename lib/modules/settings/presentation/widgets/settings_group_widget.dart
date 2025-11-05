import 'package:defyx_vpn/modules/settings/models/settings_item.dart';
import 'package:defyx_vpn/shared/services/animation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/settings_group.dart';
import 'settings_item_widget.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../shared/widgets/defyx_switch.dart';

class SettingsGroupWidget extends StatefulWidget {
  final SettingsGroup group;
  final Function(String, String)? onToggle;
  final VoidCallback? onReset;
  final ReorderCallback? onReorder;
  final bool
      showSeparators; // Controls whether separators are shown between items

  const SettingsGroupWidget({
    super.key,
    required this.group,
    this.onToggle,
    this.onReset,
    this.onReorder,
    this.showSeparators = false,
  });

  @override
  State<SettingsGroupWidget> createState() => _SettingsGroupWidgetState();
}

class _SettingsGroupWidgetState extends State<SettingsGroupWidget>
    with SingleTickerProviderStateMixin {
  final AnimationService _animationService = AnimationService();
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  int? _draggingIndex;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: _animationService.adjustDuration(const Duration(milliseconds: 500)),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _handleReset() {
    if (_animationService.shouldAnimate()) {
      _rotationController.forward().then((_) {
        _rotationController.reset();
      });
    }
    HapticFeedback.mediumImpact();
    widget.onReset?.call();
  }

  Widget _buildDraggableItems() {
    final List<SettingsItem> allItems = List.from(widget.group.items)
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorder: (oldIndex, newIndex) {
        HapticFeedback.lightImpact();
        widget.onReorder?.call(oldIndex, newIndex);
      },
      onReorderStart: (index) {
        setState(() {
          _draggingIndex = index;
        });
      },
      onReorderEnd: (index) {
        setState(() {
          _draggingIndex = null;
        });
      },
      itemCount: allItems.length,
      buildDefaultDragHandles: false, 
      proxyDecorator: (Widget child, int index, Animation<double> animation) {
        final item = allItems[index];

        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? child) {
            return Material(
              elevation: 8.0,
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(29, 29, 29, 1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  margin: EdgeInsets.symmetric(vertical: 2.h),
                  child: Row(
                    children: [
                      // Drag handle
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
                      // Title
                      Expanded(
                        child: Text(
                          item.title.toString().toUpperCase(),
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontFamily: 'Lato',
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Switch
                      DefyxSwitch(
                        value: item.isEnabled,
                        onChanged: (value) =>
                            widget.onToggle?.call(widget.group.id, item.id),
                        enabled: item.isAccessible,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final item = allItems[index];

        return Container(
          key: ValueKey(item.id),
          margin: EdgeInsets.symmetric(vertical: 2.h),
          child: SettingsItemWidget(
            key: ValueKey(item.id),
            item: item,
            onToggle: () => widget.onToggle?.call(widget.group.id, item.id),
            isDraggable:
                item.isAccessible,
            isLastItem: index == allItems.length - 1,
            showDragHandle: true,
            dragIndex: index,
            showSeparator: true,
          ),
        );
      },
    );
  }

  Widget _buildStaticItems() {
    final sortedItems = List.from(widget.group.items)
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

    return Column(
      children: sortedItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return SettingsItemWidget(
          key: ValueKey(item.id),
          item: item,
          onToggle: () => widget.onToggle?.call(widget.group.id, item.id),
          isDraggable: false,
          isLastItem: index == sortedItems.length - 1,
          showDragHandle: false,
          showSeparator: widget.showSeparators &&
              _draggingIndex != index, 
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group title
          Padding(
            padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.group.title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[400],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Settings items container with dark background
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.r),
            ),
            padding: EdgeInsets.fromLTRB(2.w, 1.h, 2.w, 1.h),
            child: AnimatedContainer(
              duration: _animationService.adjustDuration(const Duration(milliseconds: 200)),
              child: widget.group.id == 'connection_method'
                  ? _buildDraggableItems()
                  : _buildStaticItems(),
            ),
          ),

          // Reset button for connection method
          if (widget.group.id == 'connection_method' && widget.onReset != null)
            Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _handleReset,
                    child: Row(
                      children: [
                        AnimatedBuilder(
                          animation: _rotationAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationAnimation.value * 2 * 3.14159,
                              child: Icon(
                                Icons.refresh,
                                color: const Color(0xFFFF9A9A),
                                size: 16.sp,
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'RESET TO DEFAULT',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontFamily: 'Lato',
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFF9A9A),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
