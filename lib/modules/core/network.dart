import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:intl/intl.dart';

class NetworkStatus {
  NetworkStatus._internal();
  static final NetworkStatus _instance = NetworkStatus._internal();
  final _vpnBridge = VpnBridge();
  factory NetworkStatus() {
    return _instance;
  }
  Future<String> getPing() async {
    final formatter = NumberFormat.decimalPattern();

    final ping = await _vpnBridge.getPing();

    final changePing = int.tryParse(ping);
    return formatter.format(changePing);
  }

  Future<String> getFlag() async {
    final List<String> allowedCountries = [
      'at',
      'au',
      'az',
      'be',
      'ca',
      'ch',
      'cz',
      'de',
      'dk',
      'ee',
      'es',
      'fi',
      'fr',
      'gb',
      'hr',
      'hu',
      'in',
      'ir',
      'it',
      'jp',
      'lv',
      'nl',
      'no',
      'pl',
      'pt',
      'ro',
      'rs',
      'se',
      'sg',
      'sk',
      'tr'
    ];
    try {
      final flag = await _vpnBridge.getFlag();

      if (allowedCountries.contains(flag.toLowerCase())) {
        return flag.toLowerCase();
      }
      return 'xx';
    } catch (e) {
      return 'xx';
    }
  }

  Future<bool> checkConnectivity() async {
    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());

    return connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.ethernet) ||
        connectivityResult.contains(ConnectivityResult.bluetooth);
  }

  // static Future<bool> checkConnectivity() async {
  //   try {
  //     final connectivityResult = await Connectivity().checkConnectivity();
  //     return connectivityResult.any((result) =>
  //     result == ConnectivityResult.mobile ||
  //         result == ConnectivityResult.wifi ||
  //         result == ConnectivityResult.ethernet ||
  //         result == ConnectivityResult.vpn);
  //   } catch (e) {
  //     // Fallback: try to resolve a DNS query
  //     try {
  //       final result = await dart_io.InternetAddress.lookup('google.com');
  //       return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  //     } catch (e) {
  //       return false;
  //     }
  //   }
  // }
}
