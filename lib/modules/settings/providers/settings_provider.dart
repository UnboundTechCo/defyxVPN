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
      debugPrint('Skipping save - not initialized yet');
      return;
    }

    final jsonMap =
        state.groups.map((key, group) => MapEntry(key, group.toJson()));
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
    if (!updatedGroups.containsKey(SettingsGroupId.trafficControl)) {
      updatedGroups[SettingsGroupId.trafficControl] =
          _createTrafficControlGroup(text);
    }

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
      ));
  }

  bool isDeepScanEnabled() {
    final savedGroup = state.groups[SettingsGroupId.trafficControl];
    return SettingsFactory.getSavedItemState(
      savedGroup?.items,
      SettingsItemId.deepScan,
    );
  }

  SettingsGroup _createDefaultConnectionMethodGroup(
    List<dynamic> flowline,
    SettingsText text,
  ) {
    final connectionItems = SettingsFactory.flowlineToItems(flowline);
    return SettingsFactory.createConnectionMethodGroup(
      title: text.connectionMethodTitle,
      connectionItems: connectionItems,
      destinationTitle: text.destinationTitle,
    );
  }

  // ============== Connection Method Sync ==============

  Future<void> _updateConnectionMethodFromFlowLine({BuildContext? context}) async {
    try {
      final text = SettingsText(context);
      // Load flowline
      final flowline = await _loadFlowLine();
      if (flowline.isEmpty) {
        _updateGroup(_createDefaultConnectionMethodGroup([], text));
        return;
      }

      // Load saved settings
      final settingsJson =
          await _secureStorage?.read(SettingsStorageKey.appSettings);

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
          mergedItems.add(SettingsFactory.createDestinationItem(
            title: text.destinationTitle,
          ).toJson());
        }
      } else {
        mergedItems
            .removeWhere((item) => item['id'] == SettingsItemId.destination);
      }

      // Rebuild group with merged items (preserving user's sortOrder)
      final updatedGroupData = Map<String, dynamic>.from(
          savedData[SettingsGroupId.connectionMethod]);
      updatedGroupData['items'] = mergedItems;
      updatedGroupData['title'] = text.connectionMethodTitle;

      final updatedGroup = SettingsGroup.fromJson(updatedGroupData);
      _updateGroup(updatedGroup);
    } catch (e) {
      debugPrint('Error updating connection method: $e');
      final flowline = await _loadFlowLine();
      final text = SettingsText(context);
      _updateGroup(_createDefaultConnectionMethodGroup(flowline, text));
    }
  }

  Future<void> _loadSettingsFromStorage() async {
    final jsonString =
        await _secureStorage?.read(SettingsStorageKey.appSettings);

    if (jsonString == null) return;

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonString);

      final groups = decoded.map(
        (key, value) => MapEntry(
          key,
          SettingsGroup.fromJson(value),
        ),
      );

      state = state.copyWith(groups: groups);
      debugPrint('Settings loaded from storage');
    } catch (e) {
      debugPrint('Failed to load settings: $e');
    }
  }

  // ============== Public Actions ==============

  void toggleSetting(String groupId, String itemId, [BuildContext? context]) {
    print('Toggling setting: $groupId - $itemId');
    final group = state.groups[groupId];
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
      // Show error message if context is available
      if (context != null) {
        final text = SettingsText(context);
        SettingsToastMessage.show(text.atLeastOneCoreRequired);
      }
      return;
    }

    _updateGroup(group.copyWith(items: updatedItems));
    _saveSettings();
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

    _updateGroup(
        group.copyWith(items: [...updatedDraggableItems, ...navigationItems]));
    _saveSettings();
  }

  // ============== Query Methods ==============

  String getConnectionMethodPattern() {
    final group = state.groups[SettingsGroupId.connectionMethod];
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

  Future<void> resetToDefault({BuildContext? context}) async {
    final flowline = await _loadFlowLine();
    final text = SettingsText(context);
    _updateGroup(_createDefaultConnectionMethodGroup(flowline, text));
    _saveSettings();
  }

  Future<void> resetGroupToDefault(String groupId) async {
    if (groupId == SettingsGroupId.connectionMethod) {
      await resetToDefault();
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
      updatedGroups[SettingsGroupId.connectionMethod] = 
          connectionGroup.copyWith(title: text.connectionMethodTitle);
      
      // Update destination item title if it exists
      final updatedItems = connectionGroup.items.map((item) {
        if (item.id == SettingsItemId.destination) {
          return item.copyWith(title: text.destinationTitle);
        }
        return item;
      }).toList();
      
      updatedGroups[SettingsGroupId.connectionMethod] = 
          connectionGroup.copyWith(
            title: text.connectionMethodTitle,
            items: updatedItems,
          );
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
          case SettingsItemId.killSwitch:
            return item.copyWith(title: text.killSwitchTitle);
          default:
            return item;
        }
      }).toList();
      
      updatedGroups[SettingsGroupId.trafficControl] = 
          trafficGroup.copyWith(
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
