import 'dart:convert';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_item.dart';
import '../models/settings_group.dart';

class SettingsNotifier extends StateNotifier<List<SettingsGroup>> {
  final Ref<List<SettingsGroup>> ref;
  SettingsNotifier(this.ref) : super([]) {
    _loadSettings();
  }

  static const String _settingsKey = 'app_settings';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);

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
    final prefs = await SharedPreferences.getInstance();
    final jsonList = state.map((group) => group.toJson()).toList();
    await prefs.setString(_settingsKey, jsonEncode(jsonList));
  }

  Future<List<SettingsGroup>> _getDefaultSettings() async {
    List<dynamic> flowline = [];
    final flowLineStorage =
        await ref.read(secureStorageProvider).read('flowLine');
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

  void toggleSetting(String groupId, String itemId) {
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

        if (oldIndex < allItems.length && newIndex < allItems.length) {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }

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

  List<String> getPattern() {
    final items = state[0].items.where((item) => item.isEnabled).toList();
    items.sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    return items.map((item) => item.id).toList();
  }

  Future<void> clearSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_settingsKey);
    state = await _getDefaultSettings();
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, List<SettingsGroup>>(
  (ref) => SettingsNotifier(ref),
);
