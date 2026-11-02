import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/split_tunnel_config.dart';
import '../../providers/split_tunnel_provider.dart';
import 'split_tunnel_add_row.dart';
import 'split_tunnel_entry_row.dart';
import 'split_tunnel_list_card.dart';
import 'split_tunnel_type_chip.dart';

class SplitTunnelAddressesTab extends ConsumerStatefulWidget {
  final String query;

  const SplitTunnelAddressesTab({super.key, required this.query});

  @override
  ConsumerState<SplitTunnelAddressesTab> createState() =>
      _SplitTunnelAddressesTabState();
}

class _SplitTunnelAddressesTabState
    extends ConsumerState<SplitTunnelAddressesTab> {
  SplitTunnelRuleType _type = SplitTunnelRuleType.geoip;

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(splitTunnelProvider.select((c) => c.rules));
    final query = widget.query.trim().toLowerCase();
    final visibleRules = query.isEmpty
        ? rules
        : rules.where((r) => r.label.toLowerCase().contains(query)).toList();
    final notifier = ref.read(splitTunnelProvider.notifier);

    return SplitTunnelListCard(
      itemCount: visibleRules.length,
      itemBuilder: (context, index) {
        final rule = visibleRules[index];
        return SplitTunnelEntryRow(
          key: ValueKey(rule.label),
          label: rule.label,
          onRemove: () => notifier.removeRule(rule),
        );
      },
      footer: SplitTunnelAddRow(
        typeSelector: SplitTunnelTypeChip(
          value: _type.name,
          options: [for (final t in SplitTunnelRuleType.values) t.name],
          onSelected: (name) =>
              setState(() => _type = SplitTunnelRuleType.fromName(name)!),
        ),
        hint: AppLocalizations.of(context).splitTunnelAddressHint,
        onSubmit: (value) => notifier.addRule(_type, value),
      ),
    );
  }
}
