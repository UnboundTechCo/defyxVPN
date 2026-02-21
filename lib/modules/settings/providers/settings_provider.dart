import 'dart:convert';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settings_item.dart';
import '../models/settings_group.dart';
import '../constants/settings_constants.dart';
import '../factories/settings_factory.dart';
import '../presentation/widgets/settings_toast_message.dart';

class SettingsState {
  final Map<String, SettingsGroup> groups;
  final bool isLoading;

  const SettingsState({
    required this.groups,
    this.isLoading = false,
  });

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

class SettingsNotifier extends AsyncNotifier<SettingsState> {
  ISecureStorage? _secureStorage;

  @override
  Future<SettingsState> build() async {
    _secureStorage = ref.read(secureStorageProvider);
    state = const AsyncValue.loading();
    final groups = await _initializeSettings();
    return SettingsState(groups: groups);
  }

  // ============== Initialization ==============

  Future<Map<String, SettingsGroup>> _initializeSettings() async {
    await _updateConnectionMethodFromFlowLine();
    _ensureStaticGroups();
    debugPrint('Settings initialized');
    return state.value?.groups ?? {};
  }

  // ============== Storage Operations ==============

  Future<void> _saveSettings() async {
    final groups = state.value?.groups ?? {};
    if (groups.isEmpty) {
      debugPrint('Skipping save - not initialized yet');
      return;
    }
    final jsonMap = groups.map((key, group) => MapEntry(key, group.toJson()));
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
    final updatedGroups = Map<String, SettingsGroup>.from(state.value?.groups ?? {});
    updatedGroups[group.id] = group;
    state = AsyncValue.data(state.value?.copyWith(groups: updatedGroups) ?? SettingsState(groups: updatedGroups));
  }

  void _ensureStaticGroups() {
    final updatedGroups = Map<String, SettingsGroup>.from(state.value?.groups ?? {});
    // Only add traffic control if it doesn't exist
    if (!updatedGroups.containsKey(SettingsGroupId.trafficControl)) {
      updatedGroups[SettingsGroupId.trafficControl] =
          _createTrafficControlGroup();
    }
    state = AsyncValue.data(state.value?.copyWith(groups: updatedGroups) ?? SettingsState(groups: updatedGroups));

    // Only save if we have connection_method loaded (not empty state)
    if (updatedGroups.containsKey(SettingsGroupId.connectionMethod)) {
      _saveSettings();
    }
  }

  // ============== Group Creation ==============

  SettingsGroup _createTrafficControlGroup() {
    final savedGroup = state.value?.groups[SettingsGroupId.trafficControl];

    return SettingsFactory.createTrafficControlGroup(
      splitTunnelEnabled: SettingsFactory.getSavedItemState(
        savedGroup?.items,
        SettingsItemId.splitTunnel,
      ),
      killSwitchEnabled: SettingsFactory.getSavedItemState(
        savedGroup?.items,
        SettingsItemId.killSwitch,
      ),
    );
  }
  bool isDeepScanEnabled() {
    final savedGroup = state.value?.groups[SettingsGroupId.trafficControl];
    return SettingsFactory.getSavedItemState(
      savedGroup?.items,
      SettingsItemId.deepScan,
    );
  }

  SettingsGroup _createDefaultConnectionMethodGroup(List<dynamic> flowline) {
    final connectionItems = SettingsFactory.flowlineToItems(flowline);
    return SettingsFactory.createConnectionMethodGroup(
      connectionItems: connectionItems,
    );
  }

  // ============== Connection Method Sync ==============

