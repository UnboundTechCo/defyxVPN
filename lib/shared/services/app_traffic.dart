import 'dart:io';

import 'package:defyx_vpn/modules/speed_test/application/services/speed_measurement_config.dart';
import 'package:flutter/foundation.dart';

/// Sends the app's own HTTP through the VPN while it is connected.
///
/// On Android the app is left out of the tunnel, because the core runs inside
/// it and dials its servers without protecting its sockets. On Windows and
/// Linux, Dart ignores the system proxy. Either way the app's requests would
/// leave over the direct connection and show the user's real address, so
/// while the VPN is up they go to the core's local proxy instead. Requests then
/// fail rather than fall back to the direct connection if the proxy is down.
///
/// Firebase and AdMob open their own native connections and are not covered;
/// the privacy notice says so.
class AppTraffic extends HttpOverrides {
  AppTraffic._();

  static bool _throughVpn = false;

  /// Lets tests pretend to run on a platform this applies to.
  @visibleForTesting
  static bool? debugApplies;

  static bool get _applies =>
      debugApplies ??
      (Platform.isAndroid || Platform.isWindows || Platform.isLinux);

  /// Makes every [HttpClient] the app creates follow [setConnected].
  static void install() {
    if (_applies) HttpOverrides.global = AppTraffic._();
  }

  static void setConnected(bool connected) {
    _throughVpn = connected && _applies;
  }

  @visibleForTesting
  static String proxyFor(Uri uri) => _proxyFor(uri);

  static String _proxyFor(Uri uri) {
    final host = uri.host;
    if (!_throughVpn || host == '127.0.0.1' || host == 'localhost') {
      return 'DIRECT';
    }
    return 'PROXY ${SpeedMeasurementConfig.vpnProxyHost}:'
        '${SpeedMeasurementConfig.vpnProxyPort}';
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..findProxy = _proxyFor;
  }
}
