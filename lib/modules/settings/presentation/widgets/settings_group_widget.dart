import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/offline_flowline_widget.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/sync_menu_dropdown.dart';
import 'package:defyx_vpn/shared/providers/flow_line_provider.dart';
import 'package:defyx_vpn/shared/services/animation_service.dart';
import 'package:defyx_vpn/shared/tv/tv_support.dart';
import 'package:defyx_vpn/shared/widgets/tv_focusable.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/settings_group.dart';
import '../../models/settings_item.dart';
import 'settings_item_widget.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../shared/widgets/defyx_switch.dart';
import '../../../../shared/providers/haptics_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsGroupWidget extends ConsumerStatefulWidget {
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
  ConsumerState<SettingsGroupWidget> createState() =>
      _SettingsGroupWidgetState();
}

class _SettingsGroupWidgetState extends ConsumerState<SettingsGroupWidget>
    with SingleTickerProviderStateMixin {
  final AnimationService _animationService = AnimationService();
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  int? _draggingIndex;

  // D-pad support. Rows of a reorderable list are rebuilt when they move, so
  // the group owns their focus nodes to keep focus on a moving row.
  final Map<String, FocusNode> _itemFocusNodes = {};
  late FocusHighlightMode _highlightMode;
  String? _focusedItemId;
  String? _movingItemId;
  bool _moveInFlight = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: _animationService.adjustDuration(
        const Duration(milliseconds: 500),
      ),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );
    _highlightMode = FocusManager.instance.highlightMode;
    FocusManager.instance.addHighlightModeListener(_handleHighlightModeChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(
      _handleHighlightModeChange,
    );
    for (final node in _itemFocusNodes.values) {
      node.dispose();
    }
    _rotationController.dispose();
    super.dispose();
  }

  void _handleReset() {
    if (_animationService.shouldAnimate()) {
      _rotationController.forward().then((_) {
        _rotationController.reset();
      });
    }
    if (ref.read(hapticsProvider)) {
      HapticFeedback.mediumImpact();
    }
    widget.onReset?.call();
  }

  void _handleHighlightModeChange(FocusHighlightMode mode) {
    if (!mounted || mode == _highlightMode) return;
    setState(() => _highlightMode = mode);
  }

  FocusNode _focusNodeFor(String itemId) => _itemFocusNodes.putIfAbsent(
    itemId,
    () => FocusNode(debugLabel: 'SettingsItem($itemId)'),
  );

  void _handleItemFocusChange(String itemId, bool hasFocus) {
    if (hasFocus) {
      if (_focusedItemId != itemId) setState(() => _focusedItemId = itemId);
    } else if (_focusedItemId == itemId) {
      setState(() {
        _focusedItemId = null;
        // Focus left the row being moved (e.g. a dialog opened).
        if (_movingItemId == itemId) _movingItemId = null;
      });
    }
  }

  void _startMove(SettingsItem item) {
    if (ref.read(hapticsProvider)) {
      HapticFeedback.mediumImpact();
    }
    setState(() => _movingItemId = item.id);
  }

  void _endMove() {
    if (_movingItemId == null) return;
    setState(() => _movingItemId = null);
  }

  Future<bool> _handleBackButton() async {
    if (_movingItemId == null) return false;
    _endMove();
    return true;
  }

  /// Moves [itemId] one position up (-1) or down (+1) with the D-pad.
  void _moveItem(String itemId, int delta, List<SettingsItem> draggableItems) {
    // One move per frame: the index math needs the list rebuilt from the
    // previous move first (holding Up/Down repeats the key quickly).
    if (_moveInFlight) return;
    final from = draggableItems.indexWhere((item) => item.id == itemId);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= draggableItems.length) return;

    if (ref.read(hapticsProvider)) {
      HapticFeedback.selectionClick();
    }
    _moveInFlight = true;
    // ReorderableListView index semantics: newIndex counts the moved item.
    widget.onReorder?.call(from, delta > 0 ? to + 1 : to);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveInFlight = false;
      final node = _itemFocusNodes[itemId];
      if (!mounted || node == null) return;
      node.requestFocus();
      final rowContext = node.context;
      if (rowContext != null && rowContext.mounted) {
        Scrollable.ensureVisible(
          rowContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Widget _buildDraggableItems() {
    final draggableItems =
        widget.group.items
            .where((item) => item.itemType != SettingsItemType.navigation)
            .toList()
          ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

    final navigationItems = widget.group.items
        .where((item) => item.itemType == SettingsItemType.navigation)
        .toList();

    final canReorder = widget.onReorder != null;
    final l10n = AppLocalizations.of(context);

    Widget buildRow(int index, Key key) {
      final item = draggableItems[index];
      final isLastDraggable = index == draggableItems.length - 1;
      final isMoving = _movingItemId == item.id;
      // D-pad users see how to reorder right in the focused row.
      final showReorderHint =
          _highlightMode == FocusHighlightMode.traditional &&
          _focusedItemId == item.id &&
          canReorder &&
          item.isAccessible;

      return SettingsItemWidget(
        key: key,
        item: item,
        onToggle: () => widget.onToggle?.call(widget.group.id, item.id),
        onNavigate: widget.onNavigate,
        isDraggable: item.isAccessible,
        isLastItem: isLastDraggable && navigationItems.isEmpty,
        showDragHandle: true,
        dragIndex: index,
        showSeparator: true,
        focusNode: _focusNodeFor(item.id),
        onFocusChange: (hasFocus) => _handleItemFocusChange(item.id, hasFocus),
        onSelectLongPress: canReorder && item.isAccessible
            ? () => _startMove(item)
            : null,
        isMoving: isMoving,
        onMove: (delta) => _moveItem(item.id, delta, draggableItems),
        onMoveEnd: _endMove,
        dpadHint: showReorderHint
            ? (isMoving ? l10n.tvMoveModeHint : l10n.tvHoldOkToReorder)
            : null,
      );
    }

    return Column(
      children: [
        // On TV the rows go straight into the page's scroll view. A
        // ReorderableListView is a scrollable of its own, and Flutter's
        // directional focus prefers targets in the focused widget's scrollable,
        // so D-pad focus entering from above or below would skip the whole
        // list. TVs reorder with the D-pad move mode, not by dragging.
        if (TvSupport.isTv)
          for (var index = 0; index < draggableItems.length; index++)
            buildRow(
              index,
              ValueKey('${widget.group.id}_${draggableItems[index].id}'),
            )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) {
              if (ref.read(hapticsProvider)) {
                HapticFeedback.lightImpact();
              }
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
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 8.h,
                            ),
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
                                      fontFamily: AppTheme.fontFamily,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                DefyxSwitch(
                                  value: item.isEnabled,
                                  onChanged: (value) => widget.onToggle?.call(
                                    widget.group.id,
                                    item.id,
                                  ),
                                  enabled: item.isAccessible,
                                  focusable: false,
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
            itemBuilder: (context, index) => buildRow(
              index,
              ValueKey('${widget.group.id}_${draggableItems[index].id}_$index'),
            ),
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
            onFocusChange: (hasFocus) =>
                _handleItemFocusChange(item.id, hasFocus),
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

  /// D-pad-only: the focused method's description under the list (touch
  /// users get it from the row's info icon, which isn't a focus stop).
  Widget _buildFocusedDescription() {
    final focusedItem = _focusedItemId == null
        ? null
        : widget.group.items
              .where((item) => item.id == _focusedItemId)
              .firstOrNull;
    final description = focusedItem?.description;
    final visible =
        _highlightMode == FocusHighlightMode.traditional &&
        focusedItem != null &&
        focusedItem.itemType != SettingsItemType.navigation &&
        description != null &&
        description.isNotEmpty;

    return AnimatedSize(
      duration: _animationService.adjustDuration(
        const Duration(milliseconds: 200),
      ),
      alignment: Alignment.topCenter,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: EdgeInsets.only(top: 10.h, left: 4.w, right: 4.w),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontFamily: AppTheme.fontFamily,
                  color: Colors.grey[300],
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flowlineData = ref.watch(flowLineProvider);
    final content = Container(
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
                    fontFamily: AppTheme.fontFamily,
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
              duration: _animationService.adjustDuration(
                const Duration(milliseconds: 200),
              ),
              child: widget.group.isDraggable
                  ? _buildDraggableItems()
                  : _buildStaticItems(),
            ),
          ),

          if (widget.group.isDraggable) _buildFocusedDescription(),

          // Reset button for connection method
          if (widget.group.isDraggable && widget.onReset != null)
            Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SyncMenuDropdown(),
                      Spacer(),
                      TvFocusable(
                        onTap: _handleReset,
                        borderRadius: BorderRadius.circular(6.r),
                        ringOutset: 4,
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
                              AppLocalizations.of(
                                context,
                              ).settingsResetToDefault,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontFamily: AppTheme.fontFamily,
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
                  if (flowlineData.mode.isNotEmpty &&
                      flowlineData.mode != "online")
                    Padding(
                      padding: EdgeInsets.only(top: 12.h),
                      child: OfflineFlowlineWidget(),
                    ),
                ],
              ),
            ),
        ],
      ),
    );

    // Back ends the D-pad move mode instead of leaving the screen.
    if (Router.maybeOf(context) == null) return content;
    return BackButtonListener(
      onBackButtonPressed: _handleBackButton,
      child: content,
    );
  }
}