  Future<void> _updateConnectionMethodFromFlowLine() async {
    try {
      // Load flowline
      final flowline = await _loadFlowLine();
      if (flowline.isEmpty) {
        _updateGroup(_createDefaultConnectionMethodGroup([]));
        return;
      }

      // Load saved settings
      final settingsJson =
          await _secureStorage?.read(SettingsStorageKey.appSettings);

      if (settingsJson == null) {
        _updateGroup(_createDefaultConnectionMethodGroup(flowline));
        return;
      }

      // Parse saved settings
      final Map<String, dynamic> savedData = jsonDecode(settingsJson);
      if (!savedData.containsKey(SettingsGroupId.connectionMethod)) {
        _updateGroup(_createDefaultConnectionMethodGroup(flowline));
        return;
      }

      // Get saved items - these contain user's drag order(sortOrder)
      final List<dynamic> savedItems = List<dynamic>.from(
          savedData[SettingsGroupId.connectionMethod]['items'] ?? []);

      final allFlowlineItems = flowline.toList();

      // Filter saved items - keep items that exist in flowline OR are navigation items
      // This preserves user's sortOrder!
      final List<dynamic> mergedItems = savedItems.where((settingItem) {
        if (settingItem['itemType'] == 'navigation') return true;
        return allFlowlineItems
            .any((flowItem) => flowItem['label'] == settingItem['id']);
      }).toList();

      // Find max sortOrder from existing items
      int maxSortOrder = 0;
      for (var item in mergedItems) {
        final order = item['sortOrder'] as int? ?? 0;
        if (order > maxSortOrder) maxSortOrder = order;
      }

      // New items go to the end (after user's ordered items)
      for (var flowItem in allFlowlineItems) {
        final label = flowItem['label'] as String;
        final existsInSaved = mergedItems.any((settingItem) =>
            settingItem['id'] == label ||
            settingItem['itemType'] == 'navigation');

        if (!existsInSaved) {
          maxSortOrder++;
          final newItem = SettingsFactory.createFlowlineItem(
            label: label,
            description: flowItem['description'] ?? '',
            sortOrder: maxSortOrder,
            isEnabled: flowItem['enabled'] ?? false,
          );
          mergedItems.add(newItem.toJson());
        }
      }

      if (SettingsFactory.config.showDestination) {
        if (!mergedItems
            .any((item) => item['id'] == SettingsItemId.destination)) {
          mergedItems.add(SettingsFactory.createDestinationItem().toJson());
        }
      } else {
        mergedItems
            .removeWhere((item) => item['id'] == SettingsItemId.destination);
      }

      // Rebuild group with merged items (preserving user's sortOrder)
      final updatedGroupData = Map<String, dynamic>.from(
          savedData[SettingsGroupId.connectionMethod]);
      updatedGroupData['items'] = mergedItems;

      final updatedGroup = SettingsGroup.fromJson(updatedGroupData);
      _updateGroup(updatedGroup);
    } catch (e) {
      debugPrint('Error updating connection method: $e');
      final flowline = await _loadFlowLine();
      _updateGroup(_createDefaultConnectionMethodGroup(flowline));
    }
  }

  // ============== Public Actions ==============

  void toggleSetting(String groupId, String itemId, [BuildContext? context]) {
    final group = state.value?.groups[groupId];
    if (group == null) return;

    final updatedItems = group.items.map((item) {
      if (item.id == itemId && item.isAccessible) {
        return item.copyWith(isEnabled: !item.isEnabled);
      }
      return item;
    }).toList();

    // Prevent disabling all connection methods
    if (groupId == SettingsGroupId.connectionMethod &&
        updatedItems.every((item) => !item.isEnabled)) {
      SettingsToastMessage.show(SettingsMessage.atLeastOneCoreRequired);
      return;
    }

    _updateGroup(group.copyWith(items: updatedItems));
    _saveSettings();
  }

  void reorderItems(String groupId, int oldIndex, int newIndex) {
    final group = state.value?.groups[groupId];
    if (group == null || !group.isDraggable) return;

    final draggableItems = group.items
        .where((item) => item.itemType != SettingsItemType.navigation)
        .toList()
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

    final navigationItems = group.items
        .where((item) => item.itemType == SettingsItemType.navigation)
        .toList();

    if (newIndex > oldIndex) newIndex -= 1;

    if (oldIndex < 0 ||
        oldIndex >= draggableItems.length ||
        newIndex < 0 ||
        newIndex >= draggableItems.length) {
      return;
    }

    final item = draggableItems.removeAt(oldIndex);
    draggableItems.insert(newIndex, item);

    final updatedDraggableItems = draggableItems
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(sortOrder: entry.key))
        .toList();

    _updateGroup(group.copyWith(items: [...updatedDraggableItems, ...navigationItems]));
    _saveSettings();
  }

  // ============== Query Methods ==============

  String getConnectionMethodPattern() {
    final group = state.value?.groups[SettingsGroupId.connectionMethod];
    if (group == null) return '';

    final items = group.items
        .where((item) =>
            item.isEnabled && item.itemType != SettingsItemType.navigation)
        .toList()
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

    return items.map((item) => item.id).join(',');
  }

  String getPattern() => getConnectionMethodPattern();

  // ============== Reset Methods ==============

  Future<void> resetToDefault() async {
    final flowline = await _loadFlowLine();
    _updateGroup(_createDefaultConnectionMethodGroup(flowline));
    _saveSettings();
  }

  Future<void> resetGroupToDefault(String groupId) async {
    if (groupId == SettingsGroupId.connectionMethod) {
      await resetToDefault();
    }
  }

  // ============== Refresh Methods ==============

  Future<void> saveState() async => await _saveSettings();

  Future<void> updateSettingsBasedOnFlowLine() async {
    await _updateConnectionMethodFromFlowLine();
    _ensureStaticGroups();
  }

  Future<void> refreshFromFlowLine() async {
    await _updateConnectionMethodFromFlowLine();
    _ensureStaticGroups();
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
