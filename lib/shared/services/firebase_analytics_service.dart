import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class FirebaseAnalyticsService {
  FirebaseAnalyticsService._internal();
  static final FirebaseAnalyticsService _instance = FirebaseAnalyticsService._internal();
  factory FirebaseAnalyticsService() => _instance;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver getAnalyticsObserver() =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logVpnConnectAttempt(String connectionMethod) async {
    try {
      await _analytics.logEvent(
        name: 'vpn_connect_attempt',
        parameters: {'connection_method': connectionMethod},
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  Future<void> logVpnConnected(String connectionMethod, String? server, int durationSeconds) async {
    try {
      await _analytics.logEvent(
        name: 'vpn_connected',
        parameters: {
          'connection_method': connectionMethod,
          'connection_duration_seconds': durationSeconds,
          if (server != null) 'server': server,
        },
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  Future<void> logVpnDisconnected() async {
    try {
      await _analytics.logEvent(name: 'vpn_disconnected');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  Future<void> logConnectionMethodChanged(String newMethod) async {
    try {
      await _analytics.logEvent(
        name: 'connection_method_changed',
        parameters: {'method': newMethod},
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  Future<void> logServerSelected(String serverName) async {
    try {
      await _analytics.logEvent(
        name: 'server_selected',
        parameters: {'server': serverName},
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  Future<void> setUserProperty(String name, String? value) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }
}
