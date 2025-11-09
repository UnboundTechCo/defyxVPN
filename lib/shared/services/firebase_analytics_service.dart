// Firebase temporarily disabled for Windows testing
import 'package:flutter/foundation.dart';

class FirebaseAnalyticsService {
  FirebaseAnalyticsService._internal();
  static final FirebaseAnalyticsService _instance =
      FirebaseAnalyticsService._internal();
  factory FirebaseAnalyticsService() => _instance;

  // Stub implementation - Firebase disabled
  dynamic getAnalyticsObserver() => null;

  Future<void> logVpnConnectAttempt(String connectionMethod) async {
    debugPrint('Analytics stub: vpn_connect_attempt - $connectionMethod');
  }

  Future<void> logVpnConnected(
      String connectionMethod, String? server, int durationSeconds) async {
    debugPrint(
        'Analytics stub: vpn_connected - $connectionMethod, $server, ${durationSeconds}s');
  }

  Future<void> logVpnDisconnected() async {
    debugPrint('Analytics stub: vpn_disconnected');
  }

  Future<void> logConnectionMethodChanged(String newMethod) async {
    debugPrint('Analytics stub: connection_method_changed - $newMethod');
  }

  Future<void> logServerSelected(String serverName) async {
    debugPrint('Analytics stub: server_selected - $serverName');
  }

  Future<void> setUserId(String? userId) async {
    debugPrint('Analytics stub: setUserId - $userId');
  }

  Future<void> setUserProperty(String name, String? value) async {
    debugPrint('Analytics stub: setUserProperty - $name: $value');
  }
}
