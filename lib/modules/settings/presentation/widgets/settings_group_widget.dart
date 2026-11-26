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
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/country_names.dart';
import '../../models/method_sections.dart';
import '../../models/settings_group.dart';
import '../../models/settings_item.dart';
import 'marketplace_info_sheet.dart';
import 'method_section_widgets.dart';
import 'settings_item_widget.dart';
import 'settings_toast_message.dart';
import '../../../../shared/providers/haptics_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Moves `blocks[oldIndex]` so it ends up at [newIndex]. [blocks] holds the
/// item ids of each block in the list being reordered.
typedef BlockReorderCallback =
    void Function(List<List<String>> blocks, int oldIndex, int newIndex);

class SettingsGroupWidget extends ConsumerStatefulWidget {
  final SettingsGroup group;
  final Function(String, String)? onToggle;
  final VoidCallback? onReset;
  final BlockReorderCallback? onReorderBlocks;
  final ValueChanged<String>? onTogglePlan;

  /// Called when the user opens or closes a section or plan, by its key.
  final void Function(String key, bool expanded)? onExpandedChange;
  final Function(String)? onNavigate;
  final bool showSeparators;

  const SettingsGroupWidget({
    super.key,
    required this.group,
    this.onToggle,
    this.onReset,
    this.onReorderBlocks,
    this.onTogglePlan,
    this.onExpandedChange,
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

  // D-pad support. Rows of a reorderable list are rebuilt when they move, so
  // the group owns their focus nodes to keep focus on a moving row. Keys are
  // item ids, or the layout keys of section and plan headers.
  final Map<String, FocusNode> _focusNodes = {};
  late FocusHighlightMode _highlightMode;
  String? _focusedKey;
  String? _movingKey;
  bool _moveInFlight = false;

  /// Opened and closed sections and plans, shown before the saved group
  /// catches up.
  final Map<String, bool> _expanded = {};

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
    for (final node in _focusNodes.values) {
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

  FocusNode _focusNodeFor(String key) => _focusNodes.putIfAbsent(
    key,
    () => FocusNode(debugLabel: 'SettingsItem($key)'),
  );

  void _handleFocusChange(String key, bool hasFocus) {
    if (hasFocus) {
      if (_focusedKey != key) setState(() => _focusedKey = key);
    } else if (_focusedKey == key) {
      setState(() {
        _focusedKey = null;
        // Focus left the row being moved (e.g. a dialog opened).
        if (_movingKey == key) _movingKey = null;
      });
    }
  }

  bool _isExpanded(String key, {required bool byDefault}) =>
      _expanded[key] ?? widget.group.expanded[key] ?? byDefault;

  void _setExpanded(String key, bool expanded) {
    if (ref.read(hapticsProvider)) {
      HapticFeedback.selectionClick();
    }
    setState(() => _expanded[key] = expanded);
    widget.onExpandedChange?.call(key, expanded);
  }

  void _startMove(String key) {
    if (ref.read(hapticsProvider)) {
      HapticFeedback.mediumImpact();
    }
    setState(() => _movingKey = key);
  }

  void _endMove() {
    if (_movingKey == null) return;
    setState(() => _movingKey = null);
  }

  Future<bool> _handleBackButton() async {
    if (_movingKey == null) return false;
    _endMove();
    return true;
  }

  /// Moves the block [key] one position up (-1) or down (+1) with the D-pad,
  /// within the list whose block keys are [keys].
  void _moveBlock(
    String key,
    int delta,
    List<String> keys,
    List<List<String>> blocks,
  ) {
    // One move per frame: the index math needs the list rebuilt from the
    // previous move first (holding Up/Down repeats the key quickly).
    if (_moveInFlight) return;
    final from = keys.indexOf(key);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= keys.length) return;

    if (ref.read(hapticsProvider)) {
      HapticFeedback.selectionClick();
    }
    _moveInFlight = true;
    widget.onReorderBlocks?.call(blocks, from, to);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveInFlight = false;
      final node = _focusNodes[key];
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

  String? _dpadHint(String key, {required bool canMove}) {
    if (_highlightMode != FocusHighlightMode.traditional ||
        _focusedKey != key ||
        !canMove ||
        widget.onReorderBlocks == null) {
      return null;
    }
    final l10n = AppLocalizations.of(context);
    return _movingKey == key ? l10n.tvMoveModeHint : l10n.tvHoldOkToReorder;
  }

  /// A list the user can reorder: by dragging on touch screens, and with the
  /// D-pad move mode on TV.
  Widget _reorderableList({
    required List<String> keys,
    required List<List<String>> blocks,
    required Widget Function(int index) buildRow,
  }) {
    Widget keyed(int index) => KeyedSubtree(
      key: ValueKey('${widget.group.id}_${keys[index]}'),
      child: buildRow(index),
    );

    // On TV the rows go straight into the page's scroll view. A
    // ReorderableListView is a scrollable of its own, and Flutter's
    // directional focus prefers targets in the focused widget's scrollable,
    // so D-pad focus entering from above or below would skip the whole list.
    // TVs reorder with the D-pad move mode, not by dragging.
    if (TvSupport.isTv) {
      return Column(children: [for (var i = 0; i < keys.length; i++) keyed(i)]);
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: keys.length,
      onReorderItem: (oldIndex, newIndex) {
        if (ref.read(hapticsProvider)) {
          HapticFeedback.lightImpact();
        }
        widget.onReorderBlocks?.call(blocks, oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) => Material(
        elevation: 8.0,
        color: const Color.fromRGBO(29, 29, 29, 1),
        borderRadius: BorderRadius.circular(12.r),
        child: child,
      ),
      itemBuilder: (context, index) => keyed(index),
    );
  }

  /// Opens or closes [child] with a short size animation.
  Widget _collapsible({required bool expanded, required Widget child}) {
    return AnimatedSize(
      duration: _animationService.adjustDuration(
        const Duration(milliseconds: 200),
      ),
      alignment: Alignment.topCenter,
      child: expanded ? child : const SizedBox(width: double.infinity),
    );
  }

  String _sectionTitle(MethodSection section, AppLocalizations l10n) =>
      switch (section) {
        MethodSection.premium => l10n.settingsMethodsPremium,
        MethodSection.market => l10n.settingsMethodsMarket,
        MethodSection.builtIn => l10n.settingsMethodsBuiltIn,
        MethodSection.rewards => l10n.settingsMethodsRewards,
      };

  /// Seller or features, then days left.
  String? _caption(SettingsItem item, DateTime now, AppLocalizations l10n) {
    final parts = <String>[];
    if (item.seller != null) {
      parts.add(l10n.settingsMethodsBySeller(_isolate(item.seller!)));
    } else {
      parts.addAll(item.features);
    }
    final ends = item.expiresAt;
    if (ends != null) {
      if (!ends.isAfter(now)) {
        parts.add(l10n.settingsMethodsExpired);
      } else {
        final days = (ends.difference(now).inMinutes / 1440).round();
        parts.add(l10n.settingsMethodsDaysLeft(days < 1 ? 1 : days));
      }
    }
    // Each part keeps its own direction, so Latin names and Persian text
    // don't get reordered into each other.
    return parts.isEmpty ? null : parts.map(_isolate).join(' · ');
  }

  /// [text] wrapped in a Unicode first-strong isolate.
  static String _isolate(String text) => '\u2068$text\u2069';

  /// A plan's SOS method holds every config the user has on one of its
  /// servers, not every location, so it keeps the name users know it by.
  /// The plan's own config shows as its subscription link rather than the
  /// plan's name again. Countries show by their full name.
  String _locationTitle(SettingsItem item, {required bool isMain}) {
    if (item.isSos) return 'SOS';
    if (isMain) return AppLocalizations.of(context).settingsMethodsSubscription;
    final country = item.country;
    if (country == null) return item.title;
    final language = Localizations.localeOf(context).languageCode;
    return CountryNames.of(country, language) ?? country;
  }

  /// A location's flag (the unknown-country flag for ones without), a link
  /// for the plan's own config, or a lifebuoy for the SOS backup, so the
  /// names line up.
  Widget _locationLeading(SettingsItem item, {required bool isMain}) {
    final width = 24.w;
    final height = width * 3 / 4;
    if (item.isSos || isMain) {
      return SizedBox(
        width: width,
        height: height,
        child: Icon(
          item.isSos ? Icons.support : Icons.link,
          size: height,
          color: Colors.grey[400],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(3.r),
      child: SvgPicture.asset(
        CountryNames.flagAsset(item.country ?? ''),
        width: width,
        height: height,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildMethodRow(
    SettingsItem item, {
    required int index,
    required List<String> keys,
    required List<List<String>> blocks,
    required bool isLast,
    required DateTime now,
    String? titleOverride,
    String? caption,
    bool compact = false,
    double indent = 0,
    bool disabled = false,
    Widget? leading,
  }) {
    // An expired method, or one in a plan that's off, isn't used, so its
    // switch shows off and can't be changed.
    final shown = disabled || item.isExpiredAt(now)
        ? item.copyWith(isAccessible: false, isEnabled: false)
        : item;
    final canMove = widget.onReorderBlocks != null && shown.isAccessible;

    return SettingsItemWidget(
      item: shown,
      titleOverride: titleOverride,
      caption: caption,
      compact: compact,
      indent: indent,
      leading: leading,
      onToggle: shown.isAccessible
          ? () => widget.onToggle?.call(widget.group.id, item.id)
          : null,
      onNavigate: widget.onNavigate,
      isDraggable: shown.isAccessible,
      isLastItem: isLast,
      showDragHandle: true,
      dragIndex: index,
      showSeparator: true,
      focusNode: _focusNodeFor(item.id),
      onFocusChange: (hasFocus) => _handleFocusChange(item.id, hasFocus),
      onSelectLongPress: canMove ? () => _startMove(item.id) : null,
      isMoving: _movingKey == item.id,
      onMove: (delta) => _moveBlock(item.id, delta, keys, blocks),
      onMoveEnd: _endMove,
      dpadHint: _dpadHint(item.id, canMove: canMove),
    );
  }

  Widget _buildPlan(
    MethodBlock plan, {
    required int index,
    required List<String> keys,
    required List<List<String>> blocks,
    required bool isLast,
    required bool expandedByDefault,
    required Set<String> disabledPlans,
    required DateTime now,
    required AppLocalizations l10n,
  }) {
    final planId = plan.planId!;
    // The plan's row takes its details from its own config, if it has one,
    // which is also listed under it as the subscription link. The row's
    // switch turns the whole plan on or off.
    final main = plan.main;
    final first = main ?? plan.items.first;
    final expanded = _isExpanded(plan.key, byDefault: expandedByDefault);
    final isOn = !disabledPlans.contains(planId);
    final canMove = widget.onReorderBlocks != null;
    final description = first.description;

    final locations = plan.items;
    final locationKeys = [for (final item in locations) item.id];
    final locationBlocks = [
      for (final id in locationKeys) [id],
    ];

    return Column(
      children: [
        MethodPlanHeader(
          title: first.planName ?? first.title,
          caption: _caption(first, now, l10n),
          isPremium: first.section == MethodSection.premium,
          isMarket: first.section == MethodSection.market,
          onInfo: first.section == MethodSection.premium
              ? () => MarketplaceInfoSheet.show(context, first)
              : description != null && description.isNotEmpty
              ? () => SettingsToastMessage.show(description)
              : null,
          isOn: isOn,
          onToggle: widget.onTogglePlan == null
              ? null
              : () => widget.onTogglePlan!(planId),
          expanded: expanded,
          onTap: () => _setExpanded(plan.key, !expanded),
          dragIndex: index,
          focusNode: _focusNodeFor(plan.key),
          onFocusChange: (hasFocus) => _handleFocusChange(plan.key, hasFocus),
          onSelectLongPress: canMove ? () => _startMove(plan.key) : null,
          isMoving: _movingKey == plan.key,
          onMove: (delta) => _moveBlock(plan.key, delta, keys, blocks),
          onMoveEnd: _endMove,
          dpadHint: _dpadHint(plan.key, canMove: canMove),
          showSeparator: expanded || !isLast,
        ),
        _collapsible(
          expanded: expanded,
          child: _reorderableList(
            keys: locationKeys,
            blocks: locationBlocks,
            buildRow: (i) {
              final location = locations[i];
              return _buildMethodRow(
                location,
                index: i,
                keys: locationKeys,
                blocks: locationBlocks,
                isLast: isLast && i == locations.length - 1,
                now: now,
                titleOverride: _locationTitle(
                  location,
                  isMain: location.id == main?.id,
                ),
                leading: _locationLeading(
                  location,
                  isMain: location.id == main?.id,
                ),
                caption: location.isExpiredAt(now)
                    ? l10n.settingsMethodsExpired
                    : null,
                compact: true,
                indent: 24.w,
                // Off with the plan; back on, each follows its own switch.
                disabled: !isOn,
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSection(
    MethodSectionGroup section, {
    required bool isFirst,
    required bool isOnly,
    required Set<String> disabledPlans,
    required DateTime now,
    required AppLocalizations l10n,
  }) {
    final key = MethodLayout.sectionKey(section.section);
    // The first section starts open. When it's the only one (a user with
    // just the free methods), it opens every time, even if it was closed
    // back when paid sections were above it, so the page never looks empty.
    final expanded = isOnly
        ? _expanded[key] ?? true
        : _isExpanded(key, byDefault: isFirst);
    final items = section.items.toList();
    final active = items
        .where((item) => MethodLayout.isActive(item, disabledPlans, now))
        .length;

    final blocks = section.blocks;
    final keys = [for (final block in blocks) block.key];
    final blockIds = [for (final block in blocks) block.itemIds];
    final onlyPlan = blocks.where((block) => block.isPlan).length == 1;

    return [
      MethodSectionHeader(
        key: ValueKey('${widget.group.id}_$key'),
        title: _sectionTitle(section.section, l10n),
        summary: l10n.settingsMethodsOnCount(active, items.length),
        expanded: expanded,
        showDivider: !isFirst,
        focusNode: _focusNodeFor(key),
        onFocusChange: (hasFocus) => _handleFocusChange(key, hasFocus),
        onTap: () => _setExpanded(key, !expanded),
      ),
      _collapsible(
        expanded: expanded,
        child: _reorderableList(
          keys: keys,
          blocks: blockIds,
          buildRow: (index) {
            final block = blocks[index];
            final isLast = index == blocks.length - 1;
            if (block.isPlan) {
              return _buildPlan(
                block,
                index: index,
                keys: keys,
                blocks: blockIds,
                isLast: isLast,
                expandedByDefault: onlyPlan,
                disabledPlans: disabledPlans,
                now: now,
                l10n: l10n,
              );
            }
            final item = block.items.single;
            return _buildMethodRow(
              item,
              index: index,
              keys: keys,
              blocks: blockIds,
              isLast: isLast,
              now: now,
              caption: _caption(item, now, l10n),
            );
          },
        ),
      ),
    ];
  }

  Widget _buildDraggableItems() {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final disabledPlans = widget.group.disabledPlans.toSet();
    // Sections without methods are left out.
    final sections = MethodLayout.sections(
      widget.group.items.where(
        (item) => item.itemType != SettingsItemType.navigation,
      ),
    );
    final navigationItems = widget.group.items
        .where((item) => item.itemType == SettingsItemType.navigation)
        .toList();

    return Column(
      children: [
        for (var i = 0; i < sections.length; i++)
          ..._buildSection(
            sections[i],
            isFirst: i == 0,
            isOnly: sections.length == 1,
            disabledPlans: disabledPlans,
            now: now,
            l10n: l10n,
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
            onFocusChange: (hasFocus) => _handleFocusChange(item.id, hasFocus),
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
          showSeparator: widget.showSeparators,
        );
      }).toList(),
    );
  }

  /// D-pad-only: the focused method's description under the list (touch
  /// users get it from the row's info icon, which isn't a focus stop).
  Widget _buildFocusedDescription() {
    final key = _focusedKey;
    final focusedItem = key == null
        ? null
        : widget.group.items.where((item) => item.id == key).firstOrNull ??
              widget.group.items
                  .where(
                    (item) =>
                        item.planId != null &&
                        MethodLayout.planKey(item.planId!) == key,
                  )
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
            padding: EdgeInsetsDirectional.only(bottom: 12.h, start: 4.w),
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
