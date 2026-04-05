import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashReportingService {
  CrashReportingService._internal();
  static final CrashReportingService _instance =
      CrashReportingService._internal();
  factory CrashReportingService() => _instance;

  FirebaseCrashlytics? _crashlytics;

  bool get _isDesktopPlatform {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  FirebaseCrashlytics? get _crashlyticsInstance {
    if (_isDesktopPlatform) return null;
    _crashlytics ??= FirebaseCrashlytics.instance;
    return _crashlytics;
  }

  /// Record a non-fatal error
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Iterable<Object> information = const [],
  }) async {
    if (_isDesktopPlatform) {
      debugPrint('Crashlytics error (desktop): $exception');
      return;
    }

    try {
      await _crashlyticsInstance?.recordError(
        exception,
        stack,
        reason: reason,
        fatal: fatal,
        information: information,
      );
    } catch (e) {
      debugPrint('Failed to record error to Crashlytics: $e');
    }
  }

  /// Record a fatal error (same as recordError with fatal=true)
  Future<void> recordFatalError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
  }) async {
    return recordError(
      exception,
      stack,
      reason: reason,
      fatal: true,
    );
  }

  /// Record a Flutter error (from FlutterErrorDetails)
  Future<void> recordFlutterFatalError(FlutterErrorDetails errorDetails) async {
    if (_isDesktopPlatform) {
      debugPrint('Crashlytics Flutter error (desktop): ${errorDetails.exception}');
      return;
    }

    try {
      await _crashlyticsInstance?.recordFlutterFatalError(errorDetails);
    } catch (e) {
      debugPrint('Failed to record Flutter error to Crashlytics: $e');
    }
  }

  /// Set a custom key-value pair for debugging context
  Future<void> setCustomKey(String key, Object value) async {
    if (_isDesktopPlatform) return;

    try {
      await _crashlyticsInstance?.setCustomKey(key, value);
    } catch (e) {
      debugPrint('Failed to set custom key in Crashlytics: $e');
    }
  }

  /// Set user identifier for crash reports
  Future<void> setUserId(String userId) async {
    if (_isDesktopPlatform) return;

    try {
      await _crashlyticsInstance?.setUserIdentifier(userId);
    } catch (e) {
      debugPrint('Failed to set user ID in Crashlytics: $e');
    }
  }

  /// Log a message to Crashlytics (appears in crash reports as breadcrumb)
  Future<void> log(String message) async {
    if (_isDesktopPlatform) {
      debugPrint('Crashlytics log (desktop): $message');
      return;
    }

    try {
      await _crashlyticsInstance?.log(message);
    } catch (e) {
      debugPrint('Failed to log to Crashlytics: $e');
    }
  }

  /// Record VPN-specific error with context
  Future<void> recordVpnError(
    dynamic exception,
    StackTrace? stack, {
    String? vpnState,
    String? server,
    String? protocol,
    String? connectionMethod,
  }) async {
    if (_isDesktopPlatform) return;

    try {
      // Set VPN context as custom keys
      if (vpnState != null) await setCustomKey('vpn_state', vpnState);
      if (server != null) await setCustomKey('vpn_server', server);
      if (protocol != null) await setCustomKey('vpn_protocol', protocol);
      if (connectionMethod != null) {
        await setCustomKey('vpn_connection_method', connectionMethod);
      }

      // Record the error
      await recordError(
        exception,
        stack,
        reason: 'VPN operation error',
        fatal: false,
      );
    } catch (e) {
      debugPrint('Failed to record VPN error to Crashlytics: $e');
    }
  }

  /// Record Go panic from native crash callback
  Future<void> recordGoPanic(
    String functionName,
    String errorMessage,
    String stackTrace,
  ) async {
    if (_isDesktopPlatform) {
      debugPrint('Go panic (desktop): $functionName - $errorMessage');
      return;
    }

    try {
      await setCustomKey('go_panic_function', functionName);
      await log('Go panic in $functionName: $errorMessage');
      
      // Record as non-fatal since we recovered from it
      await recordError(
        'Go panic in $functionName: $errorMessage',
        StackTrace.fromString(stackTrace),
        reason: 'Go runtime panic recovered',
        fatal: false,
      );
    } catch (e) {
      debugPrint('Failed to record Go panic to Crashlytics: $e');
    }
  }
}
