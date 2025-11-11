import 'dart:convert';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
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

  SettingsNotifier(this.ref) : super([]) {
    _secureStorage = ref.read(secureStorageProvider);
    _updateSettingsBasedOnFlowLine();
  }

  Future<void> _loadSettings() async {
    final settingsJson = await _secureStorage?.read(_settingsKey);

    if (settingsJson != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(settingsJson);
        state = jsonList
            .map((json) => SettingsGroup.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        state = await _getDefaultSettings();
      }
    } else {
      state = await _getDefaultSettings();
    }
  }

  Future<void> _saveSettings() async {
    final jsonList = state.map((group) => group.toJson()).toList();
    await _secureStorage?.write(_settingsKey, jsonEncode(jsonList));
  }

  Future<List<SettingsGroup>> _getDefaultSettings() async {
    List<dynamic> flowline = [];
    final flowLineStorage = await _secureStorage?.read('flowLine');
    if (flowLineStorage != null) {
      flowline = json.decode(flowLineStorage);
    }

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
          );
        }).toList(),
      )
      // SettingsGroup(
      //   id: 'escape_mode',
      //   title: 'ESCAPE MODE',
      //   isDraggable: false,
      //   items: [
      //     SettingsItem(
      //       id: 'route_reconnect',
      //       title: 'ROUTE RECONNECT',
      //       isEnabled: true,
      //       isAccessible: true,
      //       sortOrder: 0,
      //     ),
      //     SettingsItem(
      //       id: 'deep_scan',
      //       title: 'DEEP SCAN',
      //       isEnabled: false,
      //       isAccessible: true,
      //       sortOrder: 1,
      //     ),
      //   ],
      // ),
      // SettingsGroup(
      //   id: 'protective_measures',
      //   title: 'PROTECTIVE MEASURES',
      //   isDraggable: false,
      //   items: [
      //     SettingsItem(
      //       id: 'child_safety',
      //       title: 'CHILD SAFETY',
      //       isEnabled: true,
      //       isAccessible: true,
      //       sortOrder: 0,
      //     ),
      //     SettingsItem(
      //       id: 'threat_protection',
      //       title: 'THREAT PROTECTION',
      //       isEnabled: true,
      //       isAccessible: true,
      //       sortOrder: 1,
      //     ),
      //     SettingsItem(
      //       id: 'ad_blocker',
      //       title: 'AD BLOCKER',
      //       isEnabled: true,
      //       isAccessible: true,
      //       sortOrder: 2,
      //     ),
      //   ],
      // ),
    ];
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
        SettingsToastMessage.show(context, 'At least one core must remain enabled');
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
    _saveSettings();
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

    _saveSettings();
  }

  void reorderConnectionMethodItems(int oldIndex, int newIndex) {
    state = state.map((group) {
      if (group.id == 'connection_method') {
        final List<SettingsItem> allItems = List.from(group.items)
          ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

        if (newIndex > oldIndex) {
          newIndex -= 1;
        }

        if (oldIndex >= 0 && oldIndex < allItems.length && newIndex >= 0 && newIndex < allItems.length) {
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
    final items = state[0].items.where((item) => item.isEnabled).toList();
    items.sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    return items.map((item) => item.id).toList().join(',');
  }

  Future<void> _updateSettingsBasedOnFlowLine() async {
    try {
      List<dynamic> flowline = [];
      final flowLineStorage = await _secureStorage?.read('flowLine');
      if (flowLineStorage == null) {
        state = await _getDefaultSettings();
        return;
      }

      flowline = json.decode(flowLineStorage);
      List<dynamic> jsonList = [];
      final settingsJson = await _secureStorage?.read(_settingsKey);

      if (settingsJson == null) {
        state = await _getDefaultSettings();
        return;
      }

      final List<dynamic> data = jsonDecode(settingsJson);
      jsonList = data[0]["items"];
      jsonList = jsonList.where((settingItem) {
        if (flowline.any(
            (flowlineItem) => flowlineItem['label'] == settingItem['id'])) {
          return true;
        }
        return false;
      }).toList();

      final filteredFlowline =
          flowline.where((test) => test['enabled'] == true).toList();

      for (var item in filteredFlowline) {
        if (jsonList
            .every((settingItem) => settingItem['id'] != item['label'])) {
          final newItem = SettingsItem(
              id: item['label'],
              title: item['label'],
              isAccessible: true,
              isEnabled: true,
              sortOrder: jsonList.length);
          jsonList.add(newItem.toJson());
        }
      }
      data[0]["items"] = jsonList;

      state = data.map((json) => SettingsGroup.fromJson(json)).toList();
      _saveSettings();
    } catch (e) {
      state = await _getDefaultSettings();
    }
  }

  Future<void> updateSettingsBasedOnFlowLine() async {
    _updateSettingsBasedOnFlowLine();
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, List<SettingsGroup>>(
  (ref) => SettingsNotifier(ref),
);
