import 'dart:io';

import 'package:defyx_vpn/shared/services/telemetry_consent.dart';
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

  // Null until the user agrees to share usage statistics, so no event is even
  // handed to Firebase before that.
  FirebaseAnalytics? get _analyticsInstance {
    if (_isDesktopPlatform || !TelemetryConsent.isGranted) return null;
    _analytics ??= FirebaseAnalytics.instance;
    return _analytics;
  }

  FirebaseAnalyticsObserver getAnalyticsObserver() {
    if (_isDesktopPlatform) {
      throw UnsupportedError(
          'Firebase Analytics is not supported on desktop platforms');
    }
    // Collection itself is off until consent, see TelemetryConsent.
    return FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);
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

  Future<void> logVpnConnectionFailed(
      String connectionMethod, String? server, int durationSeconds) async {
    if (_isDesktopPlatform) return;
    try {
      await _analyticsInstance?.logEvent(
        name: 'vpn_connection_failed',
        parameters: {
          'connection_method': connectionMethod,
          'attempt_duration_seconds': durationSeconds,
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

  // The only events the core may report, and the fields each may carry.
  // Anything else the core sends is dropped.
  static const _coreEvents = <String, Set<String>>{
    'flowline': {'method', 'asn', 'device'},
    'asn': {'method', 'asn', 'device'},
    'flag': {'country', 'asn', 'device'},
    'connect': {'method', 'step', 'asn', 'device'},
  };

  /// The fields of a core event that may be sent, or null if the event may
  /// not be sent at all.
  @visibleForTesting
  static Map<String, String>? filterCoreEvent(
    String event,
    Map<String, String> parameters,
  ) {
    final allowed = _coreEvents[event];
    if (allowed == null) return null;
    return {
      for (final entry in parameters.entries)
        if (allowed.contains(entry.key)) entry.key: entry.value,
    };
  }

  Future<void> logCoreData(String event, Map<String, String> parameters) async {
    if (_isDesktopPlatform) return;
    final filtered = filterCoreEvent(event, parameters);
    if (filtered == null) return;
    try {
      await _analyticsInstance?.logEvent(name: event, parameters: filtered);
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

  // Generic event logging for services
  Future<void> logEvent({
    required String name,
    Map<String, String>? parameters,
  }) async {
    if (_isDesktopPlatform) return;
    try {
      await _analyticsInstance?.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }
}
