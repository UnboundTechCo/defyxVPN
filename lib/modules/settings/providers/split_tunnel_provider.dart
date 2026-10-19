import 'dart:convert';
import 'dart:io';

import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_interface.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/settings_constants.dart';
import '../models/installed_app.dart';
import '../models/split_tunnel_config.dart';

class SplitTunnelNotifier extends StateNotifier<SplitTunnelConfig> {
  final ISecureStorage _storage;
  late final Future<void> _ready;

  SplitTunnelNotifier(this._storage) : super(const SplitTunnelConfig()) {
    _ready = _load();
  }

  Future<SplitTunnelConfig> loadedConfig() async {
    await _ready;
    return state;
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(SettingsStorageKey.splitTunnel);
      if (raw == null) return;
      state = SplitTunnelConfig.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('Failed to load split tunnel settings: $e');
    }
  }

  Future<void> _update(SplitTunnelConfig config) async {
    state = config;
    try {
      await _storage.write(
        SettingsStorageKey.splitTunnel,
        jsonEncode(config.toJson()),
      );
    } catch (e) {
      debugPrint('Failed to save split tunnel settings: $e');
    }
  }

  Future<void> setMode(SplitTunnelMode mode) async {
    await _ready;
    if (mode == state.mode) return;
    await _update(state.copyWith(mode: mode));
  }

  Future<bool> addRule(SplitTunnelRuleType type, String value) async {
    await _ready;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) return false;

    final rule = SplitTunnelRule(type: type, value: trimmed);
    if (state.rules.contains(rule)) return false;

    await _update(state.copyWith(rules: [...state.rules, rule]));
    return true;
  }

  Future<void> removeRule(SplitTunnelRule rule) async {
    await _ready;
    await _update(
      state.copyWith(rules: state.rules.where((r) => r != rule).toList()),
    );
  }

  Future<bool> addApp(String value) async {
    await _ready;
    final entry = _normalizeAppEntry(value);
    if (entry.isEmpty || state.apps.contains(entry)) return false;

    await _update(state.copyWith(apps: [...state.apps, entry]));
    return true;
  }

  Future<void> removeApp(String app) async {
    await _ready;
    await _update(
      state.copyWith(apps: state.apps.where((a) => a != app).toList()),
    );
  }

  Future<void> toggleApp(String packageName) async {
    await _ready;
    if (state.apps.contains(packageName)) {
      await removeApp(packageName);
    } else {
      await _update(state.copyWith(apps: [...state.apps, packageName]));
    }
  }

  String _normalizeAppEntry(String value) {
    final trimmed = value.trim();
    return Platform.isWindows ? trimmed.replaceAll('\\', '/') : trimmed;
  }
}

final splitTunnelProvider =
    StateNotifierProvider<SplitTunnelNotifier, SplitTunnelConfig>(
      (ref) => SplitTunnelNotifier(ref.read(secureStorageProvider)),
    );

final installedAppsProvider = FutureProvider.autoDispose<List<InstalledApp>>((
  ref,
) async {
  final apps = await VpnBridge().getInstalledApps();
  return [...apps]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});
