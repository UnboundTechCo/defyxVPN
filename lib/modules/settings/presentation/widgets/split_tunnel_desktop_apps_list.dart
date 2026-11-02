import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../providers/split_tunnel_provider.dart';
import 'split_tunnel_add_row.dart';
import 'split_tunnel_entry_row.dart';
import 'split_tunnel_list_card.dart';
import 'split_tunnel_type_chip.dart';

const String _appPrefix = 'app';
const Color _browseIconColor = Color(0xFFFFC927);

enum _BrowseTarget { file, folder }

class SplitTunnelDesktopAppsList extends ConsumerWidget {
  final String query;

  const SplitTunnelDesktopAppsList({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(splitTunnelProvider.select((c) => c.apps));
    final needle = query.trim().toLowerCase();
    final visibleApps = needle.isEmpty
        ? apps
        : apps.where((a) => a.toLowerCase().contains(needle)).toList();
    final notifier = ref.read(splitTunnelProvider.notifier);

    return SplitTunnelListCard(
      itemCount: visibleApps.length,
      itemBuilder: (context, index) {
        final app = visibleApps[index];
        return SplitTunnelEntryRow(
          key: ValueKey(app),
          label: '$_appPrefix:$app',
          onRemove: () => notifier.removeApp(app),
        );
      },
      footer: SplitTunnelAddRow(
        typeSelector: const SplitTunnelTypeChip(value: _appPrefix),
        hint: AppLocalizations.of(context).splitTunnelAppHint,
        onSubmit: notifier.addApp,
        actions: [_BrowseButton(onPicked: notifier.addApp)],
      ),
    );
  }
}

class _BrowseButton extends StatelessWidget {
  final Future<bool> Function(String path) onPicked;

  const _BrowseButton({required this.onPicked});

  Future<void> _browse(_BrowseTarget target) async {
    final String? path = switch (target) {
      _BrowseTarget.file => (await FilePicker.pickFile())?.path,
      _BrowseTarget.folder => await FilePicker.getDirectoryPath(),
    };
    if (path != null) await onPicked(path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_BrowseTarget>(
      tooltip: '',
      padding: EdgeInsets.zero,
      color: const Color(0xFF1D1D1D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      onSelected: _browse,
      itemBuilder: (context) => [
        _menuItem(_BrowseTarget.file, l10n.splitTunnelBrowseFile),
        _menuItem(_BrowseTarget.folder, l10n.splitTunnelBrowseFolder),
      ],
      child: Padding(
        padding: EdgeInsets.all(4.r),
        child: Icon(
          Icons.folder_open_outlined,
          size: 26.sp,
          color: _browseIconColor,
        ),
      ),
    );
  }

  PopupMenuItem<_BrowseTarget> _menuItem(_BrowseTarget value, String label) {
    return PopupMenuItem<_BrowseTarget>(
      value: value,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 17.sp,
          fontFamily: AppTheme.fontFamily,
          color: Colors.white,
        ),
      ),
    );
  }
}
