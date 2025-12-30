import 'package:defyx_vpn/shared/services/animation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/settings_group.dart';
import '../../models/settings_item.dart';
import 'settings_item_widget.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../shared/widgets/defyx_switch.dart';

class SettingsGroupWidget extends StatefulWidget {
  final SettingsGroup group;
  final Function(String, String)? onToggle;
  final VoidCallback? onReset;
  final ReorderCallback? onReorder;
  final Function(String)? onNavigate;
  final bool showSeparators;

  const SettingsGroupWidget({
    super.key,
    required this.group,
    this.onToggle,
    this.onReset,
    this.onReorder,
    this.onNavigate,
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
      duration:
          _animationService.adjustDuration(const Duration(milliseconds: 500)),
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
    final draggableItems = widget.group.items
        .where((item) => item.itemType != SettingsItemType.navigation)
        .toList()
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

    final navigationItems = widget.group.items
        .where((item) => item.itemType == SettingsItemType.navigation)
        .toList();

    return Column(
      children: [
        ReorderableListView.builder(
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
          itemCount: draggableItems.length,
          buildDefaultDragHandles: false,
          proxyDecorator:
              (Widget child, int index, Animation<double> animation) {
            final item = draggableItems[index];

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
            final item = draggableItems[index];
            final isLastDraggable = index == draggableItems.length - 1;

            return SettingsItemWidget(
              key: ValueKey('${widget.group.id}_${item.id}_$index'),
              item: item,
              onToggle: () => widget.onToggle?.call(widget.group.id, item.id),
              onNavigate: widget.onNavigate,
              isDraggable: item.isAccessible,
              isLastItem: isLastDraggable && navigationItems.isEmpty,
              showDragHandle: true,
              dragIndex: index,
              showSeparator: true,
            );
          },
        ),
        ...navigationItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return SettingsItemWidget(
            key: ValueKey('${widget.group.id}_nav_${item.id}'),
            item: item,
            onToggle: () {},
            onNavigate: widget.onNavigate,
            isDraggable: false,
            isLastItem: index == navigationItems.length - 1,
            showDragHandle: false,
            showSeparator: index < navigationItems.length - 1,
          );
        }),
      ],
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
          key: ValueKey('${widget.group.id}_${item.id}_$index'),
          item: item,
          onToggle: () => widget.onToggle?.call(widget.group.id, item.id),
          onNavigate: widget.onNavigate,
          isDraggable: false,
          isLastItem: index == sortedItems.length - 1,
          showDragHandle: false,
          showSeparator: widget.showSeparators && _draggingIndex != index,
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
              duration: _animationService
                  .adjustDuration(const Duration(milliseconds: 200)),
              child: widget.group.isDraggable
                  ? _buildDraggableItems()
                  : _buildStaticItems(),
            ),
          ),

          // Reset button for connection method
          if (widget.group.isDraggable && widget.onReset != null)
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
