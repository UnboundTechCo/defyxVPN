import 'dart:convert';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service_interface.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_interface.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/modules/settings/providers/settings_provider.dart';
import 'package:defyx_vpn/shared/global_vars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

final flowlineServiceProvider = Provider<IFlowlineService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return FlowlineService(secureStorage, ref.container);
});

class FlowlineService implements IFlowlineService {
  final ISecureStorage _secureStorage;
  final ProviderContainer _container;
  final _vpnBridge = VpnBridge();
  final lastFlowlineUpdateKey = 'lastFlowlineUpdate';
  static final _updateFlowlinePerios =
      int.parse(dotenv.env['UPDATE_FLOWLINE_PERIOD'] ?? "60") * 1000;

  FlowlineService(this._secureStorage, this._container);

  @override
  Future<String> getFlowline() => _vpnBridge.getFlowLine();

  @override
  Future<String> getCachedFlowLine() => _vpnBridge.getCachedFlowLine();

  @override
  Future<void> saveFlowline(bool offlineMode) async {
    final prefs = await SharedPreferences.getInstance();
    final lastFlowlineUpdate = prefs.getInt(lastFlowlineUpdateKey) ?? 0;
    final shouldUpdate =
        (DateTime.now().millisecondsSinceEpoch - lastFlowlineUpdate) >
            _updateFlowlinePerios;
    if (!shouldUpdate) {
      return;
    }
    String flowLine = "";
    if (offlineMode) {
      flowLine = await getCachedFlowLine();
    } else {
      flowLine = await getFlowline();
    }

    if (flowLine.isNotEmpty) {
      final decoded = json.decode(flowLine);

      final appBuildType = GlobalVars.appBuildType;
      final version = decoded['version'][appBuildType];

      final advertiseStorageMap = {
        'api_advertise': decoded['advertise'],
      };
      await _secureStorage.writeMap(apiAvertiseKey, advertiseStorageMap);

      final versionStorageMap = {
        'api_app_version': version,
        'forceUpdate': decoded['forceUpdate'][version],
        'changeLog': decoded['changeLog'][version],
      };

      await _secureStorage.writeMap(apiVersionParametersKey, versionStorageMap);

      await _secureStorage.write(flowLineKey, json.encode(decoded['flowLine']));
      final settings = _container.read(settingsProvider.notifier);
      await settings.updateSettingsBasedOnFlowLine();
      if (!offlineMode) {
        prefs.setInt(
            lastFlowlineUpdateKey, DateTime.now().millisecondsSinceEpoch);
      }
    } else {
      debugPrint('Flowline is empty, cannot save');
    }
  }
}
