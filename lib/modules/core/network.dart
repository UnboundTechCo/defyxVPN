import 'dart:async';
import 'dart:io';

import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:intl/intl.dart';

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

  // Stream of ping results (Windows only)
  Stream<String> get pingStream {
    if (Platform.isWindows) {
      return _vpnBridge.pingStream.map((ping) {
        final formatter = NumberFormat.decimalPattern();
        final changePing = ping == 0 ? 100 : ping;
        return formatter.format(changePing);
      });
    }
    return Stream.empty();
  }

  // Trigger ping measurement
  Future<void> triggerPing() async {
    await _vpnBridge.getPing();
  }

  // Stream of flag results (Windows only)
  Stream<String> get flagStream {
    if (Platform.isWindows) {
      return _vpnBridge.flagStream.map((flag) {
        final f = flag.toLowerCase();
        return _allowedCountries.contains(f) ? f : 'xx';
      });
    }
    return const Stream.empty();
  }

  // Trigger flag fetch
  Future<void> triggerFlag() async {
    await _vpnBridge.triggerFlag();
  }

  Future<String> getPing() async {
    final formatter = NumberFormat.decimalPattern();

    final ping = await _vpnBridge.getPing();
    if (Platform.isAndroid) {
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
}
