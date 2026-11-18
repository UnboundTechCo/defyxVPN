import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user agreed to share usage statistics and crash reports.
///
/// Firebase Analytics and Crashlytics start switched off (see the flags in
/// AndroidManifest.xml and Info.plist) and send nothing, not even their
/// settings requests, until [set] is called with true. Firebase Sessions
/// follows Crashlytics. Crashes recorded before the choice stay on the device;
/// they are sent after the user agrees and deleted if they decline.
class TelemetryConsent {
  TelemetryConsent._();

  static const _key = 'telemetry_consent';

  static bool _granted = false;
  static bool _decided = false;

  static bool get isGranted => _granted;

  /// Whether the user has answered the question at all.
  static bool get isDecided => _decided;

  /// Firebase runs everywhere but Windows and Linux.
  static bool get isSupported => !(Platform.isWindows || Platform.isLinux);

  /// Reads the stored choice and applies it. Call once Firebase is ready.
  static Future<void> load(SharedPreferences? prefs) async {
    final stored = prefs?.getBool(_key);
    _decided = stored != null;
    _granted = stored ?? false;
    await _apply(discardStored: false);
  }

  static Future<void> set(bool granted) async {
    _granted = granted;
    _decided = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, granted);
    } catch (e) {
      debugPrint('Failed to store telemetry consent: $e');
    }
    await _apply(discardStored: !granted);
  }

  static Future<void> _apply({required bool discardStored}) async {
    if (!isSupported) return;
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(_granted);
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        _granted,
      );
      if (discardStored) {
        await FirebaseCrashlytics.instance.deleteUnsentReports();
      }
    } catch (e) {
      debugPrint('Failed to apply telemetry consent: $e');
    }
  }
}
