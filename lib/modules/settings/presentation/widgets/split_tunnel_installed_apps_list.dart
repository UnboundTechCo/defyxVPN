import 'dart:typed_data';

import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/shared/widgets/defyx_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/installed_app.dart';
import '../../providers/split_tunnel_provider.dart';
import 'split_tunnel_list_card.dart';

class SplitTunnelInstalledAppsList extends ConsumerWidget {
  final String query;

  const SplitTunnelInstalledAppsList({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installedApps = ref.watch(installedAppsProvider);
    final selected = ref.watch(splitTunnelProvider.select((c) => c.apps));
    final notifier = ref.read(splitTunnelProvider.notifier);

    return installedApps.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => const _EmptyMessage(),
      data: (apps) {
        final needle = query.trim().toLowerCase();
        final visibleApps = needle.isEmpty
            ? apps
            : apps
                  .where(
                    (a) =>
                        a.name.toLowerCase().contains(needle) ||
                        a.packageName.toLowerCase().contains(needle),
                  )
                  .toList();

        if (visibleApps.isEmpty) return const _EmptyMessage();

        return SplitTunnelListCard(
          itemCount: visibleApps.length,
          itemBuilder: (context, index) {
            final app = visibleApps[index];
            return _InstalledAppTile(
              key: ValueKey(app.packageName),
              app: app,
              isEnabled: selected.contains(app.packageName),
              onToggle: () => notifier.toggleApp(app.packageName),
            );
          },
        );
      },
    );
  }
}

class _InstalledAppTile extends StatelessWidget {
  final InstalledApp app;
  final bool isEnabled;
  final VoidCallback onToggle;

  const _InstalledAppTile({
    super.key,
    required this.app,
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Row(
          children: [
            _AppIcon(icon: app.icon, svg: app.iconSvg),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                app.name,
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
            DefyxSwitch(value: isEnabled, onChanged: (_) => onToggle()),
          ],
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final Uint8List? icon;
  final Uint8List? svg;

  const _AppIcon({required this.icon, this.svg});

  @override
  Widget build(BuildContext context) {
    final size = 30.r;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: icon != null
          ? Image.memory(
              icon!,
              width: size,
              height: size,
              cacheWidth: 96,
              gaplessPlayback: true,
            )
          : svg != null
          ? SvgPicture.memory(svg!, width: size, height: size)
          : Icon(Icons.apps, size: size, color: Colors.grey[400]),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32.h),
        child: Center(
          child: Text(
            AppLocalizations.of(context).splitTunnelNoApps,
            style: TextStyle(
              fontSize: 15.sp,
              fontFamily: AppTheme.fontFamily,
              color: Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }
}
