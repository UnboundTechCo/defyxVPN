import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/main_screen_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../providers/settings_provider.dart';
import '../widgets/settings_group_widget.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionStateProvider);

    return MainScreenBackground(
      connectionStatus: connectionState.status,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 393.w),
            child: Padding(padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 45.h),
                _buildHeaderSection(),
                SizedBox(height: 60.h),
                _buildSettingsContent(ref),
              ],
            ),)
          ),
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

  Widget _buildSettingsContent(WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Column(
      children: settings
          .map((group) => SettingsGroupWidget(
                key: ValueKey(group.id),
                group: group,
                showSeparators: group.id == 'connection_method',
                onToggle: (groupId, itemId) {
                  settingsNotifier.toggleSetting(groupId, itemId);
                },
                onReorder: group.id == 'connection_method'
                    ? (oldIndex, newIndex) {
                        settingsNotifier.reorderConnectionMethodItems(
                            oldIndex, newIndex);
                      }
                    : null,
                onReset: group.id == 'connection_method'
                    ? () {
                        settingsNotifier.resetConnectionMethodToDefault();
                      }
                    : null,
              ))
          .toList(),
    );
  }
}
