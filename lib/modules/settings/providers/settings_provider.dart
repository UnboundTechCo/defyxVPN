import 'dart:convert';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/method_sections.dart';
import '../models/settings_item.dart';
import '../models/settings_group.dart';
import '../constants/settings_constants.dart';
import '../factories/settings_factory.dart';
import '../presentation/widgets/settings_toast_message.dart';

class SettingsState {
  final Map<String, SettingsGroup> groups;
  final bool isLoading;

  const SettingsState({required this.groups, this.isLoading = false});

  SettingsState copyWith({
    Map<String, SettingsGroup>? groups,
    bool? isLoading,
  }) {
    return SettingsState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<SettingsGroup> get groupList =>
      groups.values.where((group) => group.items.isNotEmpty).toList();

  SettingsGroup? getGroup(String id) => groups[id];
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref<SettingsState> ref;
  ISecureStorage? _secureStorage;
  bool _isInitialized = false;

  SettingsNotifier(this.ref) : super(const SettingsState(groups: {})) {
    _secureStorage = ref.read(secureStorageProvider);
    _initializeSettings();
  }

  // ============== Initialization ==============

  Future<void> _initializeSettings() async {
    await _loadSettingsFromStorage();
    await _updateConnectionMethodFromFlowLine();
    _ensureStaticGroups();
    _isInitialized = true;
    debugPrint('Settings initialized');
  }

  // ============== Storage Operations ==============

  Future<void> _saveSettings() async {
    if (!_isInitialized && state.groups.isEmpty) {
      return;
    }

    final jsonMap = state.groups.map(
      (key, group) => MapEntry(key, group.toJson()),
    );
    final jsonString = jsonEncode(jsonMap);
    await _secureStorage?.write(SettingsStorageKey.appSettings, jsonString);
  }

  Future<List<dynamic>> _loadFlowLine() async {
    final flowLineStorage = await _secureStorage?.read(flowLineKey);
    if (flowLineStorage == null) return [];
    try {
      return json.decode(flowLineStorage) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  // ============== Group Management ==============

  void _updateGroup(SettingsGroup group) {
    final updatedGroups = Map<String, SettingsGroup>.from(state.groups);
    updatedGroups[group.id] = group;
    state = state.copyWith(groups: updatedGroups);
  }

  void _ensureStaticGroups({BuildContext? context}) {
    final updatedGroups = Map<String, SettingsGroup>.from(state.groups);
    final text = SettingsText(context);
    // Only add traffic control if it doesn't exist
    // if (!updatedGroups.containsKey(SettingsGroupId.trafficControl)) {
    // debugPrint('Adding traffic control group');
    updatedGroups[SettingsGroupId.trafficControl] = _createTrafficControlGroup(
      text,
    );
    // }

    // Share Diagnostics moved to the Diagnostics & Experiments dialog; drop
    // the privacy group that dev builds saved for it.
    updatedGroups.remove('privacy');

    state = state.copyWith(groups: updatedGroups);

    // Only save if we have connection_method loaded (not empty state)
    if (updatedGroups.containsKey(SettingsGroupId.connectionMethod)) {
      _saveSettings();
    }
  }

  // ============== Group Creation ==============

  SettingsGroup _createTrafficControlGroup(SettingsText text) {
    final savedGroup = state.groups[SettingsGroupId.trafficControl];
    return SettingsFactory.createTrafficControlGroup(
      title: text.escapeModeTitle,
      splitTunnelTitle: text.splitTunnelTitle,
      splitTunnelSubtitle: text.splitTunnelSubtitle,
      deepScanTitle: text.deepScanTitle,
      healthCheckTitle: text.healthCheckTitle,
      killSwitchTitle: text.killSwitchTitle,
      splitTunnelEnabled: SettingsFactory.getSavedItemState(
        savedGroup?.items,
        SettingsItemId.splitTunnel,
      ),
      killSwitchEnabled: SettingsFactory.getSavedItemState(
        savedGroup?.items,
        SettingsItemId.killSwitch,
      ),
      deepScanEnabled: SettingsFactory.getSavedItemState(
        savedGroup?.items,
        SettingsItemId.deepScan,
      ),
      healthCheckEnabled: SettingsFactory.getSavedItemState(
        savedGroup?.items,
        SettingsItemId.healthCheck,
      ),
    );
  }

  bool isDeepScanEnabled() {
    final savedGroup = state.groups[SettingsGroupId.trafficControl];
    return SettingsFactory.getSavedItemState(
      savedGroup?.items,
      SettingsItemId.deepScan,
    );
  }

  bool isHealthCheckEnabled() {
    final savedGroup = state.groups[SettingsGroupId.trafficControl];
    return SettingsFactory.getSavedItemState(
      savedGroup?.items,
      SettingsItemId.healthCheck,
    );
  }

  bool isKillSwitchEnabled() {
    final savedGroup = state.groups[SettingsGroupId.trafficControl];
    return SettingsFactory.getSavedItemState(
      savedGroup?.items,
      SettingsItemId.killSwitch,
    );
  }

  SettingsGroup _createDefaultConnectionMethodGroup(
    List<dynamic> flowline,
    SettingsText text,
  ) {
    final flowItems = MethodLayout.rewardsBySoonestEnd(
      MethodLayout.groupPlansByName(SettingsFactory.flowlineToItems(flowline)),
    );
    final connectionItems = MethodLayout.normalize([
      for (var i = 0; i < flowItems.length; i++)
        flowItems[i].copyWith(sortOrder: i),
    ]);
    final group = SettingsFactory.createConnectionMethodGroup(
      title: text.connectionMethodTitle,
      connectionItems: connectionItems,
      destinationTitle: text.destinationTitle,
    );
    // Opened and closed sections are a view choice, not a setting to reset.
    final saved = state.groups[SettingsGroupId.connectionMethod];
    return saved == null ? group : group.copyWith(expanded: saved.expanded);
  }

  /// Merges the user's saved methods with the current flowline: keeps their
  /// order and switches, takes everything else from the flowline, drops
  /// methods the flowline no longer has, and places new ones.
  List<SettingsItem> _mergeWithFlowline(
    List<SettingsItem> saved,
    List<Map<String, dynamic>> flowline,
  ) {
    // Each method as the flowline has it now, with plans found first so a
    // new location can join its plan.
    final seen = <String>{};
    final flowByLabel = {
      for (final item in MethodLayout.groupPlansByName(
        SettingsFactory.flowlineToItems([
          for (final flow in flowline)
            if (flow['label'] is String && seen.add(flow['label'] as String))
              flow,
        ]),
      ))
        item.title: item,
    };

    final ordered = <SettingsItem>[];
    final labels = <String>{};
    for (final item in [
      ...saved,
    ]..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0))) {
      final current = flowByLabel[item.title];
      if (current == null || !labels.add(item.title)) continue;
      ordered.add(current.copyWith(id: item.id, isEnabled: item.isEnabled));
    }

    final ids = {for (final item in ordered) item.id};
    var newPaidCount = 0;
    for (final entry in flowByLabel.entries) {
      if (labels.contains(entry.key)) continue;
      var id = entry.key + ordered.length.toString();
      for (var n = ordered.length + 1; ids.contains(id); n++) {
        id = entry.key + n.toString();
      }
      ids.add(id);
      final item = entry.value.copyWith(id: id);
      final at = MethodLayout.insertIndex(
        ordered,
        item,
        newPaidCount: newPaidCount,
      );
      ordered.insert(at, item);
      final isPaid =
          item.section == MethodSection.premium ||
          item.section == MethodSection.market;
      if (isPaid && at <= newPaidCount) newPaidCount++;
    }

    return MethodLayout.normalize([
      for (var i = 0; i < ordered.length; i++)
        ordered[i].copyWith(sortOrder: i),
    ]);
  }

  // ============== Connection Method Sync ==============

  Future<void> _updateConnectionMethodFromFlowLine({
    BuildContext? context,
  }) async {
    try {
      final text = SettingsText(context);
      // Load flowline
      final flowline = await _loadFlowLine();
      if (flowline.isEmpty) {
        _updateGroup(_createDefaultConnectionMethodGroup([], text));
        return;
      }

      // Load saved settings
      final settingsJson = await _secureStorage?.read(
        SettingsStorageKey.appSettings,
      );

      if (settingsJson == null) {
        _updateGroup(_createDefaultConnectionMethodGroup(flowline, text));
        return;
      }

      // Parse saved settings
      final Map<String, dynamic> savedData = jsonDecode(settingsJson);
      if (!savedData.containsKey(SettingsGroupId.connectionMethod)) {
        _updateGroup(_createDefaultConnectionMethodGroup(flowline, text));
        return;
      }

      final savedGroup = SettingsGroup.fromJson(
        Map<String, dynamic>.from(savedData[SettingsGroupId.connectionMethod]),
      );
      final savedMethods = savedGroup.items
          .where((item) => item.itemType != SettingsItemType.navigation)
          .toList();
      final navigationItems = savedGroup.items
          .where((item) => item.itemType == SettingsItemType.navigation)
          .toList();

      final methods = _mergeWithFlowline(savedMethods, [
        for (final flow in flowline)
          if (flow is Map) Map<String, dynamic>.from(flow),
      ]);

      if (SettingsFactory.config.showDestination) {
        if (!navigationItems.any(
          (item) => item.id == SettingsItemId.destination,
        )) {
          navigationItems.add(
            SettingsFactory.createDestinationItem(title: text.destinationTitle),
          );
        }
      } else {
        navigationItems.removeWhere(
          (item) => item.id == SettingsItemId.destination,
        );
      }

      _updateGroup(
        savedGroup.copyWith(
          title: text.connectionMethodTitle,
          items: [...methods, ...navigationItems],
          disabledPlans: MethodLayout.liveDisabledPlans(
            methods,
            savedGroup.disabledPlans,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error updating connection method: $e');
      final flowline = await _loadFlowLine();
      final text = SettingsText(context);
      _updateGroup(_createDefaultConnectionMethodGroup(flowline, text));
    }
  }

  Future<void> _loadSettingsFromStorage() async {
    final jsonString = await _secureStorage?.read(
      SettingsStorageKey.appSettings,
    );

    if (jsonString == null) return;

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonString);

      final groups = decoded.map(
        (key, value) => MapEntry(key, SettingsGroup.fromJson(value)),
      );

      state = state.copyWith(groups: groups);
    } catch (e) {
      debugPrint('Failed to load settings: $e');
    }
  }

  // ============== Public Actions ==============

  void toggleSetting(String groupId, String itemId, [BuildContext? context]) {
    final group = state.groups[groupId];
    if (group == null) return;

    final now = DateTime.now();
    final target = group.items.where((item) => item.id == itemId).firstOrNull;
    // A plan's methods follow its switch while it's off.
    if (target != null && group.disabledPlans.contains(target.planId)) {
      return;
    }
    final updatedItems = group.items.map((item) {
      if (item.id == itemId && item.isAccessible && !item.isExpiredAt(now)) {
        return item.copyWith(isEnabled: !item.isEnabled);
      }
      return item;
    }).toList();

    final updatedGroup = group.copyWith(items: updatedItems);
    if (!_keepsAMethodOn(updatedGroup, context)) return;

    _updateGroup(updatedGroup);
    _saveSettings();
  }

  /// Switches a plan with several methods on or off. While it's off, none of
  /// its methods are tried; back on, they follow their own switches again.
  void togglePlan(String groupId, String planId, [BuildContext? context]) {
    final group = state.groups[groupId];
    if (group == null ||
        !MethodLayout.multiLocationPlans(group.items).contains(planId)) {
      return;
    }

    final disabled = group.disabledPlans.toSet();
    if (!disabled.remove(planId)) disabled.add(planId);
    final updatedGroup = group.copyWith(disabledPlans: disabled.toList());
    if (!_keepsAMethodOn(updatedGroup, context)) return;

    _updateGroup(updatedGroup);
    _saveSettings();
  }

  /// False, with a message, when [group] is the connection methods and none
  /// would be left for DXcore to try.
  bool _keepsAMethodOn(SettingsGroup group, BuildContext? context) {
    if (group.id != SettingsGroupId.connectionMethod) return true;
    if (_activeMethods(group).isNotEmpty) return true;
    if (context != null) {
      SettingsToastMessage.show(SettingsText(context).atLeastOneCoreRequired);
    }
    return false;
  }

  /// Moves one block (a method, or a plan with its locations) within its
  /// section, or one location within its plan, so it ends up at [newIndex].
  /// [blocks] lists the item ids of every block in that list, in order.
  void reorderBlocks(
    String groupId,
    List<List<String>> blocks,
    int oldIndex,
    int newIndex,
  ) {
    final group = state.groups[groupId];
    if (group == null || !group.isDraggable) return;

    final methods = group.items
        .where((item) => item.itemType != SettingsItemType.navigation)
        .toList();
    final navigationItems = group.items
        .where((item) => item.itemType == SettingsItemType.navigation)
        .toList();

    final reordered = MethodLayout.reorderBlocks(
      methods,
      blocks,
      oldIndex,
      newIndex,
    );
    if (identical(reordered, methods)) return;

    _updateGroup(group.copyWith(items: [...reordered, ...navigationItems]));
    _saveSettings();
  }

  /// Remembers that the user opened or closed a section or plan.
  void setExpanded(String groupId, String key, bool expanded) {
    final group = state.groups[groupId];
    if (group == null) return;

    _updateGroup(group.copyWith(expanded: {...group.expanded, key: expanded}));
    _saveSettings();
  }

  // ============== Query Methods ==============

  /// The methods DXcore should try, in order.
  List<SettingsItem> _activeMethods(SettingsGroup group) {
    final now = DateTime.now();
    final disabledPlans = group.disabledPlans.toSet();
    return group.items
        .where(
          (item) =>
              item.itemType != SettingsItemType.navigation &&
              MethodLayout.isActive(item, disabledPlans, now),
        )
        .toList()
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
  }

  String getConnectionMethodPattern() {
    final group = state.groups[SettingsGroupId.connectionMethod];
    if (group == null) return '';

    return _activeMethods(group).map((item) => item.title).join(',');
  }

  bool isPremiumCustomer() {
    final group = state.groups[SettingsGroupId.connectionMethod];
    if (group == null) return false;

    return group.items.any((item) => item.isPremium);
  }

  String getPattern() => getConnectionMethodPattern();

  // ============== Reset Methods ==============

  Future<void> resetToDefault({BuildContext? context}) async {
    final flowline = await _loadFlowLine();
    final text = SettingsText(context);
    _updateGroup(_createDefaultConnectionMethodGroup(flowline, text));
    _saveSettings();
  }

  Future<void> resetGroupToDefault(
    String groupId, {
    BuildContext? context,
  }) async {
    if (groupId == SettingsGroupId.connectionMethod) {
      await resetToDefault(context: context);
    }
  }

  // ============== Refresh Methods ==============

  Future<void> saveState() async => await _saveSettings();

  void applyLocalization(BuildContext context) {
    final text = SettingsText(context);
    final updatedGroups = Map<String, SettingsGroup>.from(state.groups);

    // Update connection method group title and items if it exists
    final connectionGroup = updatedGroups[SettingsGroupId.connectionMethod];
    if (connectionGroup != null) {
      // Update the group title
      updatedGroups[SettingsGroupId.connectionMethod] = connectionGroup
          .copyWith(title: text.connectionMethodTitle);

      // Update destination item title if it exists
      final updatedItems = connectionGroup.items.map((item) {
        if (item.id == SettingsItemId.destination) {
          return item.copyWith(title: text.destinationTitle);
        }
        return item;
      }).toList();

      updatedGroups[SettingsGroupId.connectionMethod] = connectionGroup
          .copyWith(title: text.connectionMethodTitle, items: updatedItems);
    }

    // Update traffic control group title and items if it exists
    final trafficGroup = updatedGroups[SettingsGroupId.trafficControl];
    if (trafficGroup != null) {
      final updatedItems = trafficGroup.items.map((item) {
        switch (item.id) {
          case SettingsItemId.splitTunnel:
            return item.copyWith(
              title: text.splitTunnelTitle,
              subtitle: text.splitTunnelSubtitle,
            );
          case SettingsItemId.deepScan:
            return item.copyWith(title: text.deepScanTitle);
          case SettingsItemId.healthCheck:
            return item.copyWith(title: text.healthCheckTitle);
          case SettingsItemId.killSwitch:
            return item.copyWith(title: text.killSwitchTitle);

          default:
            return item;
        }
      }).toList();

      updatedGroups[SettingsGroupId.trafficControl] = trafficGroup.copyWith(
        title: text.escapeModeTitle,
        items: updatedItems,
      );
    }

    state = state.copyWith(groups: updatedGroups);
  }

  Future<void> updateSettingsBasedOnFlowLine({BuildContext? context}) async {
    await _updateConnectionMethodFromFlowLine(context: context);
    _ensureStaticGroups(context: context);
  }

  Future<void> refreshFromFlowLine({BuildContext? context}) async {
    await _updateConnectionMethodFromFlowLine(context: context);
    _ensureStaticGroups(context: context);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(ref),
);

final settingsLoadingProvider = StateProvider<bool>((ref) => false);
