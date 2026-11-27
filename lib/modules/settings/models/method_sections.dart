import 'settings_item.dart';

/// Where a connection method comes from. Sections show in this order, and
/// DXcore tries the methods in the same order.
enum MethodSection { premium, market, builtIn, rewards }

/// The flowline's `kind` values that aren't rewards. Any other kind (invite,
/// trial, queue, gift, and ones added later) is a reward.
abstract class MethodKind {
  static const premium = 'premium';
  static const market = 'market';
  static const builtIn = 'builtin';
}

extension MethodSectionOf on SettingsItem {
  MethodSection get section => switch (kind) {
    MethodKind.premium => MethodSection.premium,
    MethodKind.market => MethodSection.market,
    MethodKind.builtIn => MethodSection.builtIn,
    // Flowlines from before `kind` only mark premium and market methods.
    null || '' =>
      isPremium
          ? MethodSection.premium
          : isMarket
          ? MethodSection.market
          : MethodSection.builtIn,
    _ => MethodSection.rewards,
  };
}

/// What can be dragged inside a section: one method, or a plan with its
/// locations.
class MethodBlock {
  const MethodBlock({required this.key, required this.items, this.planId});

  /// The item's id, or [MethodLayout.planKey] for a plan.
  final String key;
  final List<SettingsItem> items;

  /// Set for a plan with more than one location.
  final String? planId;

  bool get isPlan => planId != null;

  List<String> get itemIds => [for (final item in items) item.id];

  /// For a plan: its own config, the method named just like the plan. It's
  /// listed under the plan like the others, by what it is (its subscription
  /// link) rather than the plan's name again.
  SettingsItem? get main => isPlan ? MethodLayout.planMain(items) : null;
}

class MethodSectionGroup {
  const MethodSectionGroup(this.section, this.blocks);

  final MethodSection section;
  final List<MethodBlock> blocks;

  Iterable<SettingsItem> get items => blocks.expand((block) => block.items);
}

abstract class MethodLayout {
  static String sectionKey(MethodSection section) => 'section:${section.name}';
  static String planKey(String planId) => 'plan:$planId';

  /// Whether DXcore should try [item]: switched on, not expired, and its plan
  /// isn't switched off.
  static bool isActive(
    SettingsItem item,
    Set<String> disabledPlans,
    DateTime now,
  ) =>
      item.isEnabled &&
      !item.isExpiredAt(now) &&
      !(item.planId != null && disabledPlans.contains(item.planId));

  /// The methods grouped into sections, then plans, keeping their order inside
  /// each. Sections without methods are left out.
  static List<MethodSectionGroup> sections(Iterable<SettingsItem> items) {
    final bySection = {
      for (final section in MethodSection.values) section: <SettingsItem>[],
    };
    for (final item in _byOrder(items)) {
      bySection[item.section]!.add(item);
    }
    return [
      for (final section in MethodSection.values)
        if (bySection[section]!.isNotEmpty)
          MethodSectionGroup(section, _blocks(bySection[section]!)),
    ];
  }

  /// The method of [planItems] named just like their plan: the plan's own
  /// config, next to its locations or SOS backup.
  static SettingsItem? planMain(List<SettingsItem> planItems) {
    for (final item in planItems) {
      final planName = item.planName?.trim().toLowerCase();
      if (!item.isSos &&
          planName != null &&
          item.title.trim().toLowerCase() == planName) {
        return item;
      }
    }
    return null;
  }

  /// The plans in [disabledPlans] that still have several methods in
  /// [items]; a plan's switch only shows while it does.
  static List<String> liveDisabledPlans(
    Iterable<SettingsItem> items,
    Iterable<String> disabledPlans,
  ) {
    final plans = multiLocationPlans(items);
    return [
      for (final planId in disabledPlans)
        if (plans.contains(planId)) planId,
    ];
  }

  /// Plans with more than one location, by id.
  static Set<String> multiLocationPlans(Iterable<SettingsItem> items) {
    final counts = <String, int>{};
    for (final item in items) {
      final planId = item.planId;
      if (planId != null) counts[planId] = (counts[planId] ?? 0) + 1;
    }
    return {
      for (final entry in counts.entries)
        if (entry.value > 1) entry.key,
    };
  }

  /// [items] in section and plan order, numbered 0, 1, 2… A plan sits where
  /// its first location was.
  static List<SettingsItem> normalize(List<SettingsItem> items) {
    final ordered = [for (final section in sections(items)) ...section.items];
    return [
      for (var i = 0; i < ordered.length; i++)
        ordered[i].copyWith(sortOrder: i),
    ];
  }

  /// Moves `blocks[oldIndex]` so it ends up at [newIndex]. The moved items
  /// take the order numbers the blocks already used, so nothing else in the
  /// list moves. Returns [items] itself when nothing moves.
  static List<SettingsItem> reorderBlocks(
    List<SettingsItem> items,
    List<List<String>> blocks,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex < 0 ||
        oldIndex >= blocks.length ||
        newIndex < 0 ||
        newIndex >= blocks.length ||
        oldIndex == newIndex) {
      return items;
    }

    final byId = {for (final item in items) item.id: item};
    final ids = [for (final block in blocks) ...block];
    if (!ids.every(byId.containsKey)) return items;

    final slots = [for (final id in ids) byId[id]!.sortOrder ?? 0]..sort();
    final moved = [...blocks];
    moved.insert(newIndex, moved.removeAt(oldIndex));
    final newOrder = <String, int>{};
    var slot = 0;
    for (final block in moved) {
      for (final id in block) {
        newOrder[id] = slots[slot++];
      }
    }

