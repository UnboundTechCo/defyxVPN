import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/shared/layout/main_screen_background.dart';
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
  final double _scrollSpeedFactor = 0.35;
  final double _touchScrollSpeedFactor = 0.5;
  double _lastTouchPosition = 0;
  bool _isMiddleMouseScrolling = false;
  Offset _middleMouseStartPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final double scrollDelta = event.scrollDelta.dy * _scrollSpeedFactor;
      final double newOffset = _scrollController.offset + scrollDelta;
      _scrollController.jumpTo(
        newOffset.clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        ),
      );
    }
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

  void _onVerticalDragStart(DragStartDetails details) {
    _lastTouchPosition = details.globalPosition.dy;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final double delta = (_lastTouchPosition - details.globalPosition.dy) *
        _touchScrollSpeedFactor;
    _lastTouchPosition = details.globalPosition.dy;

    final double newOffset = _scrollController.offset + delta;
    _scrollController.jumpTo(
      newOffset.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      ),
    );
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
              child: GestureDetector(
                onVerticalDragStart: _onVerticalDragStart,
                onVerticalDragUpdate: _onVerticalDragUpdate,
                child: Listener(
                  onPointerSignal: _handlePointerSignal,
                  onPointerDown: _onPointerDown,
                  onPointerUp: _onPointerUp,
                  onPointerMove: _onPointerMove,
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: false,
                    thickness: 6.0,
                    radius: const Radius.circular(8.0),
                    interactive: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(height: 45.h),
                              _buildHeaderSection(),
                              SizedBox(height: 60.h),
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
          children: [
            Text(
              'D',
              style: TextStyle(
                fontSize: 35.sp,
                fontFamily: 'Lato',
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFFC927),
              ),
            ),
            Text(
              'efyx ',
              style: TextStyle(
                fontSize: 32.sp,
                fontFamily: 'Lato',
                fontWeight: FontWeight.w400,
                color: const Color(0xFFFFC927),
              ),
            ),
            Text(
              'is',
              style: TextStyle(
                fontSize: 32.sp,
                fontFamily: 'Lato',
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Text(
          'yours to shape',
          style: TextStyle(
            fontSize: 32.sp,
            fontFamily: 'Lato',
            fontWeight: FontWeight.w400,
            color: Colors.white,
            height: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsContent(WidgetRef ref, BuildContext context) {
    final settingsState = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final groups = settingsState.value?.groupList ?? [];

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
                          group.id, oldIndex, newIndex);
                    }
                  : null,
              onReset: group.id == SettingsGroupId.connectionMethod
                  ? () {
                      settingsNotifier.resetGroupToDefault(group.id);
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
