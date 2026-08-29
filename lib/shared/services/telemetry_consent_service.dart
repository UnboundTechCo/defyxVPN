import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:defyx_vpn/firebase_options.dart';

enum TelemetryConsent { undecided, denied, granted }

class TelemetryConsentService {
  TelemetryConsentService._internal();

  static final TelemetryConsentService _instance =
      TelemetryConsentService._internal();
  static const _storageKey = 'telemetry_consent_v1';
  static const _firebaseAppName = 'defyx-vpn';

  factory TelemetryConsentService() => _instance;

  TelemetryConsent _consent = TelemetryConsent.undecided;
  bool _firebaseInitialized = false;
  Future<void>? _initialization;

  TelemetryConsent get consent => _consent;
  bool get isGranted => _consent == TelemetryConsent.granted;
  bool get isCollectionEnabled => isGranted && _firebaseInitialized;

  Future<void> initialize() {
    return _initialization ??= _loadAndInitialize();
  }

  Future<void> _loadAndInitialize() async {
    final prefs = await SharedPreferences.getInstance();
    final storedConsent = prefs.getString(_storageKey);
    _consent = switch (storedConsent) {
      'granted' => TelemetryConsent.granted,
      'denied' => TelemetryConsent.denied,
      _ => TelemetryConsent.undecided,
    };

    if (isGranted) {
      await _initializeFirebase();
    }
  }

  Future<void> grant() async {
    _consent = TelemetryConsent.granted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, 'granted');
    await _initializeFirebase();
  }

  Future<void> deny() async {
    _consent = TelemetryConsent.denied;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, 'denied');

    if (_firebaseInitialized) {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    }
  }

  Future<void> _initializeFirebase() async {
    if (_firebaseInitialized || !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }

    try {
      await Firebase.initializeApp(
        name: _firebaseAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      _installErrorHandlers();
      _firebaseInitialized = true;
    } catch (error, stack) {
      debugPrint('Failed to initialize telemetry: $error');
      debugPrint(stack.toString());
    }
  }

  void _installErrorHandlers() {
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      FlutterError.presentError(errorDetails);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
}