    return normalize([
      for (final item in items)
        newOrder.containsKey(item.id)
            ? item.copyWith(sortOrder: newOrder[item.id])
            : item,
    ]);
  }

  /// Where a method that just appeared in the flowline goes in [ordered]:
  /// after its plan's other locations; for a newly bought plan, before the
  /// paid methods already there; for a reward, by its end date, soonest first;
  /// otherwise at the end.
  static int insertIndex(
    List<SettingsItem> ordered,
    SettingsItem item, {
    required int newPaidCount,
  }) {
    final planId = item.planId;
    if (planId != null) {
      final planEnd = ordered.lastIndexWhere((other) => other.planId == planId);
      if (planEnd >= 0) return planEnd + 1;
    }
    switch (item.section) {
      case MethodSection.premium:
      case MethodSection.market:
        return newPaidCount;
      case MethodSection.rewards:
        final ends = item.expiresAt;
        if (ends == null) return ordered.length;
        final later = ordered.indexWhere(
          (other) =>
              other.section == MethodSection.rewards &&
              (other.expiresAt == null || other.expiresAt!.isAfter(ends)),
        );
        return later >= 0 ? later : ordered.length;
      case MethodSection.builtIn:
        return ordered.length;
    }
  }

  /// Finds plans from method names while the flowline doesn't send plan ids.
  ///
  /// The backend names a plan's methods `<plan> <location>` (or just
  /// `<plan>`) and its backup `<plan> SOS`. Locations are free text and can
  /// have spaces, so plan names come only from the SOS methods: a paid method
  /// belongs to the longest SOS plan name its own name starts with. Methods
  /// with no SOS sibling stay single rows.
  static List<SettingsItem> groupPlansByName(List<SettingsItem> items) {
    bool eligible(SettingsItem item) =>
        item.planId == null &&
        item.itemType == SettingsItemType.toggle &&
        (item.section == MethodSection.premium ||
            item.section == MethodSection.market);

    final names = {
      for (final section in [MethodSection.premium, MethodSection.market])
        section: <String>{
          for (final item in items)
            if (eligible(item) && item.section == section)
              if (_sosPlanName(item.title) case final String name) name,
        },
    };

    final plans = <String, List<int>>{};
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (!eligible(item)) continue;
      final name = _planNameOf(item.title.trim(), names[item.section]!);
      if (name == null) continue;
      plans.putIfAbsent('${item.section.name}:$name', () => []).add(i);
    }

    final result = [...items];
    for (final MapEntry(key: key, value: indexes) in plans.entries) {
      if (indexes.length < 2) continue;
      final name = key.substring(key.indexOf(':') + 1);
      for (final i in indexes) {
        final item = items[i];
        final rest = item.title.trim().substring(name.length).trim();
        final isSos = rest.toLowerCase() == 'sos';
        result[i] = item.copyWith(
          planId: 'name:$key',
          planName: item.planName ?? name,
          isSos: item.isSos || isSos,
          country: item.country ?? (isSos || rest.isEmpty ? null : rest),
        );
      }
    }
    return result;
  }

  static final _sosSuffix = RegExp(r'\s+sos$', caseSensitive: false);

  static String? _sosPlanName(String title) {
    final trimmed = title.trim();
    if (!_sosSuffix.hasMatch(trimmed)) return null;
    final name = trimmed.replaceFirst(_sosSuffix, '').trim();
    return name.isEmpty ? null : name;
  }

  static String? _planNameOf(String title, Set<String> names) {
    String? best;
    for (final name in names) {
      final matches = title == name || title.startsWith('$name ');
      if (matches && (best == null || name.length > best.length)) best = name;
    }
    return best;
  }

  /// [items] with rewards sorted by end date, soonest first (no date last).
  /// Everything else keeps its place.
  static List<SettingsItem> rewardsBySoonestEnd(List<SettingsItem> items) {
    final rewards = [
      for (var i = 0; i < items.length; i++)
        if (items[i].section == MethodSection.rewards) (i, items[i]),
    ];
    final sorted = [...rewards]
      ..sort((a, b) {
        final aEnds = a.$2.expiresAt;
        final bEnds = b.$2.expiresAt;
        if (aEnds == null || bEnds == null) {
          if (aEnds == bEnds) return a.$1.compareTo(b.$1);
          return aEnds == null ? 1 : -1;
        }
        final byDate = aEnds.compareTo(bEnds);
        return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
      });
    final result = [...items];
    for (var i = 0; i < rewards.length; i++) {
      result[rewards[i].$1] = sorted[i].$2;
    }
    return result;
  }

  /// [items] sorted by sortOrder; ties keep their order.
  static List<SettingsItem> _byOrder(Iterable<SettingsItem> items) {
    final indexed = items.indexed.toList()
      ..sort((a, b) {
        final byOrder = (a.$2.sortOrder ?? 0).compareTo(b.$2.sortOrder ?? 0);
        return byOrder != 0 ? byOrder : a.$1.compareTo(b.$1);
      });
    return [for (final entry in indexed) entry.$2];
  }

  static List<MethodBlock> _blocks(List<SettingsItem> items) {
    final plans = multiLocationPlans(items);
    final planItems = <String, List<SettingsItem>>{};
    for (final item in items) {
      if (plans.contains(item.planId)) {
        planItems.putIfAbsent(item.planId!, () => []).add(item);
      }
    }
    final blocks = <MethodBlock>[];
    for (final item in items) {
      final planId = item.planId;
      if (planId != null && plans.contains(planId)) {
        if (planItems[planId]!.first.id == item.id) {
          blocks.add(
            MethodBlock(
              key: planKey(planId),
              planId: planId,
              items: planItems[planId]!,
            ),
          );
        }
      } else {
        blocks.add(MethodBlock(key: item.id, items: [item]));
      }
    }
    return blocks;
  }
}
