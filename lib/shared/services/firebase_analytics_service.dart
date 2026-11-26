import 'dart:io';

import 'package:defyx_vpn/shared/services/desktop_analytics.dart';
import 'package:defyx_vpn/shared/services/telemetry_consent.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Usage statistics: the Firebase Analytics SDK on Android, iOS and macOS,
/// DesktopAnalytics on Windows and Linux, which have no SDK.
class FirebaseAnalyticsService {
  FirebaseAnalyticsService._internal();
  static final FirebaseAnalyticsService _instance =
      FirebaseAnalyticsService._internal();
  factory FirebaseAnalyticsService() => _instance;

  FirebaseAnalytics? _analytics;

  bool get _usesDesktopAnalytics => Platform.isWindows || Platform.isLinux;

  // Null until the user agrees to share usage statistics, so no event is even
  // handed to Firebase before that.
  FirebaseAnalytics? get _analyticsInstance {
    if (_usesDesktopAnalytics || !TelemetryConsent.isGranted) return null;
    _analytics ??= FirebaseAnalytics.instance;
    return _analytics;
  }

  FirebaseAnalyticsObserver getAnalyticsObserver() {
    if (_usesDesktopAnalytics) {
      throw UnsupportedError(
          'Firebase Analytics is not supported on Windows and Linux');
    }
    // Collection itself is off until consent, see TelemetryConsent.
    return FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);
  }

  Future<void> _log(String name, [Map<String, Object>? parameters]) async {
    try {
      if (_usesDesktopAnalytics) {
        if (TelemetryConsent.isGranted) {
          await DesktopAnalytics.instance.logEvent(name, parameters);
        }
        return;
      }
      await _analyticsInstance?.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  Future<void> logVpnConnectAttempt(String connectionMethod) => _log(
        'vpn_connect_attempt',
        {'connection_method': connectionMethod},
      );

  Future<void> logVpnConnected(
          String connectionMethod, String? server, int durationSeconds) =>
      _log('vpn_connected', {
        'connection_method': connectionMethod,
        'connection_duration_seconds': durationSeconds,
        if (server != null) 'server': server,
      });

  Future<void> logVpnConnectionFailed(
          String connectionMethod, String? server, int durationSeconds) =>
      _log('vpn_connection_failed', {
        'connection_method': connectionMethod,
        'attempt_duration_seconds': durationSeconds,
        if (server != null) 'server': server,
      });

  Future<void> logVpnDisconnected() => _log('vpn_disconnected');

  Future<void> logConnectionMethodChanged(String newMethod) =>
      _log('connection_method_changed', {'method': newMethod});

  Future<void> logServerSelected(String serverName) =>
      _log('server_selected', {'server': serverName});

  Future<void> setUserId(String? userId) async {
    try {
      if (_usesDesktopAnalytics) {
        if (TelemetryConsent.isGranted) {
          DesktopAnalytics.instance.setUserId(userId);
        }
        return;
      }
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
    final filtered = filterCoreEvent(event, parameters);
    if (filtered == null) return;
    await _log(event, filtered);
  }

  Future<void> setUserProperty(String name, String? value) async {
    try {
      if (_usesDesktopAnalytics) {
        if (TelemetryConsent.isGranted) {
          DesktopAnalytics.instance.setUserProperty(name, value);
        }
        return;
      }
      await _analyticsInstance?.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  // Generic event logging for services
  Future<void> logEvent({
    required String name,
    Map<String, String>? parameters,
  }) =>
      _log(name, parameters);
}
