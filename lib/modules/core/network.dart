import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class NetworkStatus {
  final MethodChannel _platform = const MethodChannel('com.defyx.vpn');

  NetworkStatus._internal();

  static final NetworkStatus _instance = NetworkStatus._internal();

  factory NetworkStatus() {
    return _instance;
  }
  Future<String> getPing() async {
    final formatter = NumberFormat.decimalPattern();

    final ping = await _platform.invokeMethod("calculatePing");
    if (Platform.isAndroid) {
      final changePing = ping == 0 ? 100 : ping;
      return formatter.format(changePing);
    }
    final changePing = int.tryParse(ping) == 0 ? 100 : int.tryParse(ping);
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
      final flag = await _platform.invokeMethod<String>('getFlag');

      if (flag != null && allowedCountries.contains(flag.toLowerCase())) {
        return flag.toLowerCase();
      }
      return 'xx';
    } catch (e) {
      return 'xx';
    }
  }
}
