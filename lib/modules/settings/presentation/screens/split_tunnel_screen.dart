import 'dart:io';

import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/shared/layout/main_screen_background.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../providers/split_tunnel_provider.dart';
import '../widgets/split_tunnel_addresses_tab.dart';
import '../widgets/split_tunnel_desktop_apps_list.dart';
import '../widgets/split_tunnel_installed_apps_list.dart';
import '../widgets/split_tunnel_mode_selector.dart';
import '../widgets/split_tunnel_search_field.dart';
import '../widgets/split_tunnel_tab_bar.dart';

const Color _accentColor = Color(0xFFFFC927);

class SplitTunnelScreen extends ConsumerStatefulWidget {
  const SplitTunnelScreen({super.key});

  @override
  ConsumerState<SplitTunnelScreen> createState() => _SplitTunnelScreenState();
}

class _SplitTunnelScreenState extends ConsumerState<SplitTunnelScreen> {
  SplitTunnelTab _tab = SplitTunnelTab.addresses;
  String _query = '';

  bool get _listsInstalledApps => Platform.isAndroid || Platform.isIOS;

  void _selectTab(SplitTunnelTab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _query = '';
    });
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(DefyxVPNRoutes.settings.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final mode = ref.watch(splitTunnelProvider.select((c) => c.mode));
    final l10n = AppLocalizations.of(context);

    return MainScreenBackground(
      connectionStatus: connectionState.status,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 45.h),
                        _buildHeader(l10n),
                        SizedBox(height: 30.h),
                        _buildSectionTitle(l10n.settingsSplitTunnel),
                        SplitTunnelModeSelector(
                          selected: mode,
                          onChanged: ref
                              .read(splitTunnelProvider.notifier)
                              .setMode,
                        ),
                        SizedBox(height: 24.h),
                        SplitTunnelTabBar(
                          selected: _tab,
                          onChanged: _selectTab,
                        ),
                        SizedBox(height: 16.h),
                        SplitTunnelSearchField(
                          key: ValueKey(_tab),
                          onChanged: (value) => setState(() => _query = value),
                        ),
                        SizedBox(height: 16.h),
                      ],
                    ),
                  ),
                  _buildTabContent(),
                  SliverToBoxAdapter(child: SizedBox(height: 130.h)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _goBack,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: EdgeInsets.all(4.r),
            child: Icon(Icons.chevron_left, size: 36.sp, color: _accentColor),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          l10n.splitTunnelPreferences,
          style: TextStyle(
            fontSize: AppTheme.statusHeadlineFontSize.sp,
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13.sp,
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w400,
          color: Colors.grey[400],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case SplitTunnelTab.addresses:
        return SplitTunnelAddressesTab(query: _query);
      case SplitTunnelTab.apps:
        return _listsInstalledApps
            ? SplitTunnelInstalledAppsList(query: _query)
            : SplitTunnelDesktopAppsList(query: _query);
    }
  }
}
