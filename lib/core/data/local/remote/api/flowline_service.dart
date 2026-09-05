import 'dart:convert';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service_interface.dart';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_settings.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_interface.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:defyx_vpn/modules/settings/providers/settings_provider.dart';
import 'package:defyx_vpn/shared/global_vars.dart';
import 'package:defyx_vpn/shared/providers/flow_line_provider.dart';
import 'package:defyx_vpn/shared/services/desktop_error_logger.dart';
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
  Future<String> getFlowline() async {
    final token = await _container.read(authProvider.notifier).getToken();
    final flowLine = await _vpnBridge.getFlowLine(token);
    return flowLine;
  }

  @override
  Future<String> getCachedFlowLine() => _vpnBridge.getCachedFlowLine();

  @override
  Future<String> decodeAndVerifyFlowline(String flowLine) =>
      _vpnBridge.decodeAndVerifyFlowline(flowLine);

  @override
  Future<void> saveFlowline({
    required bool offlineMode,
    String? flowLine,
    bool forceUpdate = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lastFlowlineUpdate = prefs.getInt(lastFlowlineUpdateKey) ?? 0;
    final shouldUpdate =
        (DateTime.now().millisecondsSinceEpoch - lastFlowlineUpdate) >
        _updateFlowlinePerios;
    if (!shouldUpdate && !offlineMode && !forceUpdate) {
      return;
    }
    final flowlineMode = _container.read(flowLineProvider).mode;

    if (offlineMode) {
      if (flowLine == null || flowLine.isEmpty) {
        flowLine = await getCachedFlowLine();
      } else {
        // Pass to core for decoding and verification
        final verifiedFlowLine = await decodeAndVerifyFlowline(flowLine);
        if (verifiedFlowLine.isEmpty) {
          debugPrint('Flowline verification failed in core');
          return;
        }
        _container.read(flowLineProvider.notifier).setMode("offline");
        flowLine = verifiedFlowLine;
      }
    } else {
      if (flowlineMode == "offline") {
        flowLine = "";
      } else {
        flowLine = await getFlowline();
      }
    }

    if (flowLine.isNotEmpty) {
      try {
        final decoded = json.decode(flowLine);

        // A structurally-empty/placeholder blob (e.g. "{}") must never overwrite
        // previously-saved good data (would corrupt flowLineKey with "null").
        if (decoded is! Map || decoded['flowLine'] == null) {
          debugPrint('Flowline payload has no flowLine data, skipping save');
          return;
        }

        final appBuildType = GlobalVars.appBuildType;
        final version = decoded['version']?[appBuildType];

        final advertiseStorageMap = {'api_advertise': decoded['advertise']};
        // Cached blobs from older app versions may not have a 'settings' field.
        final settingsStorageMap =
            (decoded['settings'] as Map<String, dynamic>?) ??
            <String, dynamic>{};
        await _secureStorage.writeMap(apiAvertiseKey, advertiseStorageMap);
        await _secureStorage.writeMap(flowlineSettingsKey, settingsStorageMap);

        // Save tips if available
        if (decoded['tips'] != null) {
          final tipsJson = json.encode(decoded['tips']);
          await _secureStorage.write(apiTipsKey, tipsJson);
        }

        final versionStorageMap = {
          'api_app_version': version,
          'forceUpdate': (decoded['forceUpdate'] as Map?)?[version],
          'changeLog': (decoded['changeLog'] as Map?)?[version],
        };

        await _secureStorage.writeMap(
          apiVersionParametersKey,
          versionStorageMap,
        );

        await _secureStorage.write(
          flowLineKey,
          json.encode(decoded['flowLine']),
        );
        final settings = _container.read(settingsProvider.notifier);
        await settings.updateSettingsBasedOnFlowLine();
        if (!offlineMode) {
          prefs.setInt(
            lastFlowlineUpdateKey,
            DateTime.now().millisecondsSinceEpoch,
          );
        }
      } catch (e, stack) {
        // Cached flowline may be from an incompatible older/newer schema; skip this write rather than crash startup.
        debugPrint('Failed to parse/save flowline: $e');
        await DesktopErrorLogger().logError(
          'FlowlineService.saveFlowline',
          e,
          stack,
        );
      }
    } else {
      debugPrint('Flowline is empty, cannot save');
    }
  }

  @override
  Future<FlowlineSettings> getFlowlineSettings() async {
    try {
      final settingsString = await _secureStorage.read(flowlineSettingsKey);
      final decodedSettings = json.decode(settingsString ?? "");
      return FlowlineSettings.fromJson(decodedSettings);
    } catch (e, stack) {
      debugPrint('Failed to read flowline settings: $e');
      await DesktopErrorLogger().logError(
        'FlowlineService.getFlowlineSettings',
        e,
        stack,
      );
      return FlowlineSettings(disabledAdmob: []);
    }
  }
}
