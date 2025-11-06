import 'dart:async';
import 'dart:io' as dart_io;

import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkStatus {
  NetworkStatus._internal();
  static final NetworkStatus _instance = NetworkStatus._internal();
  final _vpnBridge = VpnBridge();
  factory NetworkStatus() {
    return _instance;
  }

  static const List<String> _allowedCountries = [
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

  Future<String> getPing() async {
    final formatter = NumberFormat.decimalPattern();

    final ping = await _vpnBridge.getPing();
    if (dart_io.Platform.isAndroid) {
      final changePing = ping == 0 ? 100 : ping;
      return formatter.format(changePing);
    }
    // On other platforms, ping is already an int
    final pingValue = ping is int ? ping : (int.tryParse(ping.toString()) ?? 0);
    final changePing = pingValue == 0 ? 100 : pingValue;
    return formatter.format(changePing);
  }

  Future<String> getFlag() async {
    try {
      final flag = await _vpnBridge.getFlag();
      final f = flag.toLowerCase();
      return _allowedCountries.contains(f) ? f : 'xx';
    } catch (e) {
      return 'xx';
    }
  }

  static Future<bool> checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.any((result) => 
        result == ConnectivityResult.mobile || 
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn
      );
    } catch (e) {
      // Fallback: try to resolve a DNS query
      try {
        final result = await dart_io.InternetAddress.lookup('google.com');
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (e) {
        return false;
      }
    }
  }
}
