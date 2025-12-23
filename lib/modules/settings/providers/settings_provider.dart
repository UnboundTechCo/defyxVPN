import 'dart:convert';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_interface.dart';
import 'package:defyx_vpn/core/utils/toast_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settings_item.dart';
import '../models/settings_group.dart';
import '../presentation/widgets/settings_toast_message.dart';

class SettingsNotifier extends StateNotifier<List<SettingsGroup>> {
  final Ref<List<SettingsGroup>> ref;
  ISecureStorage? _secureStorage;
  final String _settingsKey = 'app_settings';
  int _versionCounter = 0;

  SettingsNotifier(this.ref) : super([]) {
    _secureStorage = ref.read(secureStorageProvider);
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    final loadedSettings = await _loadSettingsFromStorage();
    if (loadedSettings != null) {
      state = loadedSettings;
    } else {
      state = await _getDefaultSettings();
      await _saveSettings();
    }
  }

  Future<List<SettingsGroup>?> _loadSettingsFromStorage() async {
    try {
      final settingsJson = await _secureStorage?.read(_settingsKey);
      if (settingsJson == null) return null;

      final List<dynamic> data = jsonDecode(settingsJson);
      return data.map((json) => SettingsGroup.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading settings: $e');
      return null;
    }
  }

  Future<void> _saveSettings() async {
    final jsonList = state.map((group) => group.toJson()).toList();
    await _secureStorage?.write(_settingsKey, jsonEncode(jsonList));
  }

  Future<List<SettingsGroup>> _getDefaultSettings() async {
    final flowline = await _getFlowlineFromStorage();

    return [
      SettingsGroup(
        id: 'connection_method',
        title: 'CONNECTION METHOD',
        isDraggable: true,
        items: flowline.asMap().entries.map((entry) {
          final index = entry.key;
          final flow = entry.value;
          return SettingsItem(
            id: flow['label'] ?? '',
            title: flow['label'] ?? '',
            isEnabled: flow['enabled'] ?? false,
            isAccessible: true,
            sortOrder: index,
            description: flow['description'] ?? '',
          );
        }).toList(),
      )
    ];
  }

  Future<List<dynamic>> _getFlowlineFromStorage() async {
    try {
      final flowLineStorage = await _secureStorage?.read(flowLineKey);
      if (flowLineStorage != null) {
        return json.decode(flowLineStorage);
      }
    } catch (e) {
      debugPrint('Error reading flowline: $e');
    }
    return [];
  }

  void toggleSetting(String groupId, String itemId, [BuildContext? context]) {
    final tempState = state.map((group) {
      if (group.id == groupId) {
        final updatedItems = group.items.map((item) {
          if (item.id == itemId && item.isAccessible) {
            return item.copyWith(isEnabled: !item.isEnabled);
          }
          return item;
        }).toList();
        return group.copyWith(items: updatedItems);
      }
      return group;
    }).toList();

    if (tempState[0].items.every((item) => !item.isEnabled)) {
      if (context != null) {
        SettingsToastMessage.show(
            context, 'At least one core must remain enabled');
      } else {
        ToastUtil.showToast('At least one core must remain enabled');
      }
      return;
    }

    state = tempState;
    _saveSettings();
  }

  Future<void> resetToDefault() async {
    state = await _getDefaultSettings();
    await _saveSettings();
  }

  Future<void> resetConnectionMethodToDefault() async {
    final defaultSettings = await _getDefaultSettings();
    final defaultConnectionMethod = defaultSettings.firstWhere(
      (group) => group.id == 'connection_method',
    );

    state = state.map((group) {
      if (group.id == 'connection_method') {
        return defaultConnectionMethod;
      }
      return group;
    }).toList();

    await _saveSettings();
  }

  void reorderConnectionMethodItems(int oldIndex, int newIndex) {
    state = state.map((group) {
      if (group.id == 'connection_method') {
        final List<SettingsItem> allItems = List.from(group.items)
          ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

        if (newIndex > oldIndex) {
          newIndex -= 1;
        }

        if (oldIndex >= 0 &&
            oldIndex < allItems.length &&
            newIndex >= 0 &&
            newIndex < allItems.length) {
          final item = allItems.removeAt(oldIndex);
          allItems.insert(newIndex, item);

          final updatedItems = allItems
              .asMap()
              .entries
              .map((entry) {
                return entry.value.copyWith(sortOrder: entry.key);
              })
              .toList()
              .cast<SettingsItem>();

          return group.copyWith(items: updatedItems);
        }
      }
      return group;
    }).toList();

    _saveSettings();
  }

  String getPattern() {
    if (state.isEmpty) return '';
    final items = state[0].items.where((item) => item.isEnabled).toList();
    items.sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    return items.map((item) => item.id).toList().join(',');
  }

  Future<void> syncWithFlowline() async {
    try {
      final flowline = await _getFlowlineFromStorage();
      if (flowline.isEmpty) {
        debugPrint('Flowline is empty, skipping sync');
        return;
      }

      final currentSettings = await _loadSettingsFromStorage();

      if (currentSettings == null || currentSettings.isEmpty) {
        state = await _getDefaultSettings();
        await _saveSettings();
        return;
      }

      final connectionGroup = currentSettings.firstWhere(
        (group) => group.id == 'connection_method',
        orElse: () => SettingsGroup(
          id: 'connection_method',
          title: 'CONNECTION METHOD',
          isDraggable: true,
          items: [],
        ),
      );

      final currentItemsMap = {
        for (var item in connectionGroup.items) item.id: item
      };

      final enabledFlowlineItems =
          flowline.where((flow) => flow['enabled'] == true).toList();

      final List<SettingsItem> newItems = [];

      for (var i = 0; i < enabledFlowlineItems.length; i++) {
        final flowItem = enabledFlowlineItems[i];
        final itemId = flowItem['label'] ?? '';

        if (currentItemsMap.containsKey(itemId)) {
          final existingItem = currentItemsMap[itemId]!;
          newItems.add(existingItem.copyWith(
            sortOrder: existingItem.sortOrder ?? newItems.length,
            description: flowItem['description'] ?? existingItem.description,
          ));
        } else {
          newItems.add(SettingsItem(
            id: itemId,
            title: itemId,
            isAccessible: true,
            isEnabled: flowItem['enabled'] ?? false,
            sortOrder: newItems.length,
            description: flowItem['description'] ?? '',
          ));
        }
      }

      newItems.sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

      final reorderedItems = newItems.asMap().entries.map((entry) {
        return entry.value.copyWith(sortOrder: entry.key);
      }).toList();

      final updatedGroup = connectionGroup.copyWith(items: reorderedItems);

      state = [updatedGroup];
      _versionCounter++;
      await _saveSettings();

      debugPrint('Settings synced with flowline. Version: $_versionCounter');
    } catch (e) {
      debugPrint('Error syncing with flowline: $e');
      state = await _getDefaultSettings();
      await _saveSettings();
    }
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, List<SettingsGroup>>(
  (ref) => SettingsNotifier(ref),
);

final settingsLoadingProvider = StateProvider<bool>((ref) => false);
