import 'dart:convert';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service_interface.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_interface.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/modules/settings/providers/settings_provider.dart';
import 'package:defyx_vpn/shared/global_vars.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';

final flowlineServiceProvider = Provider<IFlowlineService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return FlowlineService(secureStorage);
});

class FlowlineService implements IFlowlineService {
  final ISecureStorage _secureStorage;
  final _vpnBridge = VpnBridge();

  FlowlineService(this._secureStorage);

  @override
  Future<String> getFlowline() => _vpnBridge.getFlowLine();

  /// Load default flowline from assets
  Future<Map<String, dynamic>> _loadDefaultFlowline() async {
    try {
      final String defaultFlowlineJson = await rootBundle.loadString('assets/settings/default_flowline.json');
      return json.decode(defaultFlowlineJson);
    } catch (e) {
      // Return a minimal fallback if asset loading fails
      return {
        'version': {'release': '1.0.0'},
        'advertise': {},
        'forceUpdate': {'1.0.0': false},
        'changeLog': {'1.0.0': 'Offline mode'},
        'flowLine': [
          {
            'label': 'Auto (Offline)',
            'enabled': true,
            'urls': ['vless://offline@localhost:1080?#Offline'],
            'max_items': 1,
            'probe_timeout': 30
          }
        ]
      };
    }
  }

  /// Get flowline from storage or load default
  Future<Map<String, dynamic>> getStoredFlowlineOrDefault() async {
    try {
      final stored = await _secureStorage.read(flowLineKey);
      if (stored != null && stored.isNotEmpty) {
        // Stored value is the previously saved `flowLine` JSON (an array of steps).
        // To keep the return type consistent with the bundled default flowline (a Map),
        // wrap the stored array into a Map and attempt to attach advertise/version
        // metadata from other storage keys so callers can rely on the same shape.
        final decodedStored = json.decode(stored);
        Map<String, dynamic> advertise = {};
        Map<String, dynamic> versionParams = {};
        try {
          advertise = await _secureStorage.readMap(apiAvertiseKey);
        } catch (_) {
          advertise = {};
        }
        try {
          versionParams = await _secureStorage.readMap(apiVersionParametersKey);
        } catch (_) {
          versionParams = {};
        }

        final versionValue = versionParams['api_app_version'] ?? '';
        final forceUpdateValue = versionParams['forceUpdate'] ?? false;
        final changeLogValue = versionParams['changeLog'] ?? '';

        return {
          'version': {'release': versionValue},
          'advertise': advertise,
          'forceUpdate': {versionValue: forceUpdateValue},
          'changeLog': {versionValue: changeLogValue},
          'flowLine': decodedStored,
        };
      }
    } catch (e) {
      // Storage read failed, fall back to default
    }
    
    // Load from bundled assets as fallback
    final defaultFlowline = await _loadDefaultFlowline();
    // Store the default for future use
    await _secureStorage.write(flowLineKey, json.encode(defaultFlowline['flowLine']));
    return defaultFlowline;
  }

  @override
  Future<void> saveFlowline() async {
    // Check if offline mode is explicitly enabled
    const bool useOfflineFlowline = bool.fromEnvironment('USE_OFFLINE_FLOWLINE', defaultValue: false);
    
    if (useOfflineFlowline) {
      // Offline mode is enabled, use default flowline regardless of DXcore availability
      debugPrint('Offline flowline mode is enabled via environment variable');
      await _saveDefaultFlowline();
      return;
    }
    
    try {
      final flowLine = await getFlowline();
      
      if (flowLine.isNotEmpty) {
        // Parse flowline from DXcore
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
        final ref = ProviderContainer();
        final settings = ref.read(settingsProvider.notifier);
        await settings.updateSettingsBasedOnFlowLine();
      } else {
        // No flowline from DXcore, use default offline flowline as fallback
        await _saveDefaultFlowline();
      }
    } catch (e) {
      // Network or DXcore error, fall back to default
      await _saveDefaultFlowline();
    }
  }

  /// Save default flowline for offline use
  Future<void> _saveDefaultFlowline() async {
    try {
      final defaultFlowline = await _loadDefaultFlowline();
      final appBuildType = GlobalVars.appBuildType;
      final version = defaultFlowline['version'][appBuildType] ?? defaultFlowline['version']['release'];

      final advertiseStorageMap = {
        'api_advertise': defaultFlowline['advertise'] ?? {},
      };
      await _secureStorage.writeMap(apiAvertiseKey, advertiseStorageMap);

      final versionStorageMap = {
        'api_app_version': version,
        'forceUpdate': defaultFlowline['forceUpdate'][version] ?? false,
        'changeLog': defaultFlowline['changeLog'][version] ?? 'Offline mode',
      };

      await _secureStorage.writeMap(apiVersionParametersKey, versionStorageMap);

      await _secureStorage.write(flowLineKey, json.encode(defaultFlowline['flowLine']));
      
      // Update settings with offline flowline
      final ref = ProviderContainer();
      final settings = ref.read(settingsProvider.notifier);
      await settings.updateSettingsBasedOnFlowLine();
    } catch (e) {
      // Even default loading failed - this should rarely happen
      debugPrint('Failed to load default flowline: $e');
    }
  }

  @override
  Future<void> initializeOfflineMode() async {
    const bool useOfflineFlowline = bool.fromEnvironment('USE_OFFLINE_FLOWLINE', defaultValue: false);
    
    if (useOfflineFlowline) {
      // Offline mode is explicitly enabled, always use default flowline
      debugPrint('Initializing with offline flowline mode enabled');
      await _saveDefaultFlowline();
      return;
    }
    
    // Normal mode: check if we have any stored flowline data
    final stored = await _secureStorage.read(flowLineKey);
    if (stored == null || stored.isEmpty) {
      // No stored data, initialize with default as fallback
      await _saveDefaultFlowline();
    }
  }

  /// Force the app to use offline mode with default flowline
  Future<void> forceOfflineMode() async {
    await _saveDefaultFlowline();
  }
}
