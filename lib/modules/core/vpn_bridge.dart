import 'dart:io';

import 'package:flutter/services.dart';

class VpnBridge {
  VpnBridge._internal();
  static final VpnBridge _instance = VpnBridge._internal();
  factory VpnBridge() => _instance;

  final _methodChannel = MethodChannel('com.defyx.vpn');

  Future<String?> getVpnStatus() => _methodChannel.invokeMethod('getVpnStatus');

  Future<void> setAsnName() => _methodChannel.invokeMethod('setAsnName');

  Future<dynamic> getPing() => _methodChannel.invokeMethod('calculatePing');

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
}
