import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class FirebaseAnalyticsService {
  FirebaseAnalyticsService._internal();
  static final FirebaseAnalyticsService _instance =
      FirebaseAnalyticsService._internal();
  factory FirebaseAnalyticsService() => _instance;

  FirebaseAnalytics? _analytics;

  bool get _isDesktopPlatform {
    return !(Platform.isAndroid || Platform.isIOS);
  }

  FirebaseAnalytics? get _analyticsInstance {
    if (_isDesktopPlatform) return null;
    _analytics ??= FirebaseAnalytics.instance;
    return _analytics;
  }

  FirebaseAnalyticsObserver getAnalyticsObserver() {
    if (_isDesktopPlatform) {
      throw UnsupportedError(
          'Firebase Analytics is not supported on desktop platforms');
    }
    return FirebaseAnalyticsObserver(analytics: _analyticsInstance!);
  }

  Future<void> logVpnConnectAttempt(String connectionMethod) async {
    if (_isDesktopPlatform) return;
    try {
      await _analyticsInstance?.logEvent(
        name: 'vpn_connect_attempt',
        parameters: {'connection_method': connectionMethod},
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  Future<void> logVpnConnected(
      String connectionMethod, String? server, int durationSeconds) async {
    if (_isDesktopPlatform) return;
    try {
      await _analyticsInstance?.logEvent(
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
    if (_isDesktopPlatform) return;
    try {
      await _analyticsInstance?.logEvent(name: 'vpn_disconnected');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  Future<void> logConnectionMethodChanged(String newMethod) async {
    if (_isDesktopPlatform) return;
    try {
      await _analyticsInstance?.logEvent(
        name: 'connection_method_changed',
        parameters: {'method': newMethod},
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  Future<void> logServerSelected(String serverName) async {
    if (_isDesktopPlatform) return;
    try {
      await _analyticsInstance?.logEvent(
        name: 'server_selected',
        parameters: {'server': serverName},
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  Future<void> setUserId(String? userId) async {
    if (_isDesktopPlatform) return;
    try {
      await _analyticsInstance?.setUserId(id: userId);
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  Future<void> setUserProperty(String name, String? value) async {
    if (_isDesktopPlatform) return;
    try {
      await _analyticsInstance?.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }
}
