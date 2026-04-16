import 'dart:io';
import 'dart:ui';
import 'package:defyx_vpn/firebase_options.dart';
import 'package:defyx_vpn/modules/core/vpn_bridge.dart';
import 'package:defyx_vpn/shared/providers/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  // Initialize cache directory for VPN core
  try {
    final String vpnCacheDir = await VpnBridge().getSharedDirectory();
    await VpnBridge().setCacheDir(vpnCacheDir);
    debugPrint('VPN cache directory set to: $vpnCacheDir');
  } catch (e) {
    debugPrint('Failed to set cache directory: $e');
  }

  // Initialize Firebase only on supported platforms (not Windows)
  if (!Platform.isWindows && !Platform.isLinux) {
    await Firebase.initializeApp(
      name: "defyx-vpn",
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Firebase Crashlytics
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

    // Pass all uncaught Flutter errors to Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      // Also print to console in debug mode
      FlutterError.presentError(errorDetails);
    };

    // Pass all uncaught asynchronous errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // Only lock orientation on mobile devices, not on Android TV
  if (Platform.isAndroid || Platform.isIOS) {
    // Check if running on Android TV by checking screen size will be done in app
    // For now, we'll set orientation based on platform detection
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (e) {
      debugPrint('Could not set orientations: $e');
    }
  }

  // Initialize language provider
  final prefs = await SharedPreferences.getInstance();
  final languageNotifier = LanguageNotifier(prefs);

  // Set up error handler for zone errors (if not on Windows/Linux)
  if (!Platform.isWindows && !Platform.isLinux) {
    // Additional async error handling via runZonedGuarded
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      FlutterError.presentError(errorDetails);
    };
  }

  // Run app in same zone as ensureInitialized
  runApp(
    ProviderScope(
      overrides: [languageProvider.overrideWith((ref) => languageNotifier)],
      child: const App(),
    ),
  );
}
