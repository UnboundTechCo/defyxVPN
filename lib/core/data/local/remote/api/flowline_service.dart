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
    final flowLine = await _platformChannel.invokeMethod<String>(
        'getFlowLine', {"isTest": dotenv.env['IS_TEST_MODE'] ?? 'false'});
    return flowLine ?? '';
  }

  @override
  Future<void> saveFlowline() async {
    final flowLine = await getFlowline();
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
    } else {
      throw Exception('Flowline is empty, cannot save');
    }
  }
}
