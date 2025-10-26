import 'dart:convert';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service_interface.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_interface.dart';
import 'package:defyx_vpn/shared/global_vars.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final flowlineServiceProvider = Provider<IFlowlineService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return FlowlineService(secureStorage);
});

class FlowlineService implements IFlowlineService {
  final ISecureStorage _secureStorage;
  final _platformChannel = const MethodChannel('com.defyx.vpn');

  FlowlineService(this._secureStorage);

  @override
  Future<String> getFlowline() async {
    // Ask the native side first i think it may be useful for static config loading, so I kept it :)
    final flowLine = await _platformChannel.invokeMethod<String>(
        'getFlowLine', {"isTest": dotenv.env['IS_TEST_MODE'] ?? 'false'});

    // If native returned nothing, fall back to bundled config
    if (flowLine == null || flowLine.isEmpty) {
      // Fallback: load default flowline from assets
      return await rootBundle.loadString('assets/settings/config.json');
    }

    // Validate JSON; if invalid, also fall back to assets
    try {
      json.decode(flowLine);
      return flowLine;
    } on FormatException {
      // Fallback: load default flowline from assets
      final assetConfig =
          await rootBundle.loadString('assets/settings/config.json');
      return assetConfig;
    }
  }

  @override
  Future<void> saveFlowline() async {
    final flowLine = await getFlowline();
    if (flowLine.isNotEmpty) {
      final decoded = json.decode(flowLine);
      // Optional sections: handle gracefully if missing in fallback configs
      final appBuildType = GlobalVars.appBuildType;
      if (decoded is Map<String, dynamic>) {
        // Advertise
        if (decoded.containsKey('advertise')) {
          final advertiseStorageMap = {
            'api_advertise': decoded['advertise'],
          };
          await _secureStorage.writeMap(apiAvertiseKey, advertiseStorageMap);
        }

        // Version parameters
        if (decoded['version'] != null &&
            decoded['forceUpdate'] != null &&
            decoded['changeLog'] != null) {
          final version = decoded['version'][appBuildType];
          if (version != null) {
            final versionStorageMap = {
              'api_app_version': version,
              'forceUpdate': decoded['forceUpdate'][version],
              'changeLog': decoded['changeLog'][version],
            };
            await _secureStorage.writeMap(
                apiVersionParametersKey, versionStorageMap);
          }
        }

        // Flowline list (required for operation)
        if (decoded['flowLine'] != null) {
          await _secureStorage.write(
              flowLineKey, json.encode(decoded['flowLine']));
        } else {
          throw Exception('Invalid config: missing flowLine');
        }
      } else {
        throw Exception('Invalid config format');
      }
    } else {
      throw Exception('Flowline is empty, cannot save');
    }
  }
}
