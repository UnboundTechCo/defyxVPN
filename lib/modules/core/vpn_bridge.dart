import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VpnBridge {
  VpnBridge._internal();
  static final VpnBridge _instance = VpnBridge._internal();
  factory VpnBridge() => _instance;

  final _methodChannel = MethodChannel('com.defyx.vpn');

  Future<String?> getVpnStatus() => _methodChannel.invokeMethod('getVpnStatus');

  Future<void> setAsnName() => _methodChannel.invokeMethod('setAsnName');

  Future<String> getPing() async {
    final ping = await _methodChannel.invokeMethod('calculatePing');
    return ping.toString();
  }

  Future<void> setTimezone(String timezone) =>
      _methodChannel.invokeMethod("setTimezone", {"timezone": timezone});

  Future<void> disconnectVpn() => _methodChannel.invokeMethod('disconnect');

  Future<void> stopVPN() => _methodChannel.invokeMethod('stopVPN');

  Future<void> stopTun2Socks() => _methodChannel.invokeMethod("stopTun2Socks");

  Future<bool?> connectVpn() => _methodChannel.invokeMethod<bool>('connect');

  Future<bool?> grantVpnPermission() =>
      _methodChannel.invokeMethod<bool>("grantVpnPermission");

  Future<void> startVPN(String flowline, String pattern) => _methodChannel
      .invokeMethod("startVPN", {"flowLine": flowline, "pattern": pattern});

  Future<void> startTun2socks() =>
      _methodChannel.invokeMethod("startTun2socks");

  Future<bool> isTunnelRunning() async {
    return await _methodChannel.invokeMethod<bool>("isTunnelRunning") ?? false;
  }

  Future<void> setConnectionMethod(String method) =>
      _methodChannel.invokeMethod("setConnectionMethod", {"method": method});
  Future<String> getFlowLine() async {
    final isTestMode = dotenv.env['IS_TEST_MODE'] ?? 'false';
    final flowLine = await _methodChannel
        .invokeMethod<String>('getFlowLine', {"isTest": isTestMode});
    return flowLine ?? '';
  }

  Future<String> getFlag() async {
    final flag = await _methodChannel.invokeMethod<String>('getFlag');
    return flag ?? '';
  }

  Future<bool> prepareVpn() async {
    final result = await _methodChannel.invokeMethod('prepareVPN');
    return result ?? false;
  }

  Future<bool> isVPNPrepared() async {
    return await _methodChannel.invokeMethod<bool>('isVPNPrepared') ?? false;
  }
}
