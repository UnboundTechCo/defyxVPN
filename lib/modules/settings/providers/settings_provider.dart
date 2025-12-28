import 'dart:convert';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settings_item.dart';
import '../models/settings_group.dart';
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

  List<SettingsGroup> get groupList => groups.values.toList();

  SettingsGroup? getGroup(String id) => groups[id];
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref<SettingsState> ref;
  ISecureStorage? _secureStorage;
  final String _settingsKey = 'app_settings_v2';

  static const String connectionMethodGroupId = 'connection_method';
  static const String trafficControlGroupId = 'traffic_control';

  SettingsNotifier(this.ref) : super(const SettingsState(groups: {})) {
    _secureStorage = ref.read(secureStorageProvider);
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    await _updateConnectionMethodFromFlowLine();
    _ensureStaticGroups();
  }

  Future<void> _saveSettings() async {
    final jsonMap =
        state.groups.map((key, group) => MapEntry(key, group.toJson()));
    await _secureStorage?.write(_settingsKey, jsonEncode(jsonMap));
  }

  Future<Map<String, dynamic>?> _loadSavedSettings() async {
    final settingsJson = await _secureStorage?.read(_settingsKey);
    if (settingsJson == null) return null;
    try {
      return jsonDecode(settingsJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
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

  List<SettingsItem> _createConnectionMethodItems(List<dynamic> flowline) {
    return flowline.asMap().entries.map((entry) {
      final index = entry.key;
      final flow = entry.value as Map<String, dynamic>;
      return SettingsItem(
        id: flow['label'] ?? '',
        title: flow['label'] ?? '',
        isEnabled: flow['enabled'] ?? false,
        isAccessible: true,
        sortOrder: index,
        description: flow['description'] ?? '',
        itemType: SettingsItemType.toggle,
      );
    }).toList();
  }

  SettingsGroup _createDefaultConnectionMethodGroup(List<dynamic> flowline) {
    final connectionItems = _createConnectionMethodItems(flowline);
    final destinationItem = SettingsItem(
      id: 'destination',
      title: 'DESTINATION',
      isEnabled: false,
      isAccessible: true,
      sortOrder: 9999,
      itemType: SettingsItemType.navigation,
      navigationRoute: '/settings/destination',
      showLeftIcon: true,
    );

    return SettingsGroup(
      id: connectionMethodGroupId,
      title: 'CONNECTION METHOD',
      isDraggable: true,
      items: [...connectionItems, destinationItem],
    );
  }

  SettingsGroup _createTrafficControlGroup() {
    final savedGroup = state.groups[trafficControlGroupId];

    return SettingsGroup(
      id: trafficControlGroupId,
      title: 'TRAFFIC CONTROL',
      isDraggable: false,
      items: [
        SettingsItem(
          id: 'split_tunnel',
          title: 'SPLIT TUNNEL',
          isEnabled: savedGroup?.items
                  .where((i) => i.id == 'split_tunnel')
                  .firstOrNull
                  ?.isEnabled ??
              false,
          isAccessible: true,
          sortOrder: 0,
          itemType: SettingsItemType.navigation,
          navigationRoute: '/settings/split_tunnel',
          subtitle: 'INCLUDED',
        ),
        SettingsItem(
          id: 'kill_switch',
          title: 'KILL SWITCH',
          isEnabled: savedGroup?.items
                  .where((i) => i.id == 'kill_switch')
                  .firstOrNull
                  ?.isEnabled ??
              false,
          isAccessible: true,
          sortOrder: 1,
          itemType: SettingsItemType.toggle,
        ),
      ],
    );
  }

  void _ensureStaticGroups() {
    final updatedGroups = Map<String, SettingsGroup>.from(state.groups);

    if (!updatedGroups.containsKey(trafficControlGroupId)) {
      updatedGroups[trafficControlGroupId] = _createTrafficControlGroup();
    }

    state = state.copyWith(groups: updatedGroups);
    _saveSettings();
  }

  Future<void> _updateConnectionMethodFromFlowLine() async {
    try {
      final flowline = await _loadFlowLine();

      if (flowline.isEmpty) {
        final defaultGroup = _createDefaultConnectionMethodGroup([]);
        _updateGroup(defaultGroup);
        return;
      }

      final savedSettings = await _loadSavedSettings();

      if (savedSettings == null ||
          !savedSettings.containsKey(connectionMethodGroupId)) {
        final defaultGroup = _createDefaultConnectionMethodGroup(flowline);
        _updateGroup(defaultGroup);
        return;
      }

      final savedGroup =
          SettingsGroup.fromJson(savedSettings[connectionMethodGroupId]);
      final mergedItems =
          _mergeConnectionMethodItems(savedGroup.items, flowline);

      final updatedGroup = savedGroup.copyWith(items: mergedItems);
      _updateGroup(updatedGroup);
    } catch (_) {
      final defaultGroup = _createDefaultConnectionMethodGroup([]);
      _updateGroup(defaultGroup);
    }
  }

  List<SettingsItem> _mergeConnectionMethodItems(
      List<SettingsItem> savedItems, List<dynamic> flowline) {
    final flowlineLabels = flowline
        .where((f) => f['enabled'] == true)
        .map((f) => f['label'] as String)
        .toSet();

    final navigationItems = savedItems
        .where((item) => item.itemType == SettingsItemType.navigation)
        .map((item) {
      if (item.id == 'destination') {
        return item.copyWith(showLeftIcon: true);
      }
      return item;
    }).toList();

    final filteredItems = savedItems
        .where((item) =>
            item.itemType != SettingsItemType.navigation &&
            flowlineLabels.contains(item.id))
        .toList();

    for (var flow in flowline.where((f) => f['enabled'] == true)) {
      final label = flow['label'] as String;
      if (!filteredItems.any((item) => item.id == label)) {
        filteredItems.add(SettingsItem(
          id: label,
          title: label,
          isAccessible: true,
          isEnabled: true,
          sortOrder: filteredItems.length,
          description: flow['description'] ?? '',
          itemType: SettingsItemType.toggle,
        ));
      }
    }

    if (!navigationItems.any((item) => item.id == 'destination')) {
      navigationItems.add(SettingsItem(
        id: 'destination',
        title: 'DESTINATION',
        isEnabled: false,
        isAccessible: true,
        sortOrder: 9999,
        itemType: SettingsItemType.navigation,
        navigationRoute: '/settings/destination',
        showLeftIcon: true,
      ));
    }

    return [...filteredItems, ...navigationItems];
  }

  void _updateGroup(SettingsGroup group) {
    final updatedGroups = Map<String, SettingsGroup>.from(state.groups);
    updatedGroups[group.id] = group;
    state = state.copyWith(groups: updatedGroups);
  }

  void toggleSetting(String groupId, String itemId, [BuildContext? context]) {
    final group = state.groups[groupId];
    if (group == null) return;

    final updatedItems = group.items.map((item) {
      if (item.id == itemId && item.isAccessible) {
        return item.copyWith(isEnabled: !item.isEnabled);
      }
      return item;
    }).toList();

    if (groupId == connectionMethodGroupId &&
        updatedItems.every((item) => !item.isEnabled)) {
      SettingsToastMessage.show('At least one core must remain enabled');
      return;
    }

    final updatedGroup = group.copyWith(items: updatedItems);
    _updateGroup(updatedGroup);
    _saveSettings();
  }

  Future<void> resetToDefault() async {
    final flowline = await _loadFlowLine();
    final defaultConnectionMethod =
        _createDefaultConnectionMethodGroup(flowline);
    _updateGroup(defaultConnectionMethod);
    _saveSettings();
  }

  Future<void> resetGroupToDefault(String groupId) async {
    if (groupId == connectionMethodGroupId) {
      final flowline = await _loadFlowLine();
      final defaultGroup = _createDefaultConnectionMethodGroup(flowline);
      _updateGroup(defaultGroup);
      _saveSettings();
    }
  }

  void reorderItems(String groupId, int oldIndex, int newIndex) {
    final group = state.groups[groupId];
    if (group == null || !group.isDraggable) return;

    final draggableItems = group.items
        .where((item) => item.itemType != SettingsItemType.navigation)
        .toList()
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

    final navigationItems = group.items
        .where((item) => item.itemType == SettingsItemType.navigation)
        .toList();

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    if (oldIndex >= 0 &&
        oldIndex < draggableItems.length &&
        newIndex >= 0 &&
        newIndex < draggableItems.length) {
      final item = draggableItems.removeAt(oldIndex);
      draggableItems.insert(newIndex, item);

      final updatedDraggableItems = draggableItems
          .asMap()
          .entries
          .map((entry) => entry.value.copyWith(sortOrder: entry.key))
          .toList();

      final allItems = [...updatedDraggableItems, ...navigationItems];
      final updatedGroup = group.copyWith(items: allItems);
      _updateGroup(updatedGroup);
      _saveSettings();
    }
  }

  String getConnectionMethodPattern() {
    final group = state.groups[connectionMethodGroupId];
    if (group == null) return '';

    final items = group.items
        .where((item) =>
            item.isEnabled && item.itemType != SettingsItemType.navigation)
        .toList();
    items.sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    return items.map((item) => item.id).join(',');
  }

  String getPattern() {
    return getConnectionMethodPattern();
  }

  Future<void> saveState() async {
    await _saveSettings();
  }

  Future<void> updateSettingsBasedOnFlowLine() async {
    await _updateConnectionMethodFromFlowLine();
    _ensureStaticGroups();
  }

  Future<void> refreshFromFlowLine() async {
    await _updateConnectionMethodFromFlowLine();
    _ensureStaticGroups();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(ref),
);

final settingsLoadingProvider = StateProvider<bool>((ref) => false);
