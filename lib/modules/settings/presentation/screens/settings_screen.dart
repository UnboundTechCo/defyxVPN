import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_donate_widget.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_premium_widget.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/layout/main_screen_background.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../constants/settings_constants.dart';
import '../../providers/settings_provider.dart';
import '../widgets/settings_group_widget.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final ScrollController _scrollController;
  late final ScrollController _horizontalSliderScrollController;
  final GlobalKey _premiumWidgetKey = GlobalKey();
  final GlobalKey _donateWidgetKey = GlobalKey();
  bool _isMiddleMouseScrolling = false;
  Offset _middleMouseStartPosition = Offset.zero;
  bool _hasAppliedLocalization = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _horizontalSliderScrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Apply localization once when context is available
    if (!_hasAppliedLocalization && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(settingsProvider.notifier).applyLocalization(context);
          _hasAppliedLocalization = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _horizontalSliderScrollController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    // Middle mouse button (button index 4 or kMiddleMouseButton)
    if (event.buttons == kMiddleMouseButton) {
      setState(() {
        _isMiddleMouseScrolling = true;
        _middleMouseStartPosition = event.position;
      });
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isMiddleMouseScrolling) {
      setState(() {
        _isMiddleMouseScrolling = false;
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isMiddleMouseScrolling) {
      final double deltaY = event.position.dy - _middleMouseStartPosition.dy;
      final double targetOffset = _scrollController.offset + deltaY * 0.1;

      _scrollController.animateTo(
        targetOffset.clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 50),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);

    return MainScreenBackground(
      connectionStatus: connectionState.status,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: double.infinity,
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerUp: _onPointerUp,
                onPointerMove: _onPointerMove,
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: false,
                  thickness: 6.0,
                  radius: const Radius.circular(8.0),
                  interactive: true,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.stylus,
                        PointerDeviceKind.trackpad,
                      },
                    ),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(height: 45.h),
                              _buildHeaderSection(),
                              SizedBox(height: 30.h),
                              _buildSliderSection(),
                              SizedBox(height: 30.h),
                              _buildSettingsContent(ref, context),
                              SizedBox(height: 130.h),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'D',
                      style: TextStyle(
                        fontSize: 35.sp,
                        fontFamily: 'Lato',
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFFC927),
                      ),
                    ),
                    TextSpan(
                      text: 'efyx ',
                      style: TextStyle(
                        fontSize: 32.sp,
                        fontFamily: 'Lato',
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFFFFC927),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return Text(
                    l10n.statusIs,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontFamily: 'Lato',
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Text(
              l10n.statusYoursToShape,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 32.sp,
                fontFamily: 'Lato',
                fontWeight: FontWeight.w400,
                color: Colors.white,
                height: 1.1,
              ),
            );
          },
        ),
      ],
    );
  }

  bool _handlePremiumWidgetTap() {
    if (_isWidgetVisibleInHorizontalScroll(_premiumWidgetKey)) {
      return true;
    } else {
      _scrollToShowWidget(_premiumWidgetKey);
      return false;
    }
  }

  bool _handleDonateWidgetTap() {
    if (_isWidgetVisibleInHorizontalScroll(_donateWidgetKey)) {
      return true;
    } else {
      _scrollToShowWidget(_donateWidgetKey);
      return false;
    }
  }

  Widget _buildSliderSection() {
    return Listener(
      onPointerMove: (event) {},
      onPointerSignal: (event) {},
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (notification) {
          return false;
        },
        child: SingleChildScrollView(
          controller: _horizontalSliderScrollController,
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: _premiumWidgetKey,
                  child: SettingsPremiumWidget(
                    ref: ref,
                    shouldExecuteAction: true,
                    onTapBefore: _handlePremiumWidgetTap,
                  ),
                ),
                SizedBox(width: 15.w),
                Container(
                  key: _donateWidgetKey,
                  child: SettingsDonateWidget(
                    ref: ref,
                    shouldExecuteAction: true,
                    onTapBefore: _handleDonateWidgetTap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContent(WidgetRef ref, BuildContext context) {
    final settingsState = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final groups = settingsState.groupList;
    return Column(
      children: groups
          .map(
            (group) => SettingsGroupWidget(
              key: ValueKey(group.id),
              group: group,
              showSeparators: true,
              onToggle: (groupId, itemId) {
                settingsNotifier.toggleSetting(groupId, itemId, context);
              },
              onReorder: group.isDraggable
                  ? (oldIndex, newIndex) {
                      settingsNotifier.reorderItems(
                        group.id,
                        oldIndex,
                        newIndex,
                      );
                    }
                  : null,
              onReset: group.id == SettingsGroupId.connectionMethod
                  ? () {
                      settingsNotifier.resetGroupToDefault(
                        group.id,
                        context: context,
                      );
                    }
                  : null,
              onNavigate: (route) {
                Navigator.pushNamed(context, route);
              },
            ),
          )
          .toList(),
    );
  }
}
