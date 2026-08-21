import 'package:defyx_vpn/core/data/local/remote/api/flowline_settings.dart';

abstract interface class IFlowlineService {
  Future<String> getFlowline();
  Future<String> getCachedFlowLine();
  Future<String> decodeAndVerifyFlowline(String flowLine);
  Future<void> saveFlowline({
    required bool offlineMode,
    String? flowLine,
    bool forceUpdate = false,
  });
  Future<FlowlineSettings> getFlowlineSettings();
}
