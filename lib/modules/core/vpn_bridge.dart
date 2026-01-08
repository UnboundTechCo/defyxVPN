import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VpnBridge {
  VpnBridge._internal();
  static final VpnBridge _instance = VpnBridge._internal();
  factory VpnBridge() => _instance;

  final _methodChannel = MethodChannel('com.defyx.vpn');

  Future<String?> getVpnStatus() async =>
      await _methodChannel.invokeMethod('getVpnStatus');

  Future<void> setAsnName() async =>
      await _methodChannel.invokeMethod('setAsnName');

  Future<String> getPing() async =>
      (await _methodChannel.invokeMethod('calculatePing')).toString();

  Future<void> setTimezone(String timezone) =>
      _methodChannel.invokeMethod("setTimezone", {"timezone": timezone});

  Future<void> disconnectVpn() async =>
      await _methodChannel.invokeMethod('disconnect');

  Future<void> stopVPN() async => await _methodChannel.invokeMethod('stopVPN');

  Future<void> stopTun2Socks() async =>
      await _methodChannel.invokeMethod("stopTun2Socks");

  Future<bool?> connectVpn() async =>
      await _methodChannel.invokeMethod<bool>('connect');

  Future<bool?> grantVpnPermission() async =>
      await _methodChannel.invokeMethod<bool>("grantVpnPermission");

  Future<void> startVPN(String flowline, String pattern, bool deepScan) async =>
      await _methodChannel.invokeMethod("startVPN", {
        "flowLine": flowline,
        "pattern": pattern,
        "deepScan": deepScan.toString()
      });

  Future<void> startTun2socks() =>
      _methodChannel.invokeMethod("startTun2socks");

  Future<bool> isTunnelRunning() async =>
      (await _methodChannel.invokeMethod<bool>("isTunnelRunning")) ?? false;

  Future<void> setConnectionMethod(String method) async => await _methodChannel
      .invokeMethod("setConnectionMethod", {"method": method});
  Future<String> getFlowLine() async {
    final isTestMode = dotenv.env['IS_TEST_MODE'] ?? 'false';
    final flowLine = await _methodChannel
        .invokeMethod<String>('getFlowLine', {"isTest": isTestMode});
    return flowLine ?? '';
  }

  Future<String> getCachedFlowLine() async {
    final info = await _methodChannel.invokeMethod<String>('getCachedFlowLine');
    return info ?? "";
  }

  Future<String> getFlag() async =>
      (await _methodChannel.invokeMethod<String>('getFlag') ?? "");

  Future<bool> prepareVpn() async =>
      (await _methodChannel.invokeMethod('prepareVPN')) ?? false;

  Future<bool> isVPNPrepared() async =>
      (await _methodChannel.invokeMethod<bool>('isVPNPrepared')) ?? false;
}
